'use strict';

const { runQuery } = require('../db/connection');

/**
 * Query inti: cari leluhur bersama terdekat (LCA) antara dua orang.
 *
 * Arah relasi: (anak)-[:CHILD_OF]->(orang tua), sehingga menelusuri ke atas
 * (ke leluhur) cukup mengikuti CHILD_OF. Kita kumpulkan semua leluhur bersama,
 * lalu pilih yang total jaraknya (depthA + depthB) paling kecil — itulah titik
 * temu terdekat. abs(depthA - depthB) dipakai sebagai tie-breaker agar jalur
 * yang seimbang lebih diutamakan.
 *
 * Hasil chainA/typesA dikembalikan urutan anak->lca, lalu di-reverse di JS
 * sehingga chainA[0] = LCA dan chainA[last] = orang A.
 */
const LCA_QUERY = `
MATCH pathA = (a:Person {id: $idA})-[:CHILD_OF*0..30]->(lca:Person)
MATCH pathB = (b:Person {id: $idB})-[:CHILD_OF*0..30]->(lca)
WITH lca, pathA, pathB,
     length(pathA) AS depthA,
     length(pathB) AS depthB
ORDER BY (depthA + depthB) ASC, abs(depthA - depthB) ASC
LIMIT 1
RETURN
  { id: lca.id, name: lca.name, gender: lca.gender } AS lca,
  depthA,
  depthB,
  [n IN nodes(pathA) | { id: n.id, name: n.name, gender: n.gender }] AS chainA,
  [r IN relationships(pathA) | r.via]                                AS typesA,
  [n IN nodes(pathB) | { id: n.id, name: n.name, gender: n.gender }] AS chainB,
  [r IN relationships(pathB) | r.via]                                AS typesB
`;

const ORDINALS = [
  'pertama',
  'kedua',
  'ketiga',
  'keempat',
  'kelima',
  'keenam',
  'ketujuh',
  'kedelapan',
];

function ordinal(n) {
  return ORDINALS[n - 1] || `ke-${n}`;
}

/** Sebutan generasi leluhur langsung (jarak ke atas). */
function directAncestorTerm(distance, gender) {
  const male = gender !== 'f';
  switch (distance) {
    case 1:
      return male ? 'Ayah' : 'Ibu';
    case 2:
      return male ? 'Kakek' : 'Nenek';
    case 3:
      return male ? 'Buyut' : 'Buyut';
    case 4:
      return 'Canggah';
    case 5:
      return 'Wareng';
    default:
      return `Leluhur (${distance} generasi ke atas)`;
  }
}

/**
 * Bangun label + deskripsi ramah-pengguna dari kedalaman jalur.
 * @param {number} depthA jarak A ke LCA
 * @param {number} depthB jarak B ke LCA
 * @param {{name:string, arabic:string, gender:string}} lca
 * @param {{gender:string}} personA
 * @param {{gender:string}} personB
 */
function describeRelationship(depthA, depthB, lca, personA, personB) {
  // Orang yang sama.
  if (depthA === 0 && depthB === 0) {
    return {
      label: 'Orang yang sama',
      description: 'A dan B adalah orang yang sama.',
    };
  }

  // Garis lurus: salah satu adalah leluhur dari yang lain.
  if (depthA === 0 || depthB === 0) {
    const distance = Math.max(depthA, depthB);
    // Yang depth-nya 0 adalah leluhurnya.
    const ancestorIsA = depthA === 0;
    const ancestorGender = ancestorIsA ? personA.gender : personB.gender;
    const term = directAncestorTerm(distance, ancestorGender);
    const who = ancestorIsA ? 'A' : 'B';
    const other = ancestorIsA ? 'B' : 'A';
    return {
      label: term,
      description: `${who} adalah ${term.toLowerCase()} dari ${other} (terpaut ${distance} generasi garis lurus).`,
    };
  }

  const g = Math.min(depthA, depthB);
  const removed = Math.abs(depthA - depthB);

  // Saudara (bertemu di orang tua).
  if (g === 1 && removed === 0) {
    return {
      label: 'Saudara',
      description: `A dan B bersaudara — sama-sama anak dari ${lca.name}.`,
    };
  }

  // Paman/Bibi <-> keponakan (g === 1, removed >= 1).
  if (g === 1) {
    const deeperIsA = depthA > depthB;
    const elder = deeperIsA ? 'B' : 'A';
    const younger = deeperIsA ? 'A' : 'B';
    const elderGender = deeperIsA ? personB.gender : personA.gender;
    const term = elderGender === 'f' ? 'Bibi' : 'Paman';
    const suffix = removed === 1 ? '' : ` (terpaut ${removed} generasi)`;
    return {
      label: `${term}${removed === 1 ? '' : ' jauh'}`,
      description: `${elder} adalah ${term.toLowerCase()} dari ${younger}${suffix}, bertemu pada ${lca.name}.`,
    };
  }

  // Sepupu. Derajat = (jarak terdekat ke LCA) - 1.
  const degree = g - 1;
  let label = `Sepupu ${ordinal(degree)}`;
  if (removed > 0) label += ` (beda ${removed} generasi)`;
  return {
    label,
    description: `Keduanya bertemu pada ${lca.name} — terpaut ${depthA} generasi di sisi A dan ${depthB} generasi di sisi B.`,
  };
}

/**
 * Cari hubungan antara dua orang berdasarkan id.
 * @returns {Promise<Object>} payload siap dikirim ke client.
 */
async function findRelationship(idA, idB) {
  if (idA === idB) {
    const records = await runQuery(
      'MATCH (p:Person {id: $id}) RETURN { id: p.id, name: p.name, gender: p.gender } AS p',
      { id: idA },
      'READ'
    );
    if (records.length === 0) {
      return {
        found: false,
        label: 'Tidak ditemukan',
        description: 'Salah satu orang tidak ada dalam data.',
      };
    }
    const p = records[0].get('p');
    return {
      found: true,
      label: 'Orang yang sama',
      description: 'A dan B adalah orang yang sama.',
      lca: p,
      depthA: 0,
      depthB: 0,
      chainA: [p],
      typesA: [],
      chainB: [p],
      typesB: [],
    };
  }

  const records = await runQuery(LCA_QUERY, { idA, idB }, 'READ');

  if (records.length === 0) {
    return {
      found: false,
      label: 'Tidak ditemukan',
      description: 'Tidak ada leluhur bersama dalam data yang tersedia.',
    };
  }

  const rec = records[0];
  const lca = rec.get('lca');
  const depthA = rec.get('depthA').toNumber();
  const depthB = rec.get('depthB').toNumber();

  // Query mengembalikan urutan anak->lca; reverse agar lca->orang.
  const chainA = rec.get('chainA').slice().reverse();
  const typesA = rec.get('typesA').slice().reverse();
  const chainB = rec.get('chainB').slice().reverse();
  const typesB = rec.get('typesB').slice().reverse();

  const personA = chainA[chainA.length - 1];
  const personB = chainB[chainB.length - 1];

  const { label, description } = describeRelationship(
    depthA,
    depthB,
    lca,
    personA,
    personB
  );

  return {
    found: true,
    label,
    description,
    lca,
    depthA,
    depthB,
    chainA,
    typesA,
    chainB,
    typesB,
  };
}

module.exports = { findRelationship, describeRelationship };
