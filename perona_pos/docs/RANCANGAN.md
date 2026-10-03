# Rancangan Perona Kasir

Aplikasi Android untuk mencatat jasa laundry sepatu, tas, topi, helm, dompet, stroller, car seat, dan repair. Satu proyek backend dipakai bersama oleh HP owner dan pegawai.

## Arsitektur

**Flutter → Supabase Authentication + PostgreSQL + Storage privat.** Flutter mengatur tampilan, kamera dan input. PostgreSQL menghitung harga dan ongkos secara resmi. Foto berada dalam Storage; database menyimpan kaitannya dengan order.

Supabase dipilih agar database dan foto dapat dimulai pada paket Free. Kuota tetap perlu diperhatikan. Firebase tetap bisa dipakai, tetapi Cloud Storage kini memerlukan paket Blaze yang terhubung billing; kebutuhan awal pengguna lebih sesuai dengan Supabase Free.

Setup backend dilakukan satu kali. Setelah itu, input/edit/hapus order, perubahan tarif, upload foto, dan aktivasi pegawai dilakukan melalui aplikasi.

## Alur kerja

1. Pegawai masuk dengan akun sendiri yang sudah disetujui owner.
2. Buat order pelanggan dan isi kondisi barang.
3. Tambahkan satu atau beberapa layanan, jumlah unit/pasang, dan pegawai penerima ongkos masing-masing.
4. Aplikasi menampilkan estimasi; server memvalidasi, menghitung ulang dan menyimpan transaksi.
5. Saat order masuk, ongkos langsung tercatat sebagai hak pegawai, sesuai pilihan pengguna.
6. Tambahkan foto dan pembayaran: tunai, transfer atau QRIS yang dicatat manual.
7. Edit status Masuk → Dikerjakan → Selesai → Diambil sesuai pengerjaan; status tidak mengubah tanggal pengakuan upah.
8. Owner/pegawai melihat rekap harian, bulanan, tahunan dan rincian ongkos kerja.

QRIS di MVP hanya label metode pembayaran, belum verifikasi otomatis dari penyedia pembayaran.

## Data inti

| Data | Isi utama | Aturan |
|---|---|---|
| profiles | ID akun, nama, peran | Akun baru pending; owner menyetujui |
| services | Nama, kategori, harga, ongkos, aktif | Owner mengatur melalui aplikasi |
| orders | Pelanggan, kontak, catatan, item, diskon, total, versi | Validasi dan harga/upah dihitung server |
| items dalam order | Snapshot layanan/harga/ongkos, jumlah, pegawai, status | Tarif item lama tetap saat master berubah |
| payments | Nominal, metode, waktu masuk, koreksi | Bisa beberapa pembayaran per order |
| order_photos | Order, path foto privat, pengunggah | Foto dari aplikasi |
| audit_log | Aktor, tindakan, data sebelum/sesudah | Jejak edit, tarif, peran dan koreksi |

Nilai uang disimpan sebagai rupiah bulat. Tidak memakai floating point untuk harga atau ongkos.

## Pengertian rekap

| Indikator | Dasar tanggal dan perhitungan |
|---|---|
| Jumlah order | Order aktif yang dicatat pada periode |
| Nilai order | Harga layanan × jumlah − diskon; tanggal order dibuat |
| Upah tercatat | Tarif ongkos × jumlah; tanggal order dibuat, per pegawai yang ditugaskan |
| Pembayaran masuk | Pembayaran valid; tanggal masing-masing pembayaran |
| Piutang semua order | Total seluruh order aktif − seluruh pembayaran valid; saldo saat ini, bukan hanya periode terpilih |
| Sisa setelah upah | Nilai order periode − upah periode; belum biaya operasional |

Contoh: order masuk 2 Oktober, dilunasi 5 Oktober. Nilai order dan upah masuk tanggal 2; uang pembayaran masuk tanggal 5. Upah belum berarti sudah dibayarkan kepada pegawai.

