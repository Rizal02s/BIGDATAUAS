# Hasil verifikasi

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
