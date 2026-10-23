# Hapus akun pegawai

Owner membuka **Internal > Kelola pegawai > Atur akses > Hapus akun pegawai**,
memeriksa nama, mengisi alasan 5 sampai 500 karakter, lalu menekan Hapus akun.
Pilihan Batal tidak mengubah akun. Admin, teknisi, dan akun pending tidak dapat
menghapus akun. Akun sendiri serta akun berperan owner dilindungi dari menu ini.

Penghapusan membatalkan akses/login akun dan tidak dapat diaktifkan kembali lewat
Atur akses. **Nonaktifkan** tetap tersedia jika hanya ingin menutup akses aplikasi
sementara dan nanti mengaktifkannya lagi.

## Aktivasi: SQL dan fungsi server

Fitur ini memerlukan **dua langkah**, bukan hanya menjalankan SQL.

1. Jalankan seluruh `supabase/013_delete_employee_account.sql` setelah 012
   melalui SQL Editor Supabase. Direktori pegawai terbaru juga memakai migrasi
   ini; terapkan sebelum menjalankan versi aplikasi terbaru.
2. Deploy Edge Function **delete-employee-account** yang berisi:
   - `supabase/functions/delete-employee-account/index.ts`
   - `supabase/functions/delete-employee-account/handler.mjs`
3. Lakukan hot restart aplikasi. Setelah mengganti peran akun, keluar/masuk
   kembali jika diperlukan.

Dengan Supabase CLI, dari direktori proyek:

```powershell
supabase login
supabase functions deploy delete-employee-account --project-ref PROJECT_REF --no-verify-jwt
```

Ganti PROJECT_REF dengan ID proyek Supabase Perona yang sama dengan aplikasi.
Jika CLI belum tersedia, gunakan CLI melalui `npx supabase` sesuai instalasi
Node.js, atau buat fungsi bernama sama melalui editor Edge Functions di dashboard
dan tambahkan kedua file di atas.

Atur **Verify JWT** platform ke nonaktif untuk fungsi ini, sesuai
`supabase/config.toml`. Handler tetap memverifikasi bearer token ke Auth dan
memeriksa hak owner lewat RPC dengan token pengguna. Pengaturan ini mendukung
proyek dengan JWT signing key baru, bukan memberikan akses anonim.

Fungsi membaca `SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan
`SUPABASE_SERVICE_ROLE_KEY` dari lingkungan server Supabase. Periksa ketiganya
tersedia pada lingkungan fungsi. Service-role key tidak dimasukkan ke Flutter,
`config.json`, body permintaan, atau respons pengguna. Panduan resmi:
[deploy fungsi](https://supabase.com/docs/guides/functions/deploy),
[lingkungan server](https://supabase.com/docs/guides/functions/secrets), dan
[otorisasi fungsi](https://supabase.com/docs/guides/functions/auth).

## Data yang dipertahankan

Supabase Auth dipanggil melalui server dengan `should_soft_delete: true`.
Kredensial/identitas login dihapus oleh Auth dan sesi dicabut, sementara UUID
historis tetap ada. Penghapusan Auth ini tidak dapat dibalik. Lihat
[Auth deleteUser](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser).

Profil historis, nama pegawai, pembuat nota/pembayaran, penanggung jawab layanan,
ongkos yang masih harus dibayar, alokasi upah, foto barang, dan audit tetap ada.
Tidak ada nota, pembayaran, atau file Storage yang dihapus/dipindahkan.
Nama lama tetap dapat muncul pada riwayat dan laporan ongkos. Ini penghapusan
akun operasional, bukan penghapusan seluruh jejak pegawai dari data usaha.

Akun yang sudah selesai dihapus menghilang dari Kelola pegawai dan tidak bisa
dipilih sebagai pegawai aktif untuk layanan baru. Pada layanan lama, nama
pegawai masih tersedia dengan penanda akun dihapus. Pembayaran ongkos lama
tetap bisa diselesaikan owner.

## Jika proses terputus

Penghapusan berjalan bertahap:

1. RPC owner mengunci akun sasaran, memeriksa peran terbaru, menandai penghapusan,
   dan langsung mencabut akses aplikasi. Alasan dan aktor dicatat dalam audit.
2. Fungsi server menghapus login melalui Supabase Auth.
3. RPC khusus server memeriksa status Auth sebelum mengonfirmasi penyelesaian.

Jika langkah Auth/konfirmasi gagal, aplikasi tidak menyatakan penghapusan selesai.
Form menampilkan pesan dan dapat dicoba lagi dengan alasan/akun yang sama.
Tutup form dan periksa daftar bila perlu. Baris **Penghapusan belum selesai**
mempunyai tombol ikon ulang dengan keterangan **Selesaikan penghapusan**.
Proses yang sudah selesai aman dicoba kembali
tanpa menggandakan audit atau menghapus catatan lain.

Penanda penghapusan tidak bisa dipulihkan melalui menu peran, termasuk ketika
Auth masih menunggu penyelesaian. JWT lama langsung kehilangan akses data karena
otorisasi/RLS memakai profil aktif yang belum dihapus. Salinan data yang sudah
terbuka di HP dan tautan foto yang sudah ditandatangani tidak ditarik kembali;
tautan foto mengikuti masa berlaku yang sudah ada.

Alasan/aktor penghapusan khusus owner. Direktori operasional untuk admin/teknisi
memuat identitas/status dasar tanpa alasan internal. Pengguna tetap dapat membaca
profil miliknya sendiri sesuai RLS.

Jika orang yang sama perlu bergabung lagi, daftarkan akun baru dan aktifkan dari
owner. Riwayat UUID lama tidak otomatis dipindahkan ke akun baru.

## Verifikasi

Tes lokal memakai PostgreSQL PGlite dan handler Edge Function yang sama, dengan
Auth/Storage tiruan. Tes memeriksa hak akses, larangan hapus owner/diri sendiri,
peran yang berubah, kegagalan parsial dan retry, JWT lama, privasi direktori,
serta keberlanjutan order, pembayaran, foto, ongkos, dan audit. Tes ini tidak
menghapus pengguna nyata dan belum membuktikan deployment fungsi pada proyek
Supabase online milik pengguna.
