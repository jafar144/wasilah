'use strict';

/**
 * Import data dummy ke Neo4j Aura.
 *
 * Jalankan: npm run seed
 *
 * Data sengaja memakai id p1..p16 agar konsisten dengan contoh di
 * WASILAH_SETUP_GUIDE.md (mis. relasi p4 <-> p6 = sepupu pertama, LCA p1).
 *
 * Pohon (CHILD_OF = anak -> orang tua). Nama = nama asli saja (tanpa bin/binti);
 * untuk membedakan orang bernama sama, UI memakai nama ayah/kakek.
 *
 *   p1 Ahmad
 *   ├─ p2 Ubaidillah
 *   │   └─ p4 Alawi
 *   │       ├─ p5 Ali
 *   │       └─ p7 Salim
 *   │           ├─ p10 Ali   (ibu: p9 — tautan silang ke cabang p3)
 *   │           │   ├─ p12 Abdullah
 *   │           │   └─ p13 Maryam
 *   │           └─ p11 Aisyah
 *   ├─ p3 Muhammad
 *   │   ├─ p6 Hasan
 *   │   │   ├─ p9 Fatimah
 *   │   │   └─ p14 Zainab
 *   │   └─ p8 Husain
 *   │       └─ p15 Yusuf
 *   └─ p16 Khadijah
 */

require('dotenv').config();
const { runQuery, closeDriver, verifyConnection } = require('./connection');

const PEOPLE = [
  { id: 'p1', name: 'Ahmad', gender: 'm' },
  { id: 'p2', name: 'Ubaidillah', gender: 'm' },
  { id: 'p3', name: 'Muhammad', gender: 'm' },
  { id: 'p4', name: 'Alawi', gender: 'm' },
  { id: 'p5', name: 'Ali', gender: 'm' },
  { id: 'p6', name: 'Hasan', gender: 'm' },
  { id: 'p7', name: 'Salim', gender: 'm' },
  { id: 'p8', name: 'Husain', gender: 'm' },
  { id: 'p9', name: 'Fatimah', gender: 'f' },
  { id: 'p10', name: 'Ali', gender: 'm' },
  { id: 'p11', name: 'Aisyah', gender: 'f' },
  { id: 'p12', name: 'Abdullah', gender: 'm' },
  { id: 'p13', name: 'Maryam', gender: 'f' },
  { id: 'p14', name: 'Zainab', gender: 'f' },
  { id: 'p15', name: 'Yusuf', gender: 'm' },
  { id: 'p16', name: 'Khadijah', gender: 'f' },
];

// [childId, parentId, via]
const RELATIONS = [
  ['p2', 'p1', 'father'],
  ['p3', 'p1', 'father'],
  ['p16', 'p1', 'father'],
  ['p4', 'p2', 'father'],
  ['p5', 'p4', 'father'],
  ['p7', 'p4', 'father'],
  ['p6', 'p3', 'father'],
  ['p8', 'p3', 'father'],
  ['p9', 'p6', 'father'],
  ['p14', 'p6', 'father'],
  ['p15', 'p8', 'father'],
  ['p10', 'p7', 'father'],
  ['p10', 'p9', 'mother'], // tautan silang: Ali bin Salim juga cucu Hasan via ibu
  ['p11', 'p7', 'father'],
  ['p12', 'p10', 'father'],
  ['p13', 'p10', 'father'],
];

async function seed() {
  await verifyConnection();

  // eslint-disable-next-line no-console
  console.log('[seed] Membuat constraint & index...');
  await runQuery(
    `CREATE CONSTRAINT person_id IF NOT EXISTS
       FOR (p:Person) REQUIRE p.id IS UNIQUE`
  );
  await runQuery(
    `CREATE INDEX person_name IF NOT EXISTS
       FOR (p:Person) ON (p.name)`
  );

  // eslint-disable-next-line no-console
  console.log('[seed] Menghapus data lama (label Person)...');
  await runQuery('MATCH (p:Person) DETACH DELETE p');

  // eslint-disable-next-line no-console
  console.log(`[seed] Membuat ${PEOPLE.length} orang...`);
  await runQuery(
    `UNWIND $people AS row
     CREATE (p:Person { id: row.id, name: row.name, gender: row.gender })`,
    { people: PEOPLE }
  );

  // eslint-disable-next-line no-console
  console.log(`[seed] Membuat ${RELATIONS.length} relasi CHILD_OF...`);
  await runQuery(
    `UNWIND $rels AS row
     MATCH (child:Person { id: row[0] })
     MATCH (parent:Person { id: row[1] })
     CREATE (child)-[:CHILD_OF { via: row[2] }]->(parent)`,
    { rels: RELATIONS }
  );

  // eslint-disable-next-line no-console
  console.log('[seed] Selesai. Contoh uji: GET /api/relationship?a=p4&b=p6');
}

seed()
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error('[seed] Gagal:', err.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closeDriver();
  });
