'use strict';

/**
 * Impor massal data nasab dari CSV ke Neo4j.
 *
 * Jalankan:  npm run import -- data/people.sample.csv
 *
 * Format CSV (header wajib, satu baris = satu orang):
 *
 *   id,name,gender,father_id,mother_id
 *   p1,Ahmad,m,,
 *   p2,Ubaidillah,m,p1,
 *   p10,Ali,m,p7,p9
 *
 * - id        : id stabil dari sumber (kitab/daftar). WAJIB & unik.
 * - name      : nama asli (tanpa bin/binti). WAJIB.
 * - gender    : 'm' atau 'f'. WAJIB.
 * - father_id : id ayah (boleh kosong / merujuk orang yang sudah ada di DB).
 * - mother_id : id ibu   (boleh kosong / merujuk orang yang sudah ada di DB).
 *
 * Sifat impor:
 * - IDEMPOTEN: memakai MERGE, jadi menjalankan ulang file yang sama akan
 *   memperbarui (bukan menggandakan). Aman untuk koreksi bertahap.
 * - ADITIF: tidak menghapus data lama. (Butuh reset total? pakai `npm run seed`
 *   atau hapus manual dulu.)
 * - DIVALIDASI dulu: id duplikat, gender salah, referensi orang tua yang hilang,
 *   dan siklus (orang jadi leluhurnya sendiri) akan menggagalkan impor sebelum
 *   ada data yang ditulis.
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { parse } = require('csv-parse/sync');
const { runQuery, closeDriver, verifyConnection } = require('./connection');

const BATCH = 1000;

/** Baca & parse CSV menjadi array baris objek (pakai header). */
function readCsv(file) {
  const text = fs.readFileSync(file, 'utf8');
  return parse(text, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
    bom: true,
  });
}

/** Normalisasi + validasi struktural (tanpa akses DB). */
function validate(rows) {
  const errors = [];
  const ids = new Set();
  const people = [];

  rows.forEach((r, i) => {
    const line = i + 2; // +1 header, +1 karena 1-based
    const id = (r.id || '').trim();
    const name = (r.name || '').trim();
    const gender = (r.gender || '').trim().toLowerCase();
    const fatherId = (r.father_id || '').trim() || null;
    const motherId = (r.mother_id || '').trim() || null;

    if (!id) errors.push(`Baris ${line}: kolom id kosong`);
    if (!name) errors.push(`Baris ${line}: kolom name kosong`);
    if (gender !== 'm' && gender !== 'f') {
      errors.push(`Baris ${line}: gender harus 'm'/'f' (dapat "${r.gender ?? ''}")`);
    }
    if (id && ids.has(id)) errors.push(`Baris ${line}: id duplikat "${id}"`);
    if (id) ids.add(id);
    if (fatherId && fatherId === id) {
      errors.push(`Baris ${line}: father_id menunjuk dirinya sendiri`);
    }
    if (motherId && motherId === id) {
      errors.push(`Baris ${line}: mother_id menunjuk dirinya sendiri`);
    }
    if (fatherId && motherId && fatherId === motherId) {
      errors.push(`Baris ${line}: father_id dan mother_id sama`);
    }

    people.push({ id, name, gender, fatherId, motherId });
  });

  return { people, ids, errors };
}

/**
 * Referensi orang tua yang tidak ada di file DAN tidak ada di DB.
 * (Referensi ke orang yang sudah ada di DB diperbolehkan — impor bertahap.)
 */
async function findMissingParents(people, ids) {
  const referenced = new Set();
  for (const p of people) {
    if (p.fatherId && !ids.has(p.fatherId)) referenced.add(p.fatherId);
    if (p.motherId && !ids.has(p.motherId)) referenced.add(p.motherId);
  }
  if (referenced.size === 0) return [];

  const records = await runQuery(
    'UNWIND $ids AS id MATCH (p:Person {id: id}) RETURN p.id AS id',
    { ids: [...referenced] },
    'READ'
  );
  const inDb = new Set(records.map((r) => r.get('id')));
  return [...referenced].filter((id) => !inDb.has(id));
}

/**
 * Deteksi siklus di dalam file (anak -> orang tua tidak boleh membentuk loop).
 * Hanya menelusuri edge antar-orang yang ada di file; referensi ke DB dianggap
 * akar (DB diasumsikan sudah bebas siklus).
 */
