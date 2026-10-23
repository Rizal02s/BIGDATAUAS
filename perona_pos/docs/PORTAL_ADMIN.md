# Portal admin operasional

Admin memakai aplikasi dan data usaha yang sama dengan owner. Navigasi bawah
admin: **Beranda, Order, Layanan, Laporan**. Owner tetap memakai Ringkasan,
Order, Layanan, Ongkos, dan Internal. Peran teknisi yang sudah ada tidak diubah.

## Mengaktifkan

1. Jalankan seluruh `supabase/012_admin_operational_report.sql` di SQL Editor
   Supabase setelah migrasi 011, lalu lakukan hot restart aplikasi.
2. Jika akun admin belum ada, daftar akun baru melalui aplikasi dengan email
   berbeda, konfirmasi email jika diminta, lalu masuk.
3. Owner membuka **Internal > Kelola pegawai > Atur akses**, lalu memilih
   **Aktifkan sebagai admin** pada akun yang benar.
4. Akun baru menekan Periksa status, atau keluar lalu masuk kembali.

Laporan baru memakai fungsi server tersendiri. Jika migrasi 012 belum diterapkan,
area laporan memberi petunjuk pembaruan; input order dan daftar layanan tetap
dapat digunakan dengan migrasi sebelumnya yang sudah tersedia.

## Isi portal

- **Beranda:** periode harian/bulanan/tahunan, jumlah nota masuk, pekerjaan belum
  selesai/terlambat, penerimaan pelanggan, input order, kas harian, prioritas
  pengerjaan, dan nota terbaru.
- **Order:** pencarian/filter, input/edit, saran pelanggan lama, estimasi selesai,
  perubahan status, DP/pelunasan, foto, nota gambar/WhatsApp, serta PDF rekap.
- **Layanan:** pencarian layanan aktif, kategori, dan harga pelanggan per unit.
  Admin tidak mendapat tombol tambah/edit atau tarif ongkos.
- **Laporan:** nilai nota sebelum diskon, diskon, omzet nota, sisa tagihan nota
  periode ini, piutang semua tanggal, penerimaan per metode, status pengerjaan,
  dan rincian pembayaran yang bisa membuka nota asal.

## Dasar perhitungan laporan

Periode memakai WIB, dengan awal termasuk dan akhir berupa awal hari berikutnya
yang tidak termasuk.

- Nota masuk, omzet, diskon, dan status pengerjaan mengikuti **tanggal masuk
  nota** pada periode terpilih. Status adalah kondisi terbaru saat laporan dimuat.
- Belum selesai berarti ada layanan Masuk/Dikerjakan. Siap diambil berarti
  seluruh layanan Selesai/Diambil dan masih ada yang Selesai. Sudah diambil
  berarti seluruh layanan Diambil.
- Pekerjaan terlambat berarti masih belum selesai dan estimasi sebelum hari
  ini. Pada laporan/beranda, jumlah ini hanya untuk nota masuk dalam periode
  terpilih. Menu Prioritas pengerjaan tetap mencakup seluruh tanggal.
- Penerimaan mengikuti **tanggal pembayaran**, sehingga pelunasan nota bulan
  sebelumnya dapat muncul pada penerimaan bulan ini. DP dan pelunasan adalah
  pembayaran terpisah. Penerimaan dipisahkan menjadi Tunai, QRIS, dan Transfer.
- Sisa tagihan memakai semua pembayaran aktif terbaru, termasuk pelunasan setelah
  periode terpilih. Ini bukan snapshot piutang pada akhir periode masa lalu.
  Piutang semua tanggal mencakup seluruh nota aktif, termasuk di luar periode.
- Pembayaran yang dikoreksi serta nota yang dihapus tidak masuk hitungan.
- Total dihitung oleh server atas seluruh data. Rincian penerimaan dimuat
  30 pembayaran per halaman; Muat pembayaran lainnya melanjutkan riwayat tanpa
  membatasi total pada halaman pertama atau batas 1.000 baris API.

Tombol **Lihat nota masuk periode ini** membuka tab Order untuk periode yang
sama dan mengosongkan pencarian/filter sebelumnya. **Unduh rekap PDF** memakai
rekap nota masuk yang sudah tersedia, tanpa data ongkos. PDF itu mengikuti
tanggal masuk nota dan pembayaran aktif pada nota tersebut; daftar penerimaan
di layar mengikuti tanggal pembayaran. Keduanya mempunyai dasar tanggal berbeda.

Kas harian tersedia dari Beranda dan Laporan. Admin dapat melakukan tutup kas
pertama; pembaruan tutup kas yang sudah tersimpan tetap hanya owner.

## Hak akses

Admin tidak mempunyai akses ke menu/data Ongkos, pembayaran ongkos, pengeluaran
Internal, pengaturan pegawai, audit, atau kontribusi setelah ongkos. Mengubah
tarif layanan, menghapus order, dan mengoreksi pembayaran tetap khusus owner.

Pembatasan berlaku di server: tabel order/layanan mentah yang mengandung ongkos
tidak dapat dibaca admin, hasil RPC operasional memakai daftar kolom eksplisit,
dan fungsi ongkos/internal menolak peran admin. Mengganti tampilan/menu pada HP
tidak memberikan hak akses tambahan.

Gunakan muat ulang untuk melihat perubahan dari HP lain. Laporan dan nilai
piutang tidak mengunci transaksi sehingga dapat berubah setelah pembayaran atau
koreksi yang sah.
