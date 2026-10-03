# Perona Kasir — Flutter + Supabase

MVP kasir jasa Perona Sepatu untuk Android. Dibuat dari nol berdasarkan dua gambar yang diberikan pada 2 Oktober 2026.

**Status:** kode aplikasi dan database tersedia. Pada 3 Oktober 2026, analisis Flutter pada `lib`/`test`, 32 tes domain/widget/HTTP, dan build APK debug berhasil. APK debug sudah dipasang pada emulator Pixel 6 untuk pemeriksaan tampilan. Kamera di perangkat nyata, integrasi transaksi/foto Supabase secara menyeluruh, dan APK release belum diverifikasi. Gunakan data uji dahulu.

## Keputusan yang sudah dipilih

- Aplikasi pertama: **Flutter Android**.
- Acuan harga: **tabel harga customer dan ongkos kerja pegawai**.
- Hak ongkos dihitung **saat order masuk**, mengikuti penanggung jawab setiap item layanan.
- Upah dihitung per unit/pasang × tarif ongkos; bukan persentase harga jual.
- Diskon customer tidak mengurangi ongkos kerja pegawai.
- Periode harian/bulanan/tahunan memakai **Asia/Jakarta/WIB**, meskipun zona waktu HP berbeda.

## Fitur yang ada dalam kode

**Home sesuai peran:** owner mendapat ringkasan usaha dan pengelolaan tim;
pegawai mendapat ongkos pribadinya serta pekerjaan yang ditugaskan kepadanya.
Navigasi owner: Ringkasan, Order, Layanan, Pegawai. Navigasi pegawai: Beranda,
Order, Layanan. Rincian tampilan dan hasil pemeriksaan ada di [docs/UI.md](docs/UI.md).

| Halaman | Fungsi |
|---|---|
| Masuk/daftar | Akun email/password; akun baru menunggu aktivasi owner |
| Rekap | Periode harian, bulanan, tahunan; nilai order, pembayaran masuk, ongkos, diskon, piutang, rincian upah per pegawai |
| Input order | Pelanggan, nomor WA, catatan, layanan, jumlah, penanggung jawab, status, diskon, pembayaran awal Tunai/QRIS/Belum lunas, serta foto kamera/galeri |
| Detail order | Ringkasan lunas/piutang dan metode bayar, layanan/pegawai, edit, pembayaran bertahap, riwayat pembayaran, dan foto barang |
| Layanan | 32 tarif awal; owner dapat tambah, edit, nonaktifkan layanan tanpa dashboard backend |
| Pegawai | Owner mengaktifkan, menonaktifkan, atau memberi akses owner kepada akun terdaftar |
| Penghapusan | Owner dapat menghapus order dari rekap dengan alasan; jejak audit disimpan |

**Pegawai aktif dapat melihat seluruh transaksi dan tarif ongkos untuk operasional bersama.** Privasi upah hanya untuk masing-masing pegawai belum diterapkan pada MVP ini. Owner mengelola tarif, akun, penghapusan, dan koreksi pembayaran. Pegawai boleh input/edit order, foto dan pembayaran. Rancangan ini untuk satu usaha/outlet dalam satu proyek Supabase.

## Contoh hitungan

2 Deep Clean: 2 × Rp30.000 = Rp60.000; ongkos 2 × Rp10.000 = Rp20.000.

1 One Day Service: Rp50.000; ongkos Rp20.000.

Total sebelum diskon Rp110.000. Jika diskon Rp10.000, tagihan Rp100.000, ongkos tetap Rp40.000. Sisa setelah upah Rp60.000 **bukan laba bersih**, karena bahan, sewa, listrik dan biaya lainnya belum dihitung.

Jika dua Deep Clean dikerjakan Pegawai A dan ODS oleh Pegawai B, upah A Rp20.000 dan B Rp20.000. Jika hanya dibayar DP Rp30.000, pembayaran masuk Rp30.000 dan sisa tagihan Rp70.000; upah tetap tercatat saat order masuk.

