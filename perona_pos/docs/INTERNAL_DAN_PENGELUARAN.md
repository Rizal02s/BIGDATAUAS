# Internal perusahaan dan pengeluaran usaha

Tab bawah **Pegawai** berganti nama menjadi **Internal**, khusus owner. Jumlah
tab tetap lima. Menu Internal berisi:

- **Pengeluaran usaha:** biaya yang sudah dibayar, total per periode/kategori,
  dan riwayat koreksi.
- **Kelola pegawai:** aktivasi akun dan pengaturan peran yang sudah ada.

Admin dan teknisi tidak mendapat akses ke tab atau data pengeluaran internal.
Pembatasan berlaku pada aplikasi, fungsi server, dan RLS tabel. Aktivasi
pegawai tetap tersedia meskipun migrasi pengeluaran belum diterapkan.

## Mengaktifkan

Jalankan seluruh `supabase/010_business_expenses.sql` di SQL Editor Supabase
setelah migrasi 009. Lakukan hot restart aplikasi. Migrasi menambah tabel dan
fungsi pengeluaran tanpa menghapus order, pegawai, ongkos, atau pembayaran.
Terapkan berurutan; jangan menjalankan ulang migrasi lama setelah migrasi ini.

## Mencatat biaya

1. Buka **Internal > Pengeluaran usaha > Catat pengeluaran**.
2. Pilih tanggal saat biaya benar-benar dibayar (WIB), termasuk tanggal lama.
   Tanggal masa depan tidak diterima.
3. Isi keterangan, misalnya Beli cairan pembersih atau Bayar sewa Oktober.
4. Pilih kategori: Bahan & peralatan, Listrik & air, Sewa, Transportasi,
   Perawatan, atau Lainnya.
5. Isi nominal lebih dari nol, maksimal Rp1 triliun per catatan.
6. Pilih Tunai, Transfer, atau QRIS.
7. Untuk Tunai, tentukan apakah uang **Diambil dari kas toko**. Matikan jika
   memakai uang pribadi atau sumber tunai lain di luar laci toko.
8. Tambahkan catatan opsional, lalu simpan.

Jika tanggal yang disimpan di luar periode yang sedang dilihat, aplikasi
membuka bulan pengeluaran tersebut agar catatannya langsung terlihat.
Jika respons terputus, gunakan **Coba simpan lagi** pada form yang sama.
ID dan isi percobaan pertama dipertahankan agar biaya tidak dicatat dua kali.
Periksa riwayat sebelum membuat catatan baru jika sudah menutup form.

## Membaca laporan

Laporan awal menampilkan bulan berjalan. Ketuk kalender untuk memilih tanggal
mulai dan akhir; kedua tanggal ikut dihitung. Total pengeluaran dan rincian
kategori mencakup seluruh catatan aktif pada periode tersebut, bukan hanya
30 catatan yang sedang tampil. Gunakan Muat lebih banyak untuk riwayat berikutnya.
Setiap baris menampilkan tanggal, kategori, nominal, metode/sumber tunai,
operator, serta catatan. Tarik untuk memuat ulang atau gunakan ikon refresh.

## Koreksi salah catat

Ketuk **Koreksi salah catat**, isi alasan minimal 5 dan maksimal 500 karakter,
lalu konfirmasi. Catatan dikeluarkan dari total, tetapi masih muncul sebagai
Dikoreksi bersama alasan dan operator. Buat catatan baru dengan data yang benar
jika dibutuhkan. Riwayat tidak dihapus dan perubahan mempunyai jejak audit.
Koreksi ini untuk kesalahan pencatatan, bukan transaksi pengembalian uang.

## Hubungan dengan kas, ongkos, dan rekap

- Biaya Tunai dari kas toko dimasukkan **satu kali** dalam total **Tunai keluar /
  disetor** saat tutup kas. Isian ini tetap manual karena juga mencakup setoran
  dan pengeluaran tunai lainnya.
- Catatan/koreksi biaya dari laci mengubah fingerprint kas pada tanggal tersebut.
  Setelah memuat ulang, tutup kas lama dapat bertanda **Perlu periksa ulang**.
  Nominal penerimaan pelanggan dan penutupan yang sudah disimpan tidak diubah.
- Transfer, QRIS, dan tunai di luar kas toko masuk total pengeluaran usaha,
  tetapi tidak mengubah pencocokan laci kas.
- Ongkos pegawai dicatat melalui tab **Ongkos > Pembayaran ongkos**. Jangan
  mencatat pembayaran ongkos yang sama sebagai pengeluaran usaha lagi.
- Setoran kas ke bank atau pengambilan pemilik bukan biaya operasional pada
  menu ini; tetap masuk tunai keluar/disetor di Kas harian bila keluar dari laci.
- Total biaya ditampilkan pada laporan pengeluaran. Angka omzet dan kontribusi
  setelah ongkos pada rekap lama tetap memakai perhitungan yang sudah ada;
  belum digabung menjadi laporan laba bersih.
- Pengeluaran ini tidak memasukkan utang biaya yang belum dibayar, pengingat
  berulang, foto bukti biaya, atau ekspor laporan biaya.
