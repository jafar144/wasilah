'use strict';

require('dotenv').config();
const express = require('express');
const cors = require('cors');

const peopleRoutes = require('./routes/people');
const relationshipRoutes = require('./routes/relationship');
const { verifyConnection, closeDriver } = require('./db/connection');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Healthcheck sederhana.
app.get('/health', (req, res) => res.json({ status: 'ok', service: 'wasilah-backend' }));

app.use('/api/people', peopleRoutes);
app.use('/api/relationship', relationshipRoutes);

// 404 handler.
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint tidak ditemukan' });
});

// Error handler terpusat.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // eslint-disable-next-line no-console
  console.error('[error]', err);
  res.status(500).json({
    error: 'Terjadi kesalahan pada server',
    detail: err.message,
  });
});

async function start() {
  try {
    await verifyConnection();
    // eslint-disable-next-line no-console
    console.log('[startup] Koneksi Neo4j OK');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(
      '[startup] Gagal terhubung ke Neo4j. Cek kredensial di .env.\n',
      err.message
    );
  }

  const server = app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`[startup] Wasilah backend berjalan di http://localhost:${PORT}`);
  });

  const shutdown = async (signal) => {
    // eslint-disable-next-line no-console
    console.log(`\n[shutdown] ${signal} diterima, menutup server...`);
    server.close(async () => {
      await closeDriver();
      process.exit(0);
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

start();

module.exports = app;
