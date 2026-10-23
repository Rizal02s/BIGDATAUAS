# Hasil verifikasi

**Absensi harian, 23 Oktober 2026:** masuk/pulang memakai jam server dan tanggal
WIB, catatan izin/sakit, kalender inklusif, rekap tim/per pegawai, paginasi,
koreksi owner dengan versi/alasan, dan riwayat sebelum/sesudah. Tidak menambah
tab bawah atau mengubah perhitungan ongkos. Seluruh 249 tes Flutter lulus,
termasuk 12 tes baru untuk absensi dan penyesuaian gulir menu Kelola pegawai.
Total 507 pemeriksaan lokal SQL/RLS/RPC dan handler server lulus; absensi
mencakup migrasi 014 berulang, peran/RLS, token akun dihapus, retry/klik ganda,
batas waktu server, shift lintas hari, batas 48 jam, konflik versi, audit,
riwayat akun nonaktif, serta rekap/paginasi 1.200 catatan. Preview
[owner](ui/attendance-owner-small.png), [pegawai](ui/attendance-self.png), dan
[koreksi](ui/attendance-correction.png) diperiksa pada 320 px dengan teks 150%.
Pengujian memakai PostgreSQL PGlite dan Auth/jaringan/repository tiruan;
migrasi online dan absensi dari dua HP nyata belum dijalankan oleh Codex.
Aktivasi: jalankan 014 setelah 013, lalu hot restart aplikasi.
Panduan: [absensi harian](ABSENSI.md).

**Hapus akun pegawai, 23 Oktober 2026:** owner dapat menghapus akun non-owner
dari Internal > Kelola pegawai, dengan alasan dan konfirmasi nama pegawai.
Akses aplikasi dicabut saat permintaan disiapkan; fungsi server menghapus
identitas login melalui Supabase Auth dan mempertahankan UUID serta riwayat
nota, foto, pembayaran, dan ongkos. Penghapusan yang terputus dapat dilanjutkan.
Seluruh 237 tes Flutter lulus; lima tes dialog terkait diulang setelah
perapian tampilan dan tetap lulus. Analisis `lib test tool` tanpa temuan.
Total 440 pemeriksaan lokal SQL/RLS/RPC dan handler server lulus, mencakup
migrasi 013 berulang, proteksi owner/diri sendiri, pencabutan akses token lama,
privasi direktori, konflik peran, retry/idempotensi, kegagalan Auth/finalisasi,
dan pelestarian riwayat. Preview dialog dan status tertunda pada layar 320 px
dengan teks 150% diperiksa. Auth dan jaringan memakai tiruan; runtime Deno,
deploy Edge Function, migrasi online, serta penghapusan akun nyata belum diuji.
Aktivasi membutuhkan migrasi 013 setelah 012 dan fungsi
`delete-employee-account`. Panduan: [hapus akun pegawai](HAPUS_AKUN_PEGAWAI.md).

**Portal admin operasional, 23 Oktober 2026:** navigasi admin diperluas menjadi
Beranda, Order, Layanan, dan Laporan. Layanan admin hanya harga pelanggan;
ongkos dan Internal tetap ditolak. Seluruh 229 tes Flutter lulus dan analisis
`lib test tool` tanpa temuan. Total 379 pemeriksaan PostgreSQL lokal +
RLS/RPC lulus, termasuk migrasi 012 berulang, pemisahan tanggal nota/pembayaran,
batas WIB, piutang terbaru, status campuran, nota dihapus/pembayaran dikoreksi,
paginasi dan lebih dari 1.000 transaksi, serta pembatasan perubahan tarif,
penghapusan, koreksi pembayaran, payroll, dan biaya Internal.
Tes Flutter mencakup empat tab, harga tanpa ongkos, perhitungan/model API,
rincian pembayaran ke nota asal, periode harian/bulanan/tahunan, retry,
paginasi, migrasi belum tersedia tanpa memblokir input, PDF rekap yang sudah
ada, dan layar 320 px dengan teks 150%. Preview Beranda, Layanan, Laporan,
dan penerimaan diperiksa. Pengujian memakai data tiruan/PostgreSQL lokal;
migrasi 012 belum dijalankan pada database usaha online. Jalankan setelah 011.
Panduan: [portal admin](PORTAL_ADMIN.md).

**Saran pelanggan lama, 23 Oktober 2026:** fitur pencarian ditambahkan pada
Nama pelanggan dan Nomor WhatsApp di Tambah order, maksimal lima pilihan.
Seluruh 219 tes Flutter lulus; analisis `lib test tool` tanpa temuan.
Pemeriksaan PostgreSQL lokal mencakup migrasi 011 berulang, pengelompokan
nomor Indonesia, nama lama/terbaru, pelanggan tanpa nomor, nama sama dengan
nomor berbeda, nota dihapus, prioritas hasil, privasi peran, dan lebih dari
1.000 kunjungan. Total 344 pemeriksaan PostgreSQL + RLS/RPC lulus.
Tes Flutter mencakup debounce/respons kedaluwarsa, pilihan nama/nomor,
pengisian dua kolom, edit manual, kegagalan migrasi/retry, input manual tanpa
menunggu saran, kunjungan hanya setelah simpan, peran aktif, dan layar kecil.
Preview [saran pelanggan](ui/customer-suggestions.png) diperiksa. Seluruh tes
memakai data tiruan dan PostgreSQL lokal; migrasi 011 belum diterapkan online.
Jalankan setelah 010. Panduan: [pelanggan lama](PELANGGAN_LAMA.md).

