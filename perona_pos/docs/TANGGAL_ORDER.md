# Tanggal order manual — 0.1.4+5

Contoh: hari ini 6 Oktober 2026, tetapi customer datang tanggal 3 Oktober.

1. Buka **Order → Buat order baru**.
2. Di bagian data pelanggan, ketuk **Tanggal order** dan pilih **3 Oktober 2026**.
3. Jika perlu, ubah **Jam order**. Semua tanggal/jam memakai WIB.
4. Isi customer, layanan, penanggung jawab, dan pembayaran seperti biasa.
5. Pilih **Simpan order** atau **Simpan & buat nota PDF**.

Order masuk ke daftar tanggal 3 Oktober. Rekap harian tanggal 3, rekap Oktober,
rincian ongkos teknisi, dan nota PDF memakai tanggal yang dipilih. Jika halaman
rekap masih pada tanggal 6, pilih tanggal 3 atau periode Oktober untuk melihatnya.
Tanggal dapat dipilih dari 2020 sampai 2100. Default order baru adalah hari ini;
saat mengedit, tanggal/jam lama dipertahankan sampai pengguna mengubahnya.

Pembayaran awal **Tunai/QRIS** mengikuti tanggal order. Pilih **Belum lunas**
jika belum dibayar pada waktu order masuk, lalu tambahkan pembayaran dari detail
order saat customer membayar. Pembayaran susulan mengikuti waktu pembayaran
yang dicatat. Mengedit tanggal order tidak memindahkan pembayaran yang sudah
tersimpan. Layanan baru memakai tarif master saat input; mengedit order lama
tetap mempertahankan snapshot tarif item yang sudah tersimpan.

Tanggal bisnis disimpan sebagai `orders.created_at` agar query rekap dan PDF
tetap konsisten. `orders.recorded_at` menyimpan waktu input sebenarnya;
`payments.recorded_at` menyimpan waktu pencatatan pembayaran. Riwayat audit
tetap memakai waktu server. Retry pembayaran/foto mempertahankan tanggal dan ID
draft pertama supaya tidak membuat pencatatan ganda.

## Pembaruan Supabase

Proyek Perona yang dipakai aplikasi sudah diperbarui pada 6 Oktober 2026.
SQL Editor mengembalikan **Success. No rows returned**, kemudian pemeriksaan
fungsi dan kolom tanggal serta kelengkapan riwayat semuanya mengembalikan `true`.
Bukti ada di [hasil verifikasi](ui/manual-date-supabase.png).

Untuk memasang pada proyek lain yang sudah memakai migrasi 001–003:

1. Buka proyek di dashboard Supabase → **SQL Editor → New query**.
2. Salin seluruh isi `supabase/004_manual_order_dates.sql`.
3. Jalankan sekali dan pastikan berhasil. Migrasi juga aman dijalankan ulang.
4. Pasang APK `0.1.4+5` sebagai pembaruan aplikasi.

Migrasi menambahkan fungsi tanggal manual tanpa menghapus order, pembayaran,
foto, atau akun. APK sebelumnya tetap dapat input/edit memakai RPC lama;
edit dari APK lama mempertahankan tanggal order yang sudah dipilih.
