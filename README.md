# Wasilah — Pelacak Hubungan Keluarga (Nasab)

Aplikasi untuk memetakan dan menelusuri hubungan kekerabatan: pilih dua orang
(A & B), aplikasi menampilkan **bagaimana keduanya terhubung** dan **di leluhur
mana mereka bertemu** (titik temu / *lowest common ancestor*), termasuk apakah
jalurnya lewat ayah atau ibu.

```
wasilah-app  (Flutter)  ──REST/JSON──▶  wasilah-backend (Node.js + Express)  ──Bolt──▶  Neo4j
```

- **Neo4j (graph DB)** — "cari titik temu A↔B" = shortest path / LCA, operasi
  native graph database.
- **Backend perantara** — wajib: tidak ada driver Neo4j resmi untuk Dart, dan
  kredensial DB tidak boleh tertanam di aplikasi mobile.
- **Flutter** — satu basis kode Android & iOS.

---

## Cara Menjalankan

### 1. Neo4j Aura
1. Buat instance **AuraDB Free** di <https://neo4j.com/cloud/aura/>.
2. Simpan **Connection URI**, **username** (`neo4j`), dan **password**.
3. Tunggu status **Running**.

### 2. Backend
```bash
cd wasilah-backend
npm install
cp .env.example .env       # isi kredensial Neo4j Aura
npm run seed               # import data dummy (16 orang, pohon contoh)
npm run dev                # server di http://localhost:3000
```

Uji cepat:
```bash
curl "http://localhost:3000/api/people/search?q=Alawi"
curl "http://localhost:3000/api/relationship?a=p4&b=p6"   # -> Sepupu pertama, LCA p1
```

### 3. Impor massal (CSV) — opsional
Untuk memasukkan data nasab dalam jumlah besar (mis. dari satu kitab), pakai
script impor, **bukan** form di aplikasi.
```bash
cd wasilah-backend
npm run import -- data/people.sample.csv
```
Format CSV (header wajib, satu baris = satu orang; lihat `data/people.sample.csv`):
```
id,name,gender,father_id,mother_id
p1,Ahmad,m,,
p2,Ubaidillah,m,p1,
p10,Ali,m,p7,p9
```
- `id` stabil & unik (dari sumber); `father_id`/`mother_id` menunjuk `id` baris lain
  (atau orang yang sudah ada di DB), kosongkan jika tidak diketahui.
- **Idempoten** (MERGE) — aman dijalankan ulang untuk koreksi; **aditif** (tidak
  menghapus data lama). Reset total → `npm run seed`.
- Validasi dulu sebelum menulis: id duplikat, gender salah, referensi orang tua
  hilang, dan **siklus** (orang jadi leluhurnya sendiri) akan membatalkan impor.
- Tips: pencatat bisa menyiapkan data di Excel/Google Sheets lalu *export CSV*.

### 4. Flutter app
```bash
cd wasilah-app
flutter create .           # generate folder platform (android/ios/...) — tidak menimpa lib/
flutter pub get
flutter run
```
> Atur `lib/config/app_config.dart`:
> - Android emulator → `http://10.0.2.2:3000/api`
> - iOS simulator → `http://localhost:3000/api`
> - Device fisik → `http://<IP-laptop>:3000/api`

---

## Endpoint API

| Method | Path | Keterangan |
|--------|------|------------|
| GET | `/api/people/search?q=` | Cari orang (pencocokan sebagian; menyertakan nama ayah/kakek untuk disambiguasi) |
| GET | `/api/people/:id` | Profil orang (ayah, ibu, anak-anak) |
| GET | `/api/people/check-duplicate?name=&gender=&fatherId=` | Cek kemungkinan duplikat sebelum simpan |
| POST | `/api/people` | Tambah orang `{name, gender, fatherId, motherId}` |
| GET | `/api/relationship?a=&b=` | **Inti** — hubungan A↔B + jalur + titik temu |
| GET | `/health` | Healthcheck |

> Impor massal lewat CLI: `npm run import -- <file.csv>` (lihat bagian 3).

Detail bentuk respons ada di `WASILAH_SETUP_GUIDE.md`.

---

## Model Data Neo4j

```cypher
(:Person { id, name, gender })                  // gender: 'm' | 'f'
// Catatan: kolom `arabic` masih ada di DB lama tapi tidak lagi dipakai/ditampilkan aplikasi.
(anak)-[:CHILD_OF { via: 'father' }]->(ayah)
(anak)-[:CHILD_OF { via: 'mother' }]->(ibu)
```
Arah anak→orang tua membuat query "cari semua leluhur" jadi natural
(`MATCH (p)-[:CHILD_OF*1..]->(ancestor)`). Memasukkan jalur ibu mengubah pohon
menjadi graph — dua orang bisa terhubung lewat lebih dari satu jalur.

## Status
MVP sesuai PRD Fase 1: data dasar, cari orang, cari hubungan A↔B + visualisasi
jalur sederhana. Di luar cakupan MVP: crowdsourcing/verifikasi, biografi/foto,
ekspor/berbagi, multi-bahasa.
