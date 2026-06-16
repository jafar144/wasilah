'use strict';

// Daftar peserta khataman (30 nama = 30 juz). Urutan ini yang dirotasi tiap bulan.
const NAMES = [
  'Aliyah', 'Zulfa', 'Abubakar', 'Lubna', 'Zaki', 'Wansila', 'Sakinah', 'Ridho',
  'Farhan', 'Fatema', 'Hasyim', "Ja'far", 'Muhammad', 'Zainab', 'Shammy',
  'Taufik', 'Wasila A', 'Fadlia', 'Aluyah', 'Hanni', 'Khodijah', 'Aliyah Alkaf', 'Rahma',
  'Anisah', 'Hanif', 'Nafisah', 'Fatimah', 'Fauziah', 'Atika', 'Aminah',
];

// Acuan rotasi: Juni 2026, Juz 1 dimulai dari indeks 22 (Rahma).
// Tiap bulan berikutnya maju 1 orang dan berputar penuh tiap 30 bulan
// (kontinu antar-tahun, bukan reset tiap Januari — karena ada 30 nama).
const ANCHOR_YEAR = 2026;
const ANCHOR_MONTH = 6; // Juni (1-12)
const ANCHOR_SHIFT = 22;

const BULAN_ID = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

// Ambil tahun & bulan (1-12) menurut zona waktu Asia/Jakarta, lepas dari TZ server.
function jakartaNow() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date());
  return {
    year: Number(parts.find((p) => p.type === 'year').value),
    month: Number(parts.find((p) => p.type === 'month').value), // 1-12
  };
}

/**
 * Membuat teks list khataman.
 * @param {{year:number, month:number}} [when] bulan 1-12; default bulan berjalan (Jakarta).
 * @returns {string}
 */
function generateList(when) {
  const { year, month } = when || jakartaNow();
  const monthIndex = month - 1; // 0-11

  const monthsSince = (year - ANCHOR_YEAR) * 12 + (monthIndex - (ANCHOR_MONTH - 1));
  const shift = (((ANCHOR_SHIFT + monthsSince) % NAMES.length) + NAMES.length) % NAMES.length;
  const rotated = [...NAMES.slice(shift), ...NAMES.slice(0, shift)];

  const lastDay = new Date(year, month, 0).getDate();
  const start = `1 ${BULAN_ID[monthIndex]} ${year}`;
  const end = `${lastDay} ${BULAN_ID[monthIndex]} ${year}`;

  let text = "*Khataman keluarga Habib Ja'far bin Abdullah Assegaf*\n";
  text += `~ ${start} s/d ${end}\n\n`;
  rotated.forEach((name, i) => {
    text += `Juz ${i + 1} ${name}\n`;
  });

  return text;
}

module.exports = { generateList, NAMES };