## Hal penting dari gambar

- Recolour Midsole memakai **Rp60.000** customer / **Rp30.000** ongkos sesuai tabel. Poster mencantumkan Rp50.000.
- Recolour Upper Leather Low memakai Rp110.000 / Rp30.000. Poster menulis dua baris “High”; nama Low mengikuti tabel ongkos.
- Repaint/Recolour Bag Rp200.000–250.000 ada pada poster tetapi **tidak dimasukkan sebagai tarif siap pakai**, karena tabel tidak memberikan ongkos kerjanya. Owner dapat menambahkannya setelah menentukan harga pasti dan ongkos.
- Helm Full Face + Compound ongkos Rp15.000 dan Repair Lem+Jahit ongkos Rp35.000 disalin apa adanya dari tabel.
- Nama Sandal/Topi/Cap mengikuti satu baris tabel. Dapat dipisah menjadi layanan tersendiri oleh owner jika dibutuhkan.

## Isi folder

- `lib/main.dart`: halaman aplikasi.
- `lib/repository.dart`: login/data/foto dan pemanggilan RPC Supabase.
- `lib/domain.dart`: perhitungan rupiah dan batas periode WIB.
- `supabase/001_schema.sql`: tabel, validasi transaksi, hak akses, audit, bucket foto privat.
- `supabase/002_seed.sql`: 32 layanan awal; tidak menimpa tarif yang telah diubah owner jika dijalankan ulang.
- `data/price_list.csv` dan `data/services.json`: transkripsi harga.
- `test/domain_test.dart`: tes domain untuk `flutter test`.
- `scripts/domain_checks.dart`: tes domain Dart mandiri yang telah dijalankan.
- `scripts/integration.mjs`: pengujian PostgreSQL lokal dengan PGlite dan stub Auth/Storage.
- `scripts/bootstrap.ps1`: membuat kerangka Android pada Windows sambil menjaga kode aplikasi.
- `docs/RANCANGAN.md`: konsep dan tahap menuju penggunaan online.
- `docs/VALIDASI.md`: hasil dan batas pemeriksaan.

Kerangka platform `android/` dibuat lewat bootstrap. Paket ini tidak menyertakan Flutter SDK, Android SDK, konfigurasi proyek pengguna, atau APK.

## 1. Siapkan Flutter di laptop Windows

