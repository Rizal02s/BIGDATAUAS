# Kas harian dan tutup kas

## Aktivasi

Pada proyek yang sudah memakai migrasi 001–006, jalankan seluruh isi
[`007_daily_cash.sql`](../supabase/007_daily_cash.sql) melalui SQL Editor Supabase.
Migrasi menambah tabel/fungsi kas dan dapat dijalankan ulang tanpa menghapus
data. Jangan menjalankan ulang migrasi 001. Setelah itu gunakan aplikasi dengan
kode terbaru dan lakukan hot restart jika masih menjalankan Flutter dari IDE.

Owner membuka **Ringkasan → Kas harian**. Admin mendapat tombol
yang sama di **Beranda**. Teknisi tidak mendapat akses kas harian. Tidak ada tab
bawah tambahan.

## Penerimaan harian

Kalender memilih satu tanggal, dari tahun 2020 sampai hari ini. Perhitungan
mengikuti tanggal `payments.paid_at` dalam WIB, dengan awal hari termasuk dan
awal hari berikutnya tidak termasuk. Tanggal masuk nota tidak membatasi
penerimaan: pelunasan nota September yang diterima Oktober masuk ke kas
Oktober pada tanggal penerimaannya. Pembayaran awal dengan tanggal manual
tetap mengikuti tanggal pembayaran manual yang sudah tersimpan.

Total mencakup Tunai, QRIS, dan Transfer. Pembayaran dibatalkan serta nota
dihapus tidak masuk laporan aktif. Daftar pembayaran berisi customer, nomor
nota, nominal, metode, waktu diterima, dan tanggal masuk nota. Ketuk untuk
membuka nota; filter metode dan tombol **Tampilkan lagi** tersedia. Total
memakai semua pembayaran, bukan hanya baris yang sedang terlihat.

Halaman ini terpisah dari empat kartu Ringkasan yang mengikuti bulan masuk
nota. Mengubah tanggal kas tidak mengubah periode order, ongkos, atau Top 5.

## Tutup kas

Isi:

1. **Saldo awal tunai**: uang di laci sebelum penerimaan tanggal itu. Diisi
   manual, tidak otomatis mengambil saldo penutupan hari sebelumnya.
2. **Tunai keluar / disetor**: total uang yang dikeluarkan dari laci, misalnya
   disetor ke owner/bank. Ini catatan total pencocokan, belum buku pengeluaran
   per transaksi.
3. **Uang tunai yang dihitung**: hasil hitung uang fisik di laci.
4. **Catatan**: wajib minimal 5 karakter jika ada selisih atau memperbarui
   tutup kas sebelumnya.

**Tunai seharusnya = saldo awal + penerimaan Tunai − tunai keluar.**
QRIS/Transfer tercatat dalam penerimaan, tetapi tidak ditambahkan ke uang laci.
Selisih = tunai dihitung − tunai seharusnya; ditampilkan sebagai Sesuai,
Kurang, atau Lebih. Tunai keluar tidak boleh melebihi kas yang tersedia.

Owner/admin bisa melakukan penutupan pertama. Hanya owner dapat memperbarui
catatan yang sudah disimpan. Setiap pembaruan menjadi catatan baru yang
menautkan catatan sebelumnya; riwayat dan audit tetap ada. Catatan tersimpan
memuat tanggal, operator, waktu simpan, saldo awal, tunai keluar, penerimaan
per metode, jumlah pembayaran, uang dihitung, dan selisih.

## Perubahan setelah tutup kas

Setelah migrasi 010, pengeluaran usaha yang ditandai **Diambil dari kas toko**
juga menandai perubahan pencocokan kas. Jumlahnya dimasukkan sekali dalam
total tunai keluar/disetor; tidak diisi otomatis. Pengeluaran dari luar kas
toko, Transfer, dan QRIS tidak mengubah laci kas. Rincian biaya internal tetap
khusus owner; admin hanya melihat penanda perubahan laporan kas.

Setelah migrasi 008, pembayaran/koreksi ongkos pegawai dengan metode Tunai
juga menandai kas untuk diperiksa ulang. Masukkan nominalnya dalam total tunai
keluar; isian itu tetap manual agar tidak dihitung dua kali. Detail ongkos
tetap tidak ditampilkan ke admin melalui laporan kas.

Tutup kas menyimpan hasil pencocokan pada waktu tersebut; tidak mengunci nota
atau melarang pembayaran berikutnya. Setelah pembayaran/nota berubah, muat
ulang laporan. Tanda **Perlu periksa ulang** menunjukkan data terbaru berbeda
dari catatan penutupan. Owner dapat menghitung ulang dan memperbarui tutup kas
dengan catatan. Angka penutupan sebelumnya tidak diubah diam-diam.

Server menghitung nominal penerimaan sendiri dan memeriksa fingerprint data.
Jika data berubah sejak laporan dimuat atau HP lain sudah menutup kas,
penyimpanan ditolak dan laporan perlu dimuat ulang. Setiap percobaan simpan
menggunakan ID yang sama ketika diulang setelah kehilangan respons, sehingga
tidak menggandakan catatan. Selama hasil simpan belum pasti, isi yang dikirim
tetap dipertahankan. **Muat ulang laporan** mengambil kondisi server terbaru.

## Pemeriksaan

Tes Flutter mencakup nominal, tanggal, RPC, akses peran, validasi, selisih,
penutupan ulang, perubahan pembayaran, retry, klik ganda, lebih dari 30 baris,
dan layar kecil dengan teks diperbesar. `scripts/integration.mjs` menjalankan
SQL/RLS/RPC pada PostgreSQL lokal (PGlite), termasuk lebih dari 1.000 penerimaan,
batas WIB, pembayaran batal, nota dihapus, konflik, audit, dan migrasi berulang.
Tes lokal tidak menerapkan migrasi pada database online.
