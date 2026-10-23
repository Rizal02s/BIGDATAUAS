# Perona Kasir — Flutter + Supabase

Kartu order kini mendukung perubahan pengerjaan dan pembayaran susulan langsung
melalui label status. Terapkan migrasi `006_quick_order_status.sql` untuk
mengaktifkan status cepat. Panduan dan rincian penyimpanan SQL ada di
[status order](docs/STATUS_ORDER.md).

MVP kasir jasa Perona Sepatu untuk Android. Dibuat dari nol berdasarkan dua gambar yang diberikan pada 2 Oktober 2026.

**Versi terbaru:** `0.1.5+6` menyediakan nota pelanggan berupa gambar PNG,
unduhan ke penyimpanan, dan berbagi ke WhatsApp/WhatsApp Business dengan nomor
tujuan dari order. Panduan penggunaan dan batas pemilihan penerima ada di
[nota gambar](docs/NOTA.md). Tidak ada migrasi database baru untuk fitur ini.

Versi `0.1.4+5` menambahkan tanggal dan jam order manual dalam WIB,
termasuk untuk mencatat order lama. Rekap, ongkos, dan nota mengikuti tanggal
order; pembayaran awal Tunai/QRIS mengikuti tanggal yang sama. Panduan ada di
[tanggal order](docs/TANGGAL_ORDER.md). Migrasi backend 004 diperlukan.

Versi `0.1.3+4` menambahkan nota pelanggan, rincian ongkos per pegawai,
dan rekap periode yang dapat diunduh/dibagikan sebagai PDF. Form order hanya
menampilkan harga pelanggan. Cara penggunaan ada di [panduan PDF](docs/PDF.md).
Pembatasan admin menggunakan migrasi 003; jika belum diterapkan ke Supabase,
ikuti [panduan akses](docs/AKSES.md). Release memakai signing proyek yang sama
dengan APK sebelumnya; signing permanen serta uji tiga akun/perangkat nyata
belum dilakukan.

## Keputusan yang sudah dipilih

- Aplikasi pertama: **Flutter Android**.
- Acuan harga: **tabel harga customer dan ongkos kerja pegawai**.
- Hak ongkos dihitung **saat order masuk**, mengikuti penanggung jawab setiap item layanan.
- Upah dihitung per unit/pasang × tarif ongkos; bukan persentase harga jual.
- Diskon customer tidak mengurangi ongkos kerja pegawai.
- Periode harian/bulanan/tahunan memakai **Asia/Jakarta/WIB**, meskipun zona waktu HP berbeda.

## Fitur yang ada dalam kode

**Absensi harian:** masuk/pulang memakai jam server WIB, catatan izin/sakit,
rekap tanggal inklusif, serta koreksi owner dengan riwayat perubahan. Owner
membuka Internal > Absensi pegawai; admin/teknisi memakai ikon Absensi saya
di bagian atas halaman utama. Terapkan
[`014_daily_attendance.sql`](supabase/014_daily_attendance.sql) setelah 013.
Panduan: [absensi harian](docs/ABSENSI.md).

**Hapus akun pegawai:** owner menghapus akun melalui Internal > Kelola pegawai
dengan alasan dan konfirmasi. Akun owner dilindungi; riwayat order, foto,
pembayaran, dan ongkos tetap tersimpan. Terapkan
[`013_delete_employee_account.sql`](supabase/013_delete_employee_account.sql)
setelah 012 **dan deploy fungsi server delete-employee-account** sebelum dipakai.
Panduan: [hapus akun pegawai](docs/HAPUS_AKUN_PEGAWAI.md).

**Portal admin operasional:** navigasi Beranda, Order, Layanan, dan Laporan.
Admin melihat harga pelanggan, nota masuk, penerimaan per metode, piutang,
status pengerjaan, dan kas harian; tanpa Ongkos/Internal. Perubahan tarif,
penghapusan order, dan koreksi pembayaran tetap khusus owner. Terapkan
[`012_admin_operational_report.sql`](supabase/012_admin_operational_report.sql)
setelah 011. Panduan: [portal admin](docs/PORTAL_ADMIN.md).