function detectCycles(people) {
  const parents = new Map();
  for (const p of people) {
    const list = [];
    if (p.fatherId) list.push(p.fatherId);
    if (p.motherId) list.push(p.motherId);
    parents.set(p.id, list);
  }

  const state = new Map(); // undefined=belum, 1=sedang, 2=selesai
  const cycles = [];

  function dfs(id, stack) {
    if (!parents.has(id)) return; // referensi luar / akar
    const s = state.get(id);
    if (s === 2) return;
    if (s === 1) {
      const from = stack.indexOf(id);
      cycles.push(stack.slice(from).concat(id).join(' -> '));
      return;
    }
    state.set(id, 1);
    for (const par of parents.get(id)) dfs(par, [...stack, id]);
    state.set(id, 2);
  }

  for (const p of people) dfs(p.id, []);
  return cycles;
}

/** Pastikan constraint & index ada (MERGE jauh lebih cepat dengan constraint). */
async function ensureSchema() {
  await runQuery(
    `CREATE CONSTRAINT person_id IF NOT EXISTS
       FOR (p:Person) REQUIRE p.id IS UNIQUE`
  );
  await runQuery(
    `CREATE INDEX person_name IF NOT EXISTS
       FOR (p:Person) ON (p.name)`
  );
}

/** Tulis node Person (MERGE) per batch. */
async function importNodes(people) {
  for (let i = 0; i < people.length; i += BATCH) {
    const rows = people
      .slice(i, i + BATCH)
      .map((p) => ({ id: p.id, name: p.name, gender: p.gender }));
    await runQuery(
      `UNWIND $rows AS row
       MERGE (p:Person { id: row.id })
       SET p.name = row.name, p.gender = row.gender`,
      { rows }
    );
  }
}

/** Tulis relasi CHILD_OF (MERGE) per batch. Kembalikan jumlah relasi. */
async function importRelationships(people) {
  const rels = [];
  for (const p of people) {
    if (p.fatherId) rels.push({ child: p.id, parent: p.fatherId, via: 'father' });
    if (p.motherId) rels.push({ child: p.id, parent: p.motherId, via: 'mother' });
  }
  for (let i = 0; i < rels.length; i += BATCH) {
    const rows = rels.slice(i, i + BATCH);
    await runQuery(
      `UNWIND $rows AS row
       MATCH (c:Person { id: row.child })
       MATCH (p:Person { id: row.parent })
       MERGE (c)-[r:CHILD_OF { via: row.via }]->(p)`,
      { rows }
    );
  }
  return rels.length;
}

async function main() {
  const file = process.argv[2];
  if (!file) {
    // eslint-disable-next-line no-console
    console.error('Usage: npm run import -- <file.csv>');
    process.exit(1);
  }
  const abs = path.resolve(file);
  if (!fs.existsSync(abs)) {
    // eslint-disable-next-line no-console
    console.error(`[import] File tidak ditemukan: ${abs}`);
    process.exit(1);
  }

  const log = (...a) => console.log('[import]', ...a); // eslint-disable-line no-console
  const fail = (title, items) => {
    // eslint-disable-next-line no-console
    console.error(`\n[import] GAGAL — ${title}:`);
    items.slice(0, 50).forEach((e) => console.error('  - ' + e)); // eslint-disable-line no-console
    if (items.length > 50) console.error(`  ...dan ${items.length - 50} lagi`); // eslint-disable-line no-console
    process.exit(1);
  };

  await verifyConnection();

  log(`Membaca ${abs}`);
  const rows = readCsv(abs);
  log(`${rows.length} baris terbaca, memvalidasi...`);

  const { people, ids, errors } = validate(rows);
  if (errors.length) fail('validasi struktur', errors);

  const missing = await findMissingParents(people, ids);
  if (missing.length) {
    fail(
      'referensi orang tua tidak ditemukan (tidak di file maupun DB)',
      missing
    );
  }

  const cycles = detectCycles(people);
  if (cycles.length) fail('siklus terdeteksi (orang jadi leluhurnya sendiri)', cycles);

  log('Validasi OK. Menyiapkan schema...');
  await ensureSchema();

  log(`Mengimpor ${people.length} orang...`);
  await importNodes(people);

  log('Mengimpor relasi...');
  const relCount = await importRelationships(people);

  log(`Selesai. ${people.length} orang, ${relCount} relasi (MERGE, idempoten).`);
}

// Hanya jalan saat dipanggil langsung; fungsi diekspor untuk pengujian.
if (require.main === module) {
  main()
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[import] Error:', err.message);
      process.exitCode = 1;
    })
    .finally(async () => {
      await closeDriver();
    });
}

module.exports = { validate, detectCycles };
