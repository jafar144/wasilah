'use strict';

const express = require('express');
const router = express.Router();
const relationshipService = require('../services/relationshipService');

/** GET /api/relationship?a=p4&b=p6 */
router.get('/', async (req, res, next) => {
  try {
    const a = (req.query.a || '').toString().trim();
    const b = (req.query.b || '').toString().trim();

    if (!a || !b) {
      return res
        .status(400)
        .json({ error: 'Parameter "a" dan "b" (id orang) wajib diisi' });
    }

    const result = await relationshipService.findRelationship(a, b);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
