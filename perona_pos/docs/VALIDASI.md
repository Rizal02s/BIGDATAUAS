# Hasil verifikasi

**Tanggal order manual, 6 Oktober 2026 (`0.1.4+5`):** 65 tes Flutter lulus,
`flutter analyze lib test tool` tanpa temuan, dan 82 pemeriksaan PostgreSQL
lokal + RLS/RPC lulus. Tes mencakup memilih 3 Oktober pada form, jam manual,
batas tengah malam WIB, pergantian tahun/kabisat, edit tanpa mengubah tanggal,
retry pembayaran yang mempertahankan tanggal/ID, rekap/nota/ongkos sesuai tanggal,
penolakan tanggal tidak valid, akses admin/pending/anon, dan kompatibilitas RPC
APK lama. Preview form diperiksa di [tanggal manual](ui/order-manual-date.png).

Migrasi `004_manual_order_dates.sql` diterapkan pada proyek Supabase Perona
melalui SQL Editor. Hasil **Success. No rows returned**; pemeriksaan kedua
fungsi, kedua kolom riwayat input, dan tidak adanya riwayat kosong semuanya
mengembalikan `true`. Bukti di [verifikasi Supabase](ui/manual-date-supabase.png).
Pemeriksaan online ini hanya memverifikasi migrasi; tidak menambah customer/order
percobaan pada database usaha. Tes transaksi/RLS memakai PostgreSQL lokal.

Build APK release 59,3 MB berhasil dan dipasang sebagai update pada emulator
Pixel 6. Tetap memakai signing proyek yang sama dengan APK sebelumnya.
Pemasangan dan input order pada HP fisik belum diuji dalam pembaruan ini.

**Nota/rincian PDF, 4 Oktober 2026 (`0.1.3+4`):** 58 tes Flutter lulus dan
`flutter analyze lib test tool` tanpa temuan. APK release 58,8 MB dibangun dari
`lib/main.dart`, dipasang sebagai update pada emulator Pixel 6, dan akun owner
tetap masuk. Generator PDF serta UI ekspor diuji untuk periode bulanan,
pagination 61 order, filter pegawai, pembayaran dikoreksi, nama panjang,
55 layanan dalam satu order, periode kosong, pembatalan/gagal unduh, dan retry
nota tanpa menyimpan ulang order.

Contoh nota, rincian pegawai, dan rekap 45 order dirender untuk pemeriksaan
tata letak. Ekstraksi teks memverifikasi total, seluruh order, serta ketiadaan
ongkos/upah/gaji pada nota dan rekap admin. Unduhan Android nyata menghasilkan
PDF valid di Downloads; dialog bagikan menampilkan WhatsApp, dan dialog cetak
menampilkan satu halaman nota. Uji Android PDF memakai data contoh tanpa
Supabase; tidak ada pesan dikirim ataupun order produksi dibuat. Printer
fisik/pengiriman ke customer pada HP nyata belum diuji. Tidak ada migrasi SQL
baru. Panduan penggunaan: [PDF.md](PDF.md).

**Riwayat peran baru pada 4 Oktober 2026:** 45 tes Flutter dan 55 pemeriksaan PostgreSQL
lokal lulus. Admin memakai API tanpa tarif/snapshot ongkos dan ditolak membaca
rekap upah atau tabel mentah; input order, pembayaran, serta upload/link foto
tetap berhasil di tes SQL. Owner/teknisi melihat ongkos tim pada halaman sendiri.
Migrasi 003 belum diterapkan pada backend online karena dashboard belum login.
Lihat [AKSES.md](AKSES.md) untuk penerapan dan batas pengujian.

**Pembaruan 4 Oktober 2026:** 39 tes lulus, `flutter analyze lib test` tanpa
temuan, dan build APK release `0.1.1+2` berhasil. Daftar tanggal bulanan diuji
untuk batas WIB, semua halaman timestamp, filter pegawai, tanggal kosong,
navigasi detail/kembali, pemulihan dari error, paginasi satu hari, dan layar kecil
dengan teks 150%. Release masih memakai signing debug proyek; ini APK untuk uji,
bukan bukti signing operasional permanen. Tidak ada migrasi database.