Mengedit jumlah, mengganti pegawai, atau menghapus order akan memperbarui rekap pada tanggal order dibuat. Penguncian upah yang sudah disetorkan menjadi pengembangan berikutnya sebelum aplikasi dipakai sebagai buku pembayaran gaji.

## Hak akses awal

| Aktivitas | Owner | Pegawai aktif | Pending/nonaktif |
|---|---|---|---|
| Baca order/foto/rekap/ongkos | Ya, seluruh usaha | Ya, seluruh usaha | Tidak |
| Input dan edit order | Ya | Ya | Tidak |
| Tambah foto dan pembayaran | Ya | Ya | Tidak |
| Hapus order / koreksi pembayaran | Ya, dengan alasan | Tidak | Tidak |
| Ubah price list/ongkos | Ya | Tidak | Tidak |
| Aktivasi/peran akun | Ya | Tidak | Tidak |
| Baca audit | Ya, melalui API/database | Tidak | Tidak |

Penghapusan berarti keluar dari rekap dengan jejak audit tetap tersimpan. Pada MVP, order yang memiliki pembayaran valid harus dikoreksi pembayarannya lebih dahulu jika memang salah input. Refund nyata membutuhkan modul berbeda.

## Penanganan pemakaian dari beberapa HP

- Semua perangkat memakai URL backend dan publishable key proyek yang sama.
- Setiap pegawai menggunakan akun berbeda agar pencatatan aktor dapat ditelusuri.
- Simpan order membawa nomor versi. Jika HP lain sudah mengedit order, versi lama ditolak agar tidak menimpa data baru.
- Tabel transaksi tidak dapat ditulis langsung oleh aplikasi; pemanggilan fungsi server memvalidasi peran, harga, upah, jumlah, diskon, pembayaran, dan pegawai.
- Master tarif diambil ketika item baru ditambahkan. Edit item lama mempertahankan snapshot tarif.
- Perhitungan di layar hanya estimasi; keputusan akhir ada di server.
- MVP memakai muat ulang untuk melihat perubahan dari HP lain. Realtime dan antrean offline belum dibuat.

## Tarif dari gambar

Ada 32 layanan dengan harga customer dan ongkos lengkap pada tabel. Daftar disertakan dalam `data/price_list.csv` dan SQL seed.

Recolour Midsole memakai Rp60.000, bukan Rp50.000 di poster, sesuai pilihan pengguna. Repaint/Recolour Bag di poster Rp200.000–250.000 belum ditambahkan karena tarif ongkos belum diberikan. Owner dapat menentukan varian dan ongkosnya melalui aplikasi.

## Tahap menuju pemakaian online

| Tahap | Hasil | Status paket ini |
|---|---|---|
| Konsep dan tarif | Alur, formula, hak akses, katalog | Selesai |
| Implementasi MVP | Kode Flutter dan migrasi Supabase | Tersedia |
| Pemeriksaan lokal | Domain Dart dan SQL/RLS | Lulus; rincian di VALIDASI.md |
| Build Flutter lengkap | Analyze, widget test dan APK | Belum diverifikasi |
| Backend milik pengguna | Proyek Free, schema, katalog, konfigurasi | Memerlukan setup akun pengguna |
| Pilot dua HP | Login, edit bersamaan, foto, pembayaran dan rekap | Belum dijalankan |
| Distribusi | Keystore release dan APK untuk setiap pegawai | Setelah pilot lulus |

## Pengembangan setelah MVP

Prioritas berikutnya: nota PDF/print, pencarian pelanggan/order, export rekap, pencatatan pembayaran upah dan penguncian periode, refund, perbaikan login/recovery akun, viewer audit, penggantian foto, backup dan retensi foto. Realtime dan offline dapat ditambahkan setelah alur transaksi stabil.

MVP ini membangun inti kasir; belum memberi jaminan kesiapan produksi sebelum uji aplikasi dan perangkat nyata selesai.
