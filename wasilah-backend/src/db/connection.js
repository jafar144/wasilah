'use strict';

const neo4j = require('neo4j-driver');
require('dotenv').config();

const { NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD } = process.env;

if (!NEO4J_URI || !NEO4J_USER || !NEO4J_PASSWORD) {
  // eslint-disable-next-line no-console
  console.error(
    '\n[connection] Kredensial Neo4j belum lengkap. ' +
      'Salin .env.example menjadi .env dan isi NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD.\n'
  );
}

// Fallback agar pembuatan driver tidak crash saat .env belum diisi —
// error koneksi yang sebenarnya akan muncul di verifyConnection() dengan
// pesan yang ramah, bukan stack trace saat import.
const driver = neo4j.driver(
  NEO4J_URI || 'neo4j://localhost:7687',
  neo4j.auth.basic(NEO4J_USER || 'neo4j', NEO4J_PASSWORD || 'password'),
  {
    maxConnectionPoolSize: 50,
    connectionAcquisitionTimeout: 30000,
  }
);

/**
 * Jalankan satu query Cypher di sesi read/write dan kembalikan record-nya.
 * @param {string} cypher
 * @param {Object} [params]
 * @param {'READ'|'WRITE'} [mode]
 * @returns {Promise<import('neo4j-driver').Record[]>}
 */
async function runQuery(cypher, params = {}, mode = 'WRITE') {
  const session = driver.session({
    defaultAccessMode:
      mode === 'READ' ? neo4j.session.READ : neo4j.session.WRITE,
  });
  try {
    const result = await session.run(cypher, params);
    return result.records;
  } finally {
    await session.close();
  }
}

/** Verifikasi koneksi saat startup. */
async function verifyConnection() {
  await driver.verifyConnectivity();
}

/** Tutup driver saat aplikasi berhenti. */
async function closeDriver() {
  await driver.close();
}

module.exports = { driver, runQuery, verifyConnection, closeDriver, neo4j };
