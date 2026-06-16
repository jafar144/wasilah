'use strict';

const express = require('express');
const router = express.Router();
const personService = require('../services/personService');

/** GET /api/people/search?q=Muhammad */
router.get('/search', async (req, res, next) => {
  try {
    const q = (req.query.q || '').toString().trim();
    const limit = Math.min(Number(req.query.limit) || 25, 100);
    const people = await personService.searchPeople(q, limit);
    res.json(people);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/people/check-duplicate?name=&gender=&fatherId=
 * Dipakai form "tambah orang" untuk memperingatkan kemungkinan duplikat
 * SEBELUM data benar-benar disimpan. Harus didefinisikan sebelum '/:id'
 * agar tidak tertangkap sebagai id.
 */
router.get('/check-duplicate', async (req, res, next) => {
  try {
    const name = (req.query.name || '').toString().trim();
    const gender = (req.query.gender || '').toString();
    const fatherId = (req.query.fatherId || '').toString() || null;
    if (!name || (gender !== 'm' && gender !== 'f')) {
      return res.json([]);
    }
    const matches = await personService.findPossibleDuplicates(
      name,
      gender,
      fatherId
    );
    res.json(matches);
  } catch (err) {
    next(err);
  }
});

/** GET /api/people/:id */
router.get('/:id', async (req, res, next) => {
  try {
    const person = await personService.getPersonById(req.params.id);
    if (!person) {
      return res.status(404).json({ error: 'Orang tidak ditemukan' });
    }
    res.json(person);
  } catch (err) {
    next(err);
  }
});

/** POST /api/people */
router.post('/', async (req, res, next) => {
  try {
    const { name, gender, fatherId, motherId } = req.body || {};

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'Field "name" wajib diisi' });
    }
    if (gender !== 'm' && gender !== 'f') {
      return res.status(400).json({ error: 'Field "gender" harus "m" atau "f"' });
    }

    // Orang baru belum punya keturunan, sehingga menautkannya ke ayah/ibu
    // yang sudah ada tidak mungkin membuat siklus. Cek duplikat dilakukan di
    // sisi klien lewat GET /check-duplicate sebelum submit.

    const person = await personService.createPerson({
      name: name.trim(),
      gender,
      fatherId,
      motherId,
    });

    res.status(201).json(person);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
