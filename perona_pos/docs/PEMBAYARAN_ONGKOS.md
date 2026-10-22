# Pembayaran ongkos pegawai

## Aktivasi

Jalankan seluruh [`008_wage_payments.sql`](../supabase/008_wage_payments.sql)
di SQL Editor pada proyek yang sudah memakai migrasi 001–007. Aman dijalankan
ulang tanpa menghapus transaksi. Gunakan kode terbaru dan hot restart dari IDE.

Buka **Ongkos → Pembayaran ongkos**. Periode awal mengikuti halaman Ongkos,
dan dapat diganti melalui kalender rentang tanggal. Ketuk pegawai untuk
melihat hak ongkos, sudah dibayar, sisa, riwayat, dan saldo per nota. Rincian
ongkos seorang pegawai juga memiliki tombol Pembayaran ongkos.

Owner mencatat dan mengoreksi pembayaran. Teknisi dapat melihat riwayat sesuai
aturan lama yang mengizinkan membaca ongkos seluruh tim. Admin, pending,
nonaktif, dan anonim tidak mendapat akses; server/RLS juga membatasinya.

## Pembayaran dan periode

Hak ongkos tetap dihitung dari snapshot tarif ongkos × jumlah layanan pada
tanggal masuk nota dalam WIB, termasuk layanan yang belum selesai. Pembayaran
pelanggan tidak menentukan hak ongkos pegawai.

Owner mengisi jumlah yang dibayarkan, metode Tunai/Transfer/QRIS, catatan
opsional, dan waktu bayar. Default memakai waktu server saat disimpan.
Pembayaran lama dapat memakai kalender dan pemilih jam WIB. Tanggal masa depan
ditolak. Pembayaran sebelum fitur ini digunakan perlu dicatat; aplikasi tidak
otomatis menganggap upah lama sudah dibayar.

Pembayaran boleh sebagian sampai sebesar sisa pada periode terpilih. Server
mengalokasikannya ke nota paling lama yang masih memiliki sisa. Contoh: hak
nota A Rp20.000 dan B Rp30.000, pembayaran Rp25.000 melunasi A dan membayar
Rp5.000 untuk B. Sisa B Rp25.000 tetap sama saat melihat hari, bulan, atau
tahun yang memuat nota tersebut. Alokasi mengikuti **pegawai + nota**.

Periode laporan mengikuti tanggal masuk nota. Riwayat menampilkan tanggal bayar
sebenarnya meskipun terjadi bulan berikutnya. Jika pembayaran mencakup nota
beberapa periode, riwayat membedakan alokasi periode terpilih dari total
pembayaran seluruhnya.

## Koreksi dan perubahan nota

**Koreksi salah catat** membutuhkan alasan minimal 5 karakter dan hanya dapat
dilakukan owner. Koreksi membatalkan seluruh alokasi pembayaran tersebut,
termasuk nota periode lain. Catatan asli tetap ada, ditandai Dikoreksi, dan
tidak lagi mengurangi sisa. Ini koreksi pencatatan, bukan refund uang nyata.

Jika nota dihapus, jumlah/tarif ongkos berkurang, atau pegawai ditugaskan ulang
setelah dibayar, riwayat tetap tersimpan. Kelebihan pembayaran ditampilkan
terpisah dan tidak otomatis melunasi nota lain. Owner memeriksa perubahan dan
mengoreksi pencatatan bila memang keliru.

## Kas harian dan PDF

Pembayaran ongkos tidak mengubah tagihan atau pembayaran pelanggan. Untuk
ongkos dibayar Tunai, masukkan nominalnya dalam total **Tunai keluar /
disetor** saat pencocokan kas. Isian itu tetap manual agar tidak dihitung ganda.
Penambahan/koreksi pembayaran ongkos Tunai mengubah fingerprint kas pada tanggal
bayar; hasil tutup kas sebelumnya ditandai Perlu periksa ulang setelah dimuat
ulang. Admin tidak menerima detail atau nominal ongkos melalui laporan kas.

PDF rincian ongkos yang sudah ada tetap merupakan laporan hak ongkos layanan.
Saldo dan riwayat pembayaran tersedia pada halaman Pembayaran ongkos.

## Konsistensi

Server menghitung hak, sisa, dan alokasi. Pembayaran untuk pegawai yang sama
diserialkan walaupun periode tumpang tindih. Fingerprint menolak data yang
berubah sejak layar dimuat. Retry memakai ID dan isi yang sama agar kehilangan
respons tidak menambah pembayaran ganda atau menghidupkan catatan dikoreksi.

`wage_payouts`, `wage_allocations`, dan audit `wage.pay`/`wage.void` menyimpan
penerima, operator, nominal, metode, waktu bayar/input, catatan, dan hubungan
nota. Tabel tidak dapat ditulis/dihapus langsung melalui akun aplikasi.

Tes SQL/RLS pada `scripts/integration.mjs` memakai PostgreSQL lokal, termasuk
lebih dari 1.000 nota, alokasi lintas periode, pembayaran parsial, retry,
konflik, koreksi, nota dihapus/ditugaskan ulang, kas, dan hak akses. Tes Flutter
mencakup API, form, kalender/jam, riwayat, daftar lanjutan, dan layar kecil.
Pengujian lokal tidak menerapkan migrasi pada Supabase online.