**Pembaruan 3 Oktober 2026:** analisis `lib`/`test`, 16 tes domain/widget,
build APK debug, dan pemasangan pada emulator Pixel 6 berhasil. Rincian dan
preview UI sesuai peran ada di [UI.md](UI.md). Catatan 2 Oktober berikut adalah
hasil pemeriksaan sebelumnya; batas tentang Flutter/build telah diperbarui oleh
pemeriksaan tersebut. Integrasi transaksi/foto online menyeluruh dan perangkat
fisik tetap perlu diuji.

**Pengembangan lanjutan pada tanggal yang sama:** 32 tes domain/widget/HTTP
lulus setelah penambahan tema logo, pembayaran awal, dan foto pada form order.
Tes mencakup kegagalan respons setelah penyimpanan, retry pembayaran/foto,
perubahan tarif sebelum pelunasan, serta detail order dari rekap. HTTP dan data
transaksi dalam tes adalah tiruan; belum membuktikan transaksi/foto pada Supabase
online atau kamera perangkat fisik. Lihat [UI.md](UI.md) untuk perilaku fitur.

Tanggal: 2 Oktober 2026.

## Telah dijalankan

- **12 pemeriksaan domain Dart langsung**, menggunakan Dart SDK dari Flutter 3.35.6. Meliputi nilai order, diskon tanpa mengurangi ongkos, tarif Rp7.500, jumlah invalid, ongkos kosong, batas WIB, Desember ke Januari, Februari dan tahun kabisat.
- **29 pemeriksaan PostgreSQL lokal melalui PGlite 0.5.8**, menjalankan migration/seed asli dengan stub schema Auth/Storage. Meliputi 32 layanan, tarif palsu dari klien, role signup, larangan tulis master dan naik peran bagi staff, versi transaksi, input duplikat, snapshot tarif, retry pembayaran, pembayaran berlebih, upah per pegawai, rekap, audit, akses pending, agregasi >1.000 order, batas WIB dan kebijakan foto.
- Parser PostgreSQL membaca kedua file SQL tanpa error sintaks.
- Parser Dart membaca `lib/main.dart`, `lib/repository.dart`, `lib/domain.dart` tanpa error sintaks.

## Batas verifikasi

PGlite adalah PostgreSQL lokal berbasis WASM. Schema Auth/Storage dibuat sebagai stub agar kebijakan/RPC dapat diuji; ini **bukan Supabase penuh**. HTTP API, email Auth, SDK Flutter, upload perangkat, URL bertanda tangan, Android permission dan kuota belum diuji end-to-end.

Proses bootstrap/verifikasi Flutter penuh diblokir oleh persetujuan otomatis karena mendeteksi akses endpoint metadata lingkungan yang berpotensi memuat kredensial. Proses tersebut tidak diulang. Pemeriksaan domain Dart dijalankan melalui VM mandiri tanpa bootstrap Flutter dan tanpa jaringan.

Belum menjalankan `flutter analyze`, `flutter test` penuh, widget/render test, build APK debug/release, atau pilot dua HP. Paket berisi test yang dapat dijalankan setelah dependency dan toolchain pengguna siap.

## Jalankan kembali

Domain mandiri:

```text
dart scripts/domain_checks.dart
```

Domain dalam Flutter:

```text
flutter test
```

SQL lokal, membutuhkan Node.js dan paket npm:

```text
cd scripts
npm install
npm test
```

Uji lokal menciptakan database baru dalam memori, tidak memanggil backend online.

Sebelum operasional, jalankan `flutter analyze`, uji perangkat nyata, validasi Supabase milik pengguna, dan seluruh skenario pilot di README. Tidak ada secret backend dalam paket ini.
