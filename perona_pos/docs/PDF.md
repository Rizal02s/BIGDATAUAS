# Nota dan rekap PDF

Versi `0.1.3+4`, 4 Oktober 2026.

## Nota untuk pelanggan

Pada akhir form order, pilih **Simpan order** untuk menyimpan saja atau
**Simpan & buat nota PDF** untuk menyimpan lalu membuka nota. Nota juga dapat
dibuka lagi melalui **Nota PDF pelanggan** di detail order.

Nota memuat logo Perona, nomor/tanggal order, customer, nomor WhatsApp,
layanan, jumlah, harga, diskon, tagihan, pembayaran, sisa tagihan, dan status
lunas. Nota tidak memuat ongkos, nama teknisi, ataupun catatan internal.
Form input/edit dan pemilih layanan sekarang hanya menampilkan harga pelanggan,
termasuk ketika owner atau teknisi yang menginput. Ongkos tetap dihitung server
dari tarif layanan dan penanggung jawab.

Pada halaman PDF:

- **Unduh PDF**: pilih lokasi penyimpanan Android, misalnya Downloads, lalu
  tekan Save/Simpan. Pembatalan pemilih lokasi tidak menghapus order.
- **Bagikan PDF**: pilih WhatsApp, pilih customer, lalu kirim dokumennya.
- **Cetak**: buka dialog pencetakan Android. Untuk printer fisik, gunakan
  layanan/printer yang didukung sistem Android.

Order, pembayaran awal, dan foto diselesaikan sebelum nota dibuat. Jika koneksi
untuk mengambil nota terputus, tombol **Coba buat PDF lagi** hanya mengulang
pembuatan PDF. Order dan pembayaran tidak dibuat ulang. Saat nota dibuka lagi,
nilai pembayaran diambil dari keadaan order terbaru.

## Rincian ongkos pegawai

Buka **Ongkos**, pilih periode, lalu ketuk nama pegawai. Halaman rincian
menampilkan total hak upah, jumlah order, jumlah unit/pasang, dan unit yang
berstatus Selesai/Diambil.

Tabel memiliki lima kolom: **Tanggal**, **Nama customer**, **Service layanan**,
**Jumlah**, dan **Total ongkos**. Status layanan tampil pada kolom layanan.
Geser ke samping untuk melihat seluruh kolom; ketuk baris untuk membuka order.
**Unduh rincian PDF** menyediakan dokumen A4 untuk pegawai tersebut.

Hanya layanan yang ditugaskan kepada pegawai itu yang dihitung. Tarif ongkos
snapshot dikalikan jumlah unit. Pengakuan upah tetap mengikuti tanggal order
masuk; pekerjaan yang belum selesai ikut tercatat. Nilai ini bukan bukti
pembayaran gaji.

## Rekap bulanan

Buka **Order → Bulanan**, pilih tanggal di bulan yang diinginkan, misalnya
Oktober 2026, lalu tekan **Unduh rekap PDF**. Periode Harian/Tahunan juga
mendukung PDF. Aplikasi mengambil seluruh halaman order dalam periode WIB
terpilih, bukan hanya order yang sedang tampak di layar.

Rekap owner/teknisi memiliki lima kolom: Tanggal, Nama customer, Service
layanan, Ongkos kerja, serta Tagihan/sisa. Satu baris mewakili satu layanan;
tagihan order ditulis sekali pada baris layanan pertama agar tidak terhitung
berulang. Ringkasan akhir memuat jumlah order/unit, nilai order, diskon,
pembayaran, piutang, jumlah order/customer belum lunas, total hak upah,
dan nilai order setelah ongkos.

Pembayaran mencakup pembayaran aktif untuk order dalam laporan, termasuk yang
diterima di luar bulan masuknya order. Angka ini berbeda dari **Pembayaran
masuk** di Ringkasan, yang mengikuti tanggal pembayaran. Order dihapus dan
pembayaran dikoreksi tidak dihitung. Customer belum lunas dihitung menurut
nomor WhatsApp; nomor kosong menggunakan nama. Nama sama tanpa nomor dapat
terhitung sebagai satu customer.

Filter **Pekerjaan saya** pada teknisi menghasilkan laporan order yang memuat
pekerjaannya; tagihan/pembayaran dan ongkos di rekap order tersebut mencakup
seluruh layanan order. Untuk ongkos teknisi itu saja, gunakan rincian pegawai
di halaman Ongkos.

Admin bisa mengunduh rekap pelanggan tanpa kolom maupun ringkasan ongkos/gaji.
Halaman/rincian ongkos tetap hanya untuk owner dan teknisi. Pembatasan API
menggunakan migrasi 003 yang sudah tersedia; tidak ada SQL baru untuk fitur PDF.
Jika 003 belum diterapkan, ikuti [AKSES.md](AKSES.md).

## Verifikasi

Seluruh 58 tes Flutter lulus; analisis `lib`, `test`, dan `tool` tanpa temuan.
APK release `0.1.3+4` sudah dipasang kembali sebagai update pada emulator,
dan sesi akun owner tetap masuk.

Generator PDF diuji untuk dokumen beberapa halaman, nama panjang, 55 layanan
dalam satu order, dan periode kosong. Tata letak contoh nota dan laporan
dirender lalu diperiksa. Ekstraksi teks memastikan nota serta PDF admin tidak
memuat ongkos/upah/gaji, dan seluruh 45 order beserta total laporan ikut masuk.

Unduhan nyata pada emulator Pixel 6 menyimpan PDF valid di Downloads. Pratinjau
PDF, pilihan WhatsApp pada dialog bagikan, dan dialog cetak Android berhasil
dibuka menggunakan data contoh tanpa koneksi Supabase. Dokumen tidak dikirim
ke kontak mana pun. Printer fisik dan pengiriman ke customer di HP nyata belum
diuji.

Target `tool/pdf_smoke.dart` hanya untuk uji Android dengan data contoh. APK
yang dibagikan adalah `build/app/outputs/flutter-apk/app-release.apk`, dibangun
dari `lib/main.dart` dan konfigurasi Supabase proyek.
