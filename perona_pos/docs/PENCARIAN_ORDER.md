# Pencarian dan filter order

Pada tab **Order**, pilih periode Harian, Bulanan, atau Tahunan dan tanggalnya.
Kolom **Cari order** menerima sebagian nama pelanggan, nomor WhatsApp, atau
nomor nota, misalnya `Nadia`, `0812 3456`, `24`, atau `#24`.
Pencarian tidak membedakan huruf besar/kecil. Format WA `08…`, `628…`, dan
`+628…` dicocokkan dengan normalisasi nomor.

Pencarian dan kedua filter status dapat digunakan bersamaan. Hasil langsung
menampilkan nota pada periode terpilih, termasuk ketika tampilan awal Bulanan
mengelompokkan nota berdasarkan tanggal. Tanpa pencarian atau filter aktif,
tampilan daftar/tanggal semula tetap digunakan. Tombol **Reset pencarian & filter**
mengosongkan keduanya. Ikon silang hanya mengosongkan teks pencarian.

## Status pengerjaan

- **Masuk:** semua layanan pada nota berstatus Masuk.
- **Dikerjakan:** layanan sedang dikerjakan atau memiliki kemajuan campuran
  yang belum seluruhnya selesai.
- **Selesai:** seluruh layanan selesai/diambil, dan masih ada layanan selesai
  yang belum diambil.
- **Diambil:** seluruh layanan sudah diambil.
- **Belum diambil:** masih ada layanan yang belum diambil; termasuk pekerjaan
  yang masih masuk/dikerjakan. Untuk barang selesai yang siap diambil, pilih
  **Selesai**.

Pada pilihan **Pekerjaan saya**, ringkasan dan filter pengerjaan hanya mengikuti
layanan yang ditugaskan kepada teknisi tersebut. Pembayaran tetap mengikuti
seluruh tagihan nota.

## Status pembayaran

- **Belum lunas:** mencakup belum bayar dan DP.
- **Belum bayar:** belum ada pembayaran aktif dan tagihan masih tersisa.
- **DP:** sudah dibayar sebagian, masih ada sisa tagihan.
- **Lunas:** tidak ada sisa tagihan.

Pembayaran yang telah dikoreksi/dibatalkan tidak dihitung. Nota tanpa tagihan
diperlakukan sebagai lunas.

## Hasil dan pembaruan

Seluruh halaman data dalam periode dibaca sebelum pencocokan, kemudian hasil
diurutkan dari nota terbaru dan ditampilkan maksimal 30 per halaman.
Mengubah teks atau status memakai data yang sudah dimuat. Mengubah periode,
pilihan pekerjaan, memuat ulang, atau kembali dari detail/status cepat akan
memperbarui data. Saat koneksi gagal, gunakan **Coba lagi**.

Pencarian juga tersedia pada halaman rincian order per tanggal. Tombol hapus
semua per tanggal disembunyikan ketika filter aktif; penghapusan satu nota
tetap tersedia untuk owner.

**Unduh rekap PDF** tetap mengikuti periode dan pilihan pekerjaan, bukan teks
pencarian atau filter status. Fitur ini memakai API yang sudah ada dan tidak
memerlukan migrasi Supabase baru. Pembatasan akses admin tetap mengikuti API
tanpa data ongkos.
