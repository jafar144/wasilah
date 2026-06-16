'use strict';

const crypto = require('crypto');
const { runQuery, neo4j } = require('../db/connection');

/**
 * Cari orang berdasarkan nama (pencocokan sebagian, case-insensitive).
 * Menyertakan nama ayah & kakek untuk disambiguasi orang bernama sama.
 */
async function searchPeople(q, limit = 25) {
  const query = `
    MATCH (p:Person)
    WHERE toLower(p.name) CONTAINS toLower($q)
    OPTIONAL MATCH (p)-[:CHILD_OF { via: 'father' }]->(father:Person)
    OPTIONAL MATCH (father)-[:CHILD_OF { via: 'father' }]->(grandfather:Person)
    RETURN p.id          AS id,
           p.name        AS name,
           p.gender      AS gender,
           father.name   AS fatherName,
           grandfather.name AS grandfatherName
    ORDER BY p.name
    LIMIT $limit
  `;
  const records = await runQuery(
    query,
    // LIMIT di Cypher wajib Integer; JS number dikirim driver sebagai Float
    // sehingga harus dibungkus neo4j.int(), kalau tidak query error 500.
    { q: q || '', limit: neo4j.int(Number(limit)) },
    'READ'
  );
  return records.map((r) => ({
    id: r.get('id'),
    name: r.get('name'),
    gender: r.get('gender'),
    fatherName: r.get('fatherName'),
    grandfatherName: r.get('grandfatherName'),
  }));
}

/** Profil satu orang: data dasar + ayah, ibu, dan anak-anak langsung. */
async function getPersonById(id) {
  const query = `
    MATCH (p:Person {id: $id})
    OPTIONAL MATCH (p)-[:CHILD_OF { via: 'father' }]->(father:Person)
    OPTIONAL MATCH (p)-[:CHILD_OF { via: 'mother' }]->(mother:Person)
    OPTIONAL MATCH (child:Person)-[:CHILD_OF]->(p)
    WITH p, father, mother, collect(DISTINCT child) AS children
    RETURN
      { id: p.id, name: p.name, gender: p.gender } AS person,
      CASE WHEN father IS NULL THEN NULL
           ELSE { id: father.id, name: father.name } END AS father,
      CASE WHEN mother IS NULL THEN NULL
           ELSE { id: mother.id, name: mother.name } END AS mother,
      [c IN children | { id: c.id, name: c.name, gender: c.gender }] AS children
  `;
  const records = await runQuery(query, { id }, 'READ');
  if (records.length === 0) return null;
  const r = records[0];
  const person = r.get('person');
  return {
    ...person,
    father: r.get('father'),
    mother: r.get('mother'),
    children: r.get('children'),
  };
}

/**
 * Cek kemungkinan duplikat sebelum input: orang bernama sama & gender sama
 * yang berdekatan (orang tua / saudara) dengan ayah yang diberikan.
 */
async function findPossibleDuplicates(name, gender, fatherId) {
  if (!fatherId) return [];
  const query = `
    MATCH (p:Person {id: $fatherId})-[:CHILD_OF*0..1]-(existing:Person)
    WHERE toLower(existing.name) = toLower($name)
      AND existing.gender = $gender
    RETURN existing.id AS id, existing.name AS name
    LIMIT 5
  `;
  const records = await runQuery(
    query,
    { fatherId, name, gender },
    'READ'
  );
  return records.map((r) => ({ id: r.get('id'), name: r.get('name') }));
}

/** Cek apakah menambah relasi child->parent akan membuat siklus. */
async function wouldCreateCycle(childId, parentId) {
  if (!parentId || childId === parentId) return childId === parentId;
  const query = `
    MATCH (parent:Person {id: $parentId})-[:CHILD_OF*1..]->(ancestor:Person {id: $childId})
    RETURN count(ancestor) > 0 AS wouldCreateCycle
  `;
  const records = await runQuery(query, { childId, parentId }, 'READ');
  return records.length > 0 && records[0].get('wouldCreateCycle');
}

/** Tambah orang baru beserta relasi ke ayah dan/atau ibu. */
async function createPerson({ name, gender, fatherId, motherId }) {
  const id = crypto.randomUUID();
  const query = `
    CREATE (p:Person { id: $id, name: $name, gender: $gender })
    WITH p
    CALL {
      WITH p
      OPTIONAL MATCH (father:Person { id: $fatherId })
      FOREACH (_ IN CASE WHEN father IS NULL THEN [] ELSE [1] END |
        CREATE (p)-[:CHILD_OF { via: 'father' }]->(father))
    }
    CALL {
      WITH p
      OPTIONAL MATCH (mother:Person { id: $motherId })
      FOREACH (_ IN CASE WHEN mother IS NULL THEN [] ELSE [1] END |
        CREATE (p)-[:CHILD_OF { via: 'mother' }]->(mother))
    }
    RETURN p.id AS id
  `;
  await runQuery(query, {
    id,
    name,
    gender,
    fatherId: fatherId || null,
    motherId: motherId || null,
  });
  return getPersonById(id);
}

module.exports = {
  searchPeople,
  getPersonById,
  findPossibleDuplicates,
  wouldCreateCycle,
  createPerson,
};
