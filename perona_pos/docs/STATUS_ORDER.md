# Status cepat pada kartu order

Ketuk **Pengerjaan** pada kartu order (daftar order maupun halaman per tanggal).
Pilih Masuk, Dikerjakan, Selesai, atau Diambil, lalu tekan **Simpan status**.
Pilihan di atas mengubah semua layanan yang ditampilkan; dropdown per layanan
bisa dipakai untuk status yang berbeda. Pada tampilan pekerjaan saya, hanya
layanan milik teknisi tersebut yang ditampilkan dan dikirim untuk diperbarui.

Ketuk **Pembayaran** untuk mencatat uang yang diterima kemudian. Nominal awal
terisi sisa tagihan; ganti jika pelanggan membayar sebagian, pilih metode,
lalu simpan. Kartu otomatis menampilkan Belum bayar, DP, atau Lunas berdasarkan
jumlah pembayaran aktif. Order lunas menampilkan riwayat pembayaran.

## Penerapan SQL

Pada proyek Supabase yang sudah memakai migrasi 001–005, jalankan
[`006_quick_order_status.sql`](../supabase/006_quick_order_status.sql) melalui
SQL Editor. Migrasi aman dijalankan ulang dan tidak mengubah order yang sudah ada.
Pembaruan aplikasi saja belum mengaktifkan RPC status cepat di server.

Fungsi `update_order_statuses` hanya mengubah `orders.items[*].status`, menaikkan
`orders.version`, dan mencatat `orders.updated_at`. Harga, ongkos, jumlah,
penanggung jawab, diskon, serta tanggal masuk tetap tersimpan. Perubahan
tercatat pada `audit_log` dengan aksi `order.status`, pelaku, dan data sebelum
serta sesudahnya. Versi lama dari perangkat lain ditolak; gunakan **Muat ulang**
pada dialog untuk mengambil kondisi terbaru.

Pembayaran susulan memakai RPC `add_payment` yang sudah ada. Setiap penerimaan
uang menjadi baris baru di `payments` dengan `order_id`, `amount`, `method`,
`paid_at`, `recorded_at`, dan `created_by`, serta audit `payment.create`.
Waktu pembayaran mengikuti waktu server saat uang dicatat, bukan tanggal masuk
order lama; aplikasi menampilkannya dalam WIB. Riwayat pembayaran sebelumnya
tetap ada. Status lunas dihitung dari total pembayaran aktif, bukan flag manual.

Dalam satu dialog, percobaan ulang memakai ID, nominal, dan metode yang sama
untuk mencegah pencatatan ganda ketika respons jaringan terputus. SQL menolak
nominal yang melebihi sisa tagihan dan menyimpan pembayaran serta audit dalam
satu transaksi. Akun aktif owner, admin, dan teknisi dapat memakai fitur ini;
akun pending/nonaktif dan anonim tidak memiliki akses.

Verifikasi lokal: `flutter test --no-pub` dan `node scripts/integration.mjs`.
Pengujian SQL memakai PostgreSQL WASM lokal dengan stub Auth/Storage, bukan
database Supabase produksi.
