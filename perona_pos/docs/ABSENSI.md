# Absensi harian Perona Sepatu

## Mengaktifkan

Jalankan seluruh [014_daily_attendance.sql](../supabase/014_daily_attendance.sql)
di SQL Editor proyek Supabase yang dipakai aplikasi, setelah migrasi 013.
Kemudian lakukan hot restart atau pasang build aplikasi terbaru. Absensi hanya
memerlukan migrasi SQL ini; tidak memerlukan Edge Function baru.
Migrasi tidak membuat catatan untuk hari-hari sebelum fitur dipakai.

## Pegawai dan admin

Pada bagian atas halaman utama, ketuk ikon kehadiran **Absensi saya** di dekat
tombol muat ulang. Tidak ada tambahan tab bawah. Semua akun aktif, termasuk
admin dan owner, dapat mencatat kehadirannya sendiri.

1. Ketuk **Absen masuk**, lalu konfirmasi. Jam dan tanggal diambil dari server
   dalam WIB, bukan jam yang dapat diisi pegawai.
2. Ketika selesai bekerja, ketuk **Absen pulang**, lalu konfirmasi.
3. Jika tidak masuk, pilih **Catat izin** atau **Catat sakit**, isi keterangan
   minimal 5 karakter, lalu simpan. Ini catatan langsung untuk hari ini;
   fitur persetujuan izin belum disertakan.
4. Lihat riwayat sendiri, lalu pilih rentang tanggal melalui tombol kalender.
   Tanggal awal dan akhir ikut dihitung, maksimal 366 hari per pencarian.

Satu pegawai memiliki satu catatan per tanggal masuk WIB. Catatan yang sudah
disimpan hanya dapat dikoreksi owner. Pegawai dan admin tidak dapat membaca
absensi orang lain, termasuk melalui API atau tabel database langsung.
Akun pending, nonaktif, atau dihapus tidak dapat mengakses absensi.

## Owner

Buka **Internal > Absensi pegawai**. Kartu teratas adalah absensi owner sendiri.
Di bawahnya terdapat rekap tim, kalender, filter pegawai, jumlah hadir/izin/sakit,
durasi tercatat, dan catatan yang belum pulang. Rekap per pegawai mencakup seluruh
periode, meskipun daftar rinci baru menampilkan 30 catatan per halaman. Gunakan
**Muat catatan berikutnya** untuk meneruskan daftar.

Untuk salah catat atau lupa absen:

- Pada baris yang sudah ada, ketuk **Koreksi**. Pegawai dan tanggalnya tetap;
  ubah status, jam masuk/pulang, atau keterangan sesuai kejadian sebenarnya.
- Untuk hari yang belum mempunyai catatan, ketuk **Isi / koreksi absensi**,
  pilih pegawai aktif dan tanggal. Jika tanggal tersebut ternyata sudah terisi,
  muat ulang lalu gunakan Koreksi pada barisnya.
- Isi alasan perubahan minimal 5 karakter. Status Izin/Sakit juga memerlukan
  keterangan dan tidak menyimpan jam masuk/pulang. Jam pulang boleh dikosongkan
  jika pegawai masih bekerja.
- Waktu harus sudah lewat; jam masuk harus berada pada tanggal absensi WIB,
  dan pulang harus sesudah/sama dengan masuk, maksimal 48 jam.
- Ketuk **Riwayat perubahan** untuk membaca aktor, waktu, nilai sebelum/sesudah,
  dan alasan koreksi. Riwayat ini hanya untuk owner; pegawai melihat catatan
  terkini beserta alasan koreksi terakhir.

Jika HP lain mengubah catatan yang sama, versi lama ditolak. Tutup form,
muat ulang, dan buka catatan terbaru sebelum mengoreksi lagi.

## Jika berganti hari atau koneksi terputus

Absen pulang mengikuti catatan masuk yang masih terbuka, termasuk dari hari
sebelumnya. Tidak membuat catatan baru di tanggal pulang. Selesaikan catatan
tersebut sebelum absen masuk lagi. Setelah lebih dari 48 jam, owner harus
mengoreksi jam pulangnya sesuai kejadian; aplikasi tidak menebak jam pulang.

Penyimpanan membutuhkan koneksi. Jika respons gagal diterima, gunakan **Coba
lagi** pada form yang sama: ID permintaan dan isi dipertahankan agar satu
aksi tidak tercatat dua kali. Bila form ditutup, muat ulang untuk memeriksa
status sebelum melanjutkan. Tidak ada antrean absensi offline.

## Perhitungan dan cakupan

- Hadir dihitung per catatan tanggal masuk, bukan per jumlah layanan.
- Durasi dihitung dari jam masuk sampai pulang yang sudah tercatat, dibulatkan
  ke bawah per menit. Catatan belum pulang tidak menambah durasi. Ini durasi
  kehadiran, tanpa pemotongan waktu istirahat atau perhitungan lembur.
- Belum ada jadwal/shift, aturan terlambat, penetapan alpa, GPS, atau selfie.
  Hari tanpa catatan tidak otomatis berarti absen atau libur.
- Absensi tidak mengubah tarif, hak ongkos, atau pembayaran upah. Ongkos tetap
  dihitung berdasarkan pekerjaan seperti sebelumnya.
- Penghapusan akun mempertahankan riwayat absensi dan nama pegawai. Owner dapat
  membaca/mengoreksi catatan lama, tetapi tidak membuat hari baru untuk akun
  nonaktif/dihapus. UUID akun baru tidak otomatis digabungkan dengan akun lama.

## Verifikasi

Pengujian lokal memakai Flutter dengan repository/jaringan tiruan dan PostgreSQL
PGlite dengan stub Auth/Storage. Termasuk retry, konflik versi, batas WIB,
masuk/pulang lintas hari, RLS setiap peran, pelestarian riwayat, kalender
inklusif, lebih dari 1.000 catatan, paginasi, dan tampilan 320 px pada teks 150%.
Migrasi online serta uji masuk/pulang dua HP nyata belum dijalankan oleh Codex.