**Pelanggan lama pada form order:** ketik minimal dua karakter nama atau WA
untuk menampilkan maksimal lima pelanggan dari seluruh riwayat nota aktif.
Pilih untuk mengisi nama dan WA bersama; format nomor Indonesia dicocokkan
sebagai identitas yang sama. Input pelanggan baru tetap tersedia. Terapkan
[`011_customer_suggestions.sql`](supabase/011_customer_suggestions.sql)
setelah 010. Panduan: [memilih pelanggan lama](docs/PELANGGAN_LAMA.md).

**Internal perusahaan** menggantikan tab Pegawai tanpa menambah tab bawah.
Owner membuka **Pengeluaran usaha** untuk mencatat biaya yang sudah dibayar,
melihat total per periode/kategori, dan menelusuri koreksi. **Kelola pegawai**
tetap tersedia di dalam Internal. Terapkan
[`010_business_expenses.sql`](supabase/010_business_expenses.sql) setelah 009.
Panduan: [Internal dan pengeluaran](docs/INTERNAL_DAN_PENGELUARAN.md).

**Estimasi selesai dan prioritas pengerjaan:** pilih tanggal estimasi opsional
per nota pada form order. Ringkasan/Beranda menyediakan daftar pekerjaan belum
selesai dari semua tanggal, dengan filter terlambat, hari ini, mendatang, dan
tanpa estimasi. Batas tanggal memakai WIB; pekerjaan Selesai/Diambil tidak
ditandai terlambat. Terapkan [`009_order_deadlines.sql`](supabase/009_order_deadlines.sql)
setelah 008 sebelum menyimpan order dengan form terbaru.
Panduan: [estimasi selesai](docs/ESTIMASI_SELESAI.md).

**Pembayaran ongkos pegawai** tersedia melalui Ongkos → Pembayaran ongkos.
Owner mencatat pembayaran sebagian/lunas, metode, waktu bayar, serta koreksi
dengan alasan. Teknisi dapat melihat riwayat. Alokasi per pegawai/nota mencegah
pembayaran ulang saat berganti periode. Terapkan
[`008_wage_payments.sql`](supabase/008_wage_payments.sql) setelah 007.
Panduan: [pembayaran ongkos](docs/PEMBAYARAN_ONGKOS.md).

**Kas harian & tutup kas** tersedia untuk owner/admin melalui Ringkasan atau
Beranda. Laporan mengikuti tanggal pembayaran diterima dalam WIB, termasuk
pelunasan nota lama, dengan pemisahan Tunai/QRIS/Transfer dan pencocokan uang
fisik. Terapkan [`007_daily_cash.sql`](supabase/007_daily_cash.sql) setelah 006
sebelum menggunakan fitur ini. Panduan: [kas harian](docs/KAS_HARIAN.md).

Tab **Order** mendukung pencarian nama pelanggan, nomor WhatsApp, dan nomor
nota, serta kombinasi filter status pengerjaan/pembayaran. Pencarian mencakup
seluruh halaman data dalam periode terpilih dan juga tersedia pada rincian
per tanggal. Lihat [panduan pencarian order](docs/PENCARIAN_ORDER.md).
Tidak memerlukan migrasi Supabase baru.

**Home sesuai peran:** owner mendapat ringkasan usaha dan pengelolaan tim;
teknisi mendapat ringkasan usaha dan ongkos seluruh tim; admin hanya operasional
order tanpa akses ongkos. Ongkos dipindahkan ke halaman sendiri.
Navigasi owner: Ringkasan, Order, Layanan, Ongkos, Internal. Navigasi teknisi:
Ringkasan, Order, Layanan, Ongkos. Admin: Beranda, Order, Layanan, Laporan.
Panduan penerapan dan hak akses ada di [docs/AKSES.md](docs/AKSES.md).