**Internal dan pengeluaran usaha, 23 Oktober 2026:** tab Pegawai menjadi
Internal, dengan menu Pengeluaran usaha dan Kelola pegawai; jumlah tab dan
akses owner tetap dipertahankan. Seluruh 207 tes Flutter lulus.
Analisis `lib test tool` tanpa temuan.
Total 317 pemeriksaan PostgreSQL lokal + RLS/RPC lulus, termasuk migrasi 010
berulang, validasi nominal/tanggal/sumber kas, idempotensi, koreksi/audit,
privasi admin/teknisi, fingerprint kas, dan lebih dari 1.000 pengeluaran.
Tes Flutter mencakup navigasi internal, kalender inklusif, pencatatan biaya,
metode/sumber tunai, respons terputus, klik ganda, koreksi, paginasi,
kegagalan migrasi/retry, serta layar kecil dengan teks diperbesar.
Preview menu, laporan, dan form biaya diperiksa. Pengujian memakai data
tiruan dan PostgreSQL lokal, bukan migrasi/transaksi pada database usaha.
Migrasi 010 belum dijalankan online; jalankan setelah 009.
Panduan: [Internal dan pengeluaran](INTERNAL_DAN_PENGELUARAN.md).

**Tanggal pada nota, 23 Oktober 2026:** 28 tes terkait model laporan, nota
gambar/PDF, unduhan, berbagi, dan estimasi lulus. Tanggal masuk sepatu dan
estimasi selesai ditambahkan di bawah NOTA ORDER, dengan keterangan eksplisit
untuk estimasi kosong. PNG dengan/tanpa estimasi dan nota panjang diperiksa;
PDF dirender dengan Poppler dan teksnya diperiksa untuk label, tanggal WIB,
serta urutan sebelum nama pelanggan. Pengujian tidak mengubah database usaha.

**Estimasi selesai, 23 Oktober 2026:** seluruh 193 tes Flutter lulus dan
analisis `lib test tool` tanpa temuan. Total 263 pemeriksaan PostgreSQL lokal
+ RLS/RPC lulus, termasuk migrasi 009 yang dapat dijalankan ulang, estimasi
opsional per nota, batas tanggal order dalam WIB, audit, konflik versi,
kompatibilitas penyimpanan lama, redaksi ongkos admin, dan antrean pekerjaan
lintas tanggal dengan paginasi. Tes widget mencakup kalender estimasi,
penghapusan estimasi, validasi perubahan tanggal masuk, filter, cakupan
teknisi/tim, kegagalan/retry, serta layar 320 px dengan teks 150%.
Preview [prioritas pengerjaan](ui/work-queue.png) dan
[form estimasi](ui/order-estimate.png) diperiksa. Pengujian memakai data tiruan
dan PostgreSQL lokal; migrasi 009 belum diterapkan pada database usaha online.
Jalankan setelah 008 sebelum menyimpan order dengan form terbaru.
Panduan: [estimasi selesai](ESTIMASI_SELESAI.md).

**Pembayaran ongkos, 23 Oktober 2026:** 54 tes Flutter terkait pembayaran
ongkos, repository, rincian per nota/PDF, Ringkasan, kas harian, dan akses peran
lulus. Analisis kode yang berubah tanpa temuan. Total 236 pemeriksaan
PostgreSQL lokal + RLS/RPC lulus, termasuk migrasi 008, alokasi FIFO per
pegawai/nota, pembayaran parsial lintas periode, idempotensi, koreksi,
perubahan/penugasan ulang nota, lebih dari 1.000 nota, dan penanda perubahan
kas untuk pembayaran ongkos Tunai tanpa membocorkan data ongkos ke admin.
Preview ringkasan, rincian, dan form pembayaran diperiksa. Tes memakai data
tiruan/PostgreSQL lokal, bukan pembayaran atau migrasi pada database usaha.
Migrasi 008 masih perlu dijalankan setelah 007 melalui SQL Editor Supabase.
Panduan: [pembayaran ongkos](PEMBAYARAN_ONGKOS.md).

**Kas harian dan tutup kas, 23 Oktober 2026:** 45 tes Flutter terkait kas,
repository, Ringkasan, kategori pembayaran, pelanggan, dan akses admin lulus.
Analisis kode yang berubah tanpa temuan. Total 189 pemeriksaan PostgreSQL
lokal + RLS/RPC lulus, termasuk migrasi 007, laporan pembayaran lintas tanggal,
batas WIB, lebih dari 1.000 pembayaran, penutupan berulang yang idempoten,
konflik data/perangkat, pembatasan owner/admin, dan pelestarian audit/riwayat.
Preview kas dan form penutupan diperiksa; layar 320 px dengan teks 150% diuji.
SQL diuji dengan PGlite lokal, bukan database usaha online. Migrasi 007 masih
perlu dijalankan melalui SQL Editor sebelum fitur digunakan pada Supabase.
Panduan: [kas harian](KAS_HARIAN.md).

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