Flutter dan Android SDK harus terpasang. Ikuti [panduan resmi Flutter](https://docs.flutter.dev/get-started/install) bila belum tersedia. Flutter 3.35.x atau versi stabil yang lebih baru menjadi acuan, dengan Dart minimal 3.7. Periksa:

```powershell
flutter --version
flutter doctor
```

Pastikan bagian Android toolchain sudah siap. Jangan memperbarui Java secara sembarang jika project Hadoop masih memakai Java 8; Android toolchain Flutter memiliki kebutuhan JDK sendiri.

Ekstrak paket ZIP, buka folder `perona_pos` di VS Code dan terminal PowerShell. Jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
```

Script memanggil `flutter create --no-pub`, menjaga `lib/`, `test/` dan `pubspec.yaml`, serta menambahkan izin Internet untuk Android release. Tidak memerlukan mode administrator.

Jika menjalankan `flutter create` manual, simpan salinan kode terlebih dahulu dan tambahkan baris ini di luar `<application>` dalam `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

## 2. Buat backend Supabase satu kali

1. Buat akun dan proyek **Free** di [Supabase](https://supabase.com/), pilih region dekat pengguna jika tersedia. Simpan password database di tempat pribadi.
2. Di SQL Editor, jalankan seluruh `supabase/001_schema.sql` **sekali, pada proyek baru**. Jangan jalankan pada database usaha lain atau mengulang migrasi awal yang sudah berhasil.
3. Jalankan `supabase/002_seed.sql` untuk mengisi price list.
4. Untuk pilot internal tanpa layanan email, atur Authentication → Email agar konfirmasi email tidak diwajibkan. Akun tetap menunggu persetujuan owner di aplikasi. Jika menggunakan konfirmasi email, siapkan SMTP dan URL konfirmasinya lebih dahulu.
5. Ambil **Project URL** dan **publishable key / anon key** dari pengaturan API/Connect proyek. Nama menu dashboard bisa berubah.
6. Salin `config.example.json` menjadi `config.json` dan isi dua nilai tersebut.

Contoh format:

```json
{
  "SUPABASE_URL": "https://project-kamu.supabase.co",
  "SUPABASE_KEY": "publishable-key-atau-anon-key"
}
```

Gunakan key untuk aplikasi publik. **Jangan masukkan secret key/service_role/database password ke aplikasi atau percakapan.** Izin akses database diatur melalui RLS dan RPC, bukan dengan menyembunyikan publishable key. Jangan membuka bucket foto ke publik atau mematikan RLS.

Dashboard backend diperlukan untuk setup awal dan pemeliharaan, bukan untuk input transaksi, foto, price list, atau aktivitas kasir sehari-hari.

## 3. Jalankan aplikasi dan aktifkan owner pertama

```powershell
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run --dart-define-from-file=config.json
```

Hubungkan HP lewat USB dengan USB debugging aktif, atau gunakan emulator Android. Dependency memakai batas versi; `flutter pub get` menghasilkan `pubspec.lock`. Setelah berhasil uji, simpan lock tersebut pada repositori proyek agar build berikutnya memakai dependency yang sama.

Di aplikasi pilih daftar akun baru, buat akun owner dengan nama/email sendiri. Karena semua akun baru berperan `pending`, langkah bootstrap owner pertama harus dijalankan sekali di SQL Editor:

```sql
update public.profiles p
set role = 'owner'
from auth.users u
where p.id = u.id
  and lower(u.email) = lower('GANTI_DENGAN_EMAIL_OWNER');
```

Ganti placeholder dengan email akunmu, pastikan hanya akun yang benar terpilih. Tekan **Periksa status** di aplikasi atau masuk kembali.

Pegawai berikutnya cukup mendaftar dari aplikasinya, kemudian owner memilih **Pegawai → Aktifkan sebagai pegawai**. Tidak perlu mengaktifkan pegawai lewat backend lagi.

## 4. Uji operasional sebelum menggunakan data sungguhan

- Buat order 2 Deep Clean + 1 ODS, tagihan harus Rp110.000 dan upah Rp40.000.
- Pilih pegawai berbeda per layanan dan cocokkan rincian upah.
- Tambahkan diskon Rp10.000; upah tetap Rp40.000.
- Tambahkan DP lalu pelunasan dari HP berbeda, gunakan muat ulang untuk melihat data terbaru.
- Edit status; upah tetap tercatat pada tanggal order masuk.
- Ubah tarif master, pastikan item lama mempertahankan tarif dan item baru memakai tarif baru.
- Coba edit order yang sama dari dua HP: versi lama harus ditolak, lalu buka ulang detail.
- Foto barang dari kamera dan galeri, tutup/buka aplikasi dan pastikan foto masih bisa dibaca akun aktif.
- Coba akun pending/nonaktif: akses server harus ditolak.
- Uji hapus order tanpa pembayaran; periksa rekap dan audit.
- Untuk salah input pembayaran, owner koreksi pembayaran dengan alasan sebelum koreksi/hapus order.
- Cek tampilan pada layar kecil, keyboard, login ulang, dan koneksi terputus.

Jangan membatalkan pembayaran untuk mencatat refund nyata. Fitur refund dan settlement gaji belum tersedia.

## 5. Build dan bagikan APK online

Backend menghubungkan semua HP; APK yang sama harus menggunakan proyek Supabase yang sama. Aplikasi memerlukan Internet untuk membaca/menyimpan transaksi. MVP memakai muat ulang/pull-to-refresh, **belum sinkronisasi realtime otomatis dan belum antrean offline**.

Untuk uji pribadi awal:

```powershell
flutter build apk --debug --dart-define-from-file=config.json
```

Hasil uji biasanya `build/app/outputs/flutter-apk/app-debug.apk`. Debug APK hanya untuk pengujian. Untuk distribusi operasional, ikuti [signing Android resmi](https://docs.flutter.dev/deployment/android) dan gunakan keystore release milikmu. Simpan keystore/password agar pembaruan aplikasi berikutnya tetap bisa dipasang.

Setelah signing disetel dan pemeriksaan lulus:

```powershell
flutter build apk --release --dart-define-from-file=config.json
```

Hasil biasanya `build/app/outputs/flutter-apk/app-release.apk`. Bagikan ke HP pegawai dan izinkan instalasi dari sumber tersebut. Distribusi langsung APK tidak memerlukan publikasi ke Play Store. Pegawai login masing-masing; datanya tersimpan bersama di Supabase.

## Batas gratis dan perawatan

Pada pemeriksaan 2 Oktober 2026, Supabase Free mencantumkan database 500 MB per proyek, file storage 1 GB, egress 5 GB ditambah cached egress 5 GB. Paket gratis memiliki batas dan proyek dapat dijeda setelah aktivitas rendah sekitar satu minggu. Ini bukan janji gratis tanpa batas selamanya.

Foto dibatasi 2 MB dan picker meminta ukuran maksimum 1400 px/quality 75; kompresi perangkat tidak menjamin setiap foto mencapai ukuran yang sama. Foto melebihi batas akan ditolak tanpa membatalkan order yang sudah tersimpan. HEIC/format selain JPG/PNG/WebP tidak diterima.

Misalnya asumsi rata-rata 200 KB/foto, 1 GB menampung sekitar 5.000 foto sebelum overhead dan file lain; itu hanya estimasi. Owner perlu memantau kuota, menyediakan backup database/foto, dan menentukan kebijakan retensi. Backup otomatis setara paket berbayar tidak diasumsikan tersedia pada Free.

Sumber utama: [Supabase pricing](https://supabase.com/pricing), [project pausing](https://supabase.com/docs/guides/platform/free-project-pausing), [Supabase Flutter](https://supabase.com/docs/reference/dart/initializing), [Cloud Storage Firebase](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).

## Batas MVP yang perlu diketahui

- Ongkos adalah **hak upah tercatat**, belum buku pembayaran gaji. Belum ada status upah sudah dibayar, gaji pokok, bonus, atau penguncian periode gaji. Koreksi order mengubah rekap pada periode tanggal order aslinya.
- Satu item diberikan kepada satu pegawai. Jika jumlah unit dibagi antara pegawai, masukkan baris layanan terpisah. Pembagian ongkos satu pekerjaan ke beberapa pegawai belum tersedia.
- Tidak ada refund sungguhan, pembayaran mundur tanggal, customer database tersendiri, export/nota PDF, printer Bluetooth, atau multi-outlet.
- Foto yang sudah terhubung belum bisa diganti/hapus lewat UI. Cleanup objek gagal unggah yang belum terhubung hanya diizinkan untuk pemiliknya.
- Audit disimpan dan hanya bisa dibaca owner melalui API/database; viewer audit di aplikasi belum dibuat.
- Tarif dan perubahan peran diatur owner; staff melihat semua order, foto, ongkos, dan rekap.
- Paginasi order 30/halaman; agregasi rekap berada di server sehingga tidak dibatasi 1.000 baris API. Daftar layanan/pegawai juga dipaginasi.
- Build debug dan pemeriksaan tampilan emulator sudah dilakukan; belum build release atau pengujian pada HP nyata. Mulai dari pilot internal, lalu perbaiki hasil uji sebelum operasional.