| Halaman | Fungsi |
|---|---|
| Masuk/daftar | Akun email/password; akun baru menunggu aktivasi owner |
| Ringkasan | Owner/teknisi: empat kartu untuk order bulan berjalan: total order, customer belum lunas, pembayaran QRIS, pembayaran tunai; ketuk kategori pembayaran untuk tabel customer dan keterangan bayar |
| Ongkos | Owner/teknisi: ketuk total tim, ongkos pribadi, atau nama pegawai untuk rincian per nota: No, tanggal masuk, nama customer, jenis order, total ongkos per nota; unduh PDF per pegawai |
| Input order | Tanggal/jam order manual (WIB), pelanggan, nomor WA, catatan, layanan, jumlah, penanggung jawab, status, diskon, pembayaran awal Tunai/QRIS/Belum lunas, serta foto kamera/galeri |
| Detail order | Ringkasan lunas/piutang, layanan/pegawai, edit, pembayaran, foto, serta nota gambar tanpa ongkos; unduh PNG atau bagikan ke WhatsApp |
| PDF rekap | Seluruh order periode terpilih dan ringkasan tagihan/piutang; ongkos/gaji hanya untuk owner/teknisi |
| Layanan | 32 tarif awal; owner dapat tambah, edit, nonaktifkan layanan tanpa dashboard backend |
| Internal | Owner mencatat pengeluaran usaha dan mengelola akses pegawai |
| Penghapusan | Owner dapat menghapus satu order atau semua order per tanggal melalui konfirmasi Ya/Tidak; mendukung semua status pembayaran dan menyimpan jejak audit |

Ringkasan memakai seluruh nota yang masuk pada bulan berjalan dalam WIB.
Kartu belum lunas menghitung customer unik serta sisa tagihan. Kartu QRIS dan
tunai menampilkan total pembayaran aktif pada nota bulan tersebut, beserta
jumlah notanya. Nota dengan pembayaran campuran muncul pada kedua kategori,
sedangkan nominal pada masing-masing kartu hanya menjumlahkan metode terkait.
Ketuk kategori untuk tabel **No, Tanggal, Nama customer, Keterangan bayar**;
ketuk baris untuk membuka nota dan memperbarui pembayaran.

Pada tab **Order**, owner dapat menekan ikon hapus di sebelah tanggal dalam
tampilan Bulanan, atau membuka tanggal lalu memilih **Hapus semua order tanggal
ini**. Ikon tempat sampah pada kartu menghapus satu order. Dialog menampilkan
tanggal WIB, jumlah order, dan pilihan **Ya/Tidak** tanpa meminta alasan. Penghapusan per
tanggal mencakup seluruh halaman order pada hari itu.

Order dapat dihapus baik belum dibayar, dibayar sebagian, maupun sudah lunas.
Pencatatan pembayaran aktif otomatis dibatalkan saat penghapusan.
Order, ongkos, piutang, dan pembayaran keluar dari rekap; riwayat
order/pembayaran serta jejak audit tetap tersimpan. Jika koneksi terputus
atau versi order berubah di tengah proses, dialog menampilkan jumlah yang sudah
terkonfirmasi dihapus; tutup dialog untuk memuat data terbaru sebelum mencoba
lagi. Aplikasi juga mendukung backend lama: jika server meminta koreksi
pembayaran, aplikasi mengoreksinya lalu menghapus order secara otomatis.
**[Migrasi 005](supabase/005_simple_order_deletion.sql)** tetap disarankan agar
koreksi pembayaran dan penghapusan berjalan dalam satu transaksi. Tanpa migrasi
ini, permintaan berjalan berurutan; kegagalan koneksi atau perubahan oleh pengguna
lain dapat menghentikan proses setelah sebagian pembayaran dikoreksi. Muat ulang
dan ulangi penghapusan untuk melanjutkan. Migrasi hanya mengubah fungsi
penghapusan, tanpa menghapus data saat dijalankan.

