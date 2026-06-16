'use strict';

const express = require('express');
const { generateList } = require('../khataman');

const router = express.Router();

function escapeHtml(s) {
  return s.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
}

// Halaman list khataman bulan berjalan + tombol Salin. Tinggal copy lalu tempel ke grup WA.
router.get('/', (req, res) => {
  // Opsional: ?bulan=1-12 & ?tahun=YYYY untuk lihat bulan lain (preview/koreksi).
  const bulan = Number(req.query.bulan);
  const tahun = Number(req.query.tahun);
  const when =
    bulan >= 1 && bulan <= 12
      ? { month: bulan, year: tahun || new Date().getFullYear() }
      : undefined;

  const text = generateList(when);

  res.type('html').send(`<!doctype html>
<html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>List Khataman</title>
<style>
  :root{color-scheme:light dark}
  body{font-family:system-ui,-apple-system,sans-serif;max-width:560px;margin:0 auto;padding:20px;line-height:1.5}
  h2{font-size:1.1rem}
  pre{background:#f4f4f5;color:#111;border-radius:10px;padding:14px;white-space:pre-wrap;word-break:break-word;font-size:14px}
  button{font-size:16px;padding:12px 18px;border:0;border-radius:10px;background:#16a34a;color:#fff;width:100%}
  button:active{opacity:.85}
  .ok{color:#16a34a;font-weight:600;text-align:center;margin-top:10px;min-height:1.2em}
</style></head><body>
<h2>List Khataman bulan ini</h2>
<pre id="teks">${escapeHtml(text)}</pre>
<button id="bagikan">📤 Bagikan ke WhatsApp</button>
<div class="ok" id="status"></div>
<script>
  const teks = document.getElementById('teks').textContent;
  const status = document.getElementById('status');

  async function salinClipboard() {
    try {
      await navigator.clipboard.writeText(teks);
    } catch (e) {
      const ta = document.createElement('textarea');
      ta.value = teks; document.body.appendChild(ta); ta.select();
      document.execCommand('copy'); ta.remove();
    }
    status.textContent = '✅ Tersalin! Tinggal tempel ke grup WhatsApp.';
  }

  document.getElementById('bagikan').addEventListener('click', async () => {
    // Web Share API: di HP memunculkan menu share bawaan -> pilih WhatsApp.
    if (navigator.share) {
      try {
        await navigator.share({ text: teks });
        status.textContent = '';
        return;
      } catch (e) {
        // User membatalkan share, atau gagal -> jatuh ke salin.
        if (e && e.name === 'AbortError') { status.textContent = ''; return; }
      }
    }
    // Fallback (desktop / tanpa Web Share): salin ke clipboard.
    await salinClipboard();
  });
</script>
</body></html>`);
});

module.exports = router;
