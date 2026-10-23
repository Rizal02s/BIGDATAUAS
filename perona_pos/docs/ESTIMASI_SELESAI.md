# Estimasi selesai dan prioritas pengerjaan

Jalankan seluruh `supabase/009_order_deadlines.sql` di SQL Editor Supabase
setelah migrasi 008, lalu lakukan hot restart aplikasi. Form order terbaru
memakai fungsi penyimpanan baru, sehingga migrasi diperlukan sebelum menyimpan
order dari versi ini. Data lama tidak dihapus dan estimasinya tetap kosong.

## Mengisi estimasi

1. Buka Tambah order atau Edit order.
2. Pada Data pelanggan, ketuk **Pilih estimasi selesai** lalu pilih tanggal.
3. Periksa layanan dan simpan order seperti biasa.

Estimasi bersifat opsional dan berlaku untuk seluruh nota. Tanggalnya paling
awal sama dengan tanggal order, sampai 31 Desember 2100. Jika tanggal order
dipindah melewati estimasi, pilih estimasi baru atau ketuk **Hapus estimasi**
sebelum menyimpan. Pembatalan kalender mempertahankan pilihan sebelumnya.
Order lama bisa diberi estimasi melalui Edit order.

Batas selesai adalah akhir tanggal tersebut dalam WIB. Contoh: estimasi
25 Oktober masih berstatus **Hari ini** sepanjang 25 Oktober, lalu menjadi
**Terlambat** mulai 26 Oktober pukul 00.00 WIB jika masih ada layanan Masuk
atau Dikerjakan. Status Selesai dan Diambil tidak dianggap pekerjaan terlambat.
Belum diambil pelanggan berbeda dari belum selesai dikerjakan.

Estimasi terlihat pada kartu, detail order, serta nota pelanggan (gambar/PDF).
Nota mencantumkan Tanggal masuk sepatu dan Estimasi selesai di bawah judul
NOTA ORDER; estimasi kosong tertulis Belum ditentukan. Perubahan estimasi tidak
mengubah tanggal masuk, hak ongkos, tarif, pembayaran, atau periode laporan.
Perubahan disimpan bersama order dan auditnya, dengan pemeriksaan versi untuk
mencegah penimpaan perubahan dari perangkat lain.

## Membuka daftar prioritas

Ketuk **Prioritas pengerjaan** dari Ringkasan (owner/teknisi) atau Beranda
(admin). Tidak ada tab navigasi bawah tambahan.

- **Semua:** pekerjaan belum selesai dari seluruh tanggal order, termasuk
  order bulan atau tahun sebelumnya; estimasi paling awal tampil lebih dulu.
- **Terlambat:** estimasi sebelum hari ini.
- **Hari ini:** estimasi hari ini.
- **Mendatang:** estimasi setelah hari ini.
- **Tanpa estimasi:** pekerjaan belum selesai yang belum mempunyai target.

Order tanpa estimasi tampil di bagian bawah pada pilihan Semua. Urutan tanggal
yang sama memakai tanggal masuk paling awal. Daftar dimuat 30 nota per halaman;
ketuk Muat lebih banyak untuk melanjutkan. Daftar prioritas tidak mengikuti
kalender/periode rekap dan tidak mengubah filter pada tab Order.

Teknisi awalnya melihat **Pekerjaan saya**. Matikan pilihan ini untuk melihat
tim sesuai akses operasional yang sudah ada. Filter pribadi memeriksa layanan
milik teknisi tersebut: jika bagiannya selesai dan bagian pegawai lain belum,
nota hanya muncul pada daftar pegawai yang belum selesai atau daftar tim.
Owner/admin langsung melihat tim; admin tetap tidak menerima data ongkos.

Ketuk nama pelanggan untuk membuka detail, atau label Pengerjaan/Pembayaran
untuk memperbarui langsung. Setelah semua layanan terkait menjadi Selesai
atau Diambil, nota keluar dari daftar prioritas saat dimuat ulang. Koreksi status
kembali menjadi Masuk/Dikerjakan membuatnya muncul lagi sesuai estimasi.

Tarik untuk memuat ulang atau gunakan ikon refresh, termasuk setelah lewat
tengah malam atau perubahan dari HP lain. Ini penanda dalam aplikasi;
notifikasi otomatis ke HP/WhatsApp belum ditambahkan.