**Owner dan teknisi dapat membaca ongkos seluruh tim. Admin tidak dapat membaca ongkos.** Pembatasan admin memerlukan migrasi `003_roles_and_wage_privacy.sql`; API menghapus tarif ongkos dari JSON order/layanan, dan rekap ongkos ditolak. Owner mengelola tarif, akun, penghapusan, dan koreksi pembayaran. Ketiga peran dapat input/edit order, foto, dan pembayaran. Rancangan ini untuk satu usaha/outlet dalam satu proyek Supabase.

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
- `supabase/003_roles_and_wage_privacy.sql`: migrasi peran admin/teknisi dan pembatasan data ongkos admin; aman untuk proyek yang sudah berjalan.
- `supabase/004_manual_order_dates.sql`: tanggal order/pembayaran awal manual dan waktu input asli; tetap mendukung APK lama.
- `supabase/005_simple_order_deletion.sql`: konfirmasi hapus sederhana dengan pembatalan pencatatan pembayaran otomatis dalam satu transaksi.
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
3. Jalankan `supabase/002_seed.sql` untuk mengisi price list, lalu `supabase/003_roles_and_wage_privacy.sql` untuk hak akses admin/teknisi, `supabase/004_manual_order_dates.sql` untuk tanggal manual, dan `supabase/005_simple_order_deletion.sql` untuk penghapusan sederhana. Untuk proyek yang sudah menjalankan 001–004, cukup jalankan 005.
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

Pegawai berikutnya cukup mendaftar dari aplikasinya, kemudian owner memilih **Internal → Kelola pegawai → Atur akses**. Tidak perlu mengaktifkan pegawai lewat backend lagi.

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
- Uji hapus order belum dibayar, dibayar sebagian, dan lunas dengan konfirmasi Ya/Tidak; periksa rekap dan audit.
- Koreksi pembayaran terpisah tetap memerlukan alasan; saat menghapus order, pencatatan pembayaran aktif dibatalkan otomatis.
- Cek tampilan pada layar kecil, keyboard, login ulang, dan koneksi terputus.

Jangan membatalkan pembayaran untuk mencatat refund nyata. Pembayaran ongkos
per nota tersedia melalui migrasi 008; fitur refund nyata belum tersedia.

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

- Ongkos adalah **hak upah tercatat**. Pembayaran sebagian/lunas dan riwayatnya
  tersedia melalui migrasi 008. Gaji pokok, bonus, dan penguncian periode belum
  tersedia. Koreksi order mengubah hak pada periode tanggal order aslinya;
  kelebihan yang sudah dibayar ditandai untuk diperiksa.
- Satu item diberikan kepada satu pegawai. Jika jumlah unit dibagi antara pegawai, masukkan baris layanan terpisah. Pembagian ongkos satu pekerjaan ke beberapa pegawai belum tersedia.
- Tidak ada refund sungguhan, pembayaran mundur tanggal, customer database tersendiri, export/nota PDF, printer Bluetooth, atau multi-outlet.
- Foto yang sudah terhubung belum bisa diganti/hapus lewat UI. Cleanup objek gagal unggah yang belum terhubung hanya diizinkan untuk pemiliknya.
- Audit disimpan dan hanya bisa dibaca owner melalui API/database; viewer audit di aplikasi belum dibuat.
- Tarif dan perubahan peran diatur owner; teknisi melihat semua order, foto, ongkos, dan rekap. Admin melihat order, harga pelanggan, dan laporan operasional; tanpa ongkos, kontribusi, atau data Internal.
- Paginasi order 30/halaman; agregasi rekap berada di server sehingga tidak dibatasi 1.000 baris API. Daftar layanan/pegawai juga dipaginasi.
- Build debug/release dan pemeriksaan tampilan emulator sudah dilakukan. Release masih memakai signing debug; signing permanen dan pengujian pada HP nyata belum dilakukan. Mulai dari pilot internal, lalu perbaiki hasil uji sebelum operasional.
