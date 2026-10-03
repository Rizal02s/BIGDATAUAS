# Tampilan owner dan pegawai

Perubahan 3 Oktober 2026. Peran berasal dari `profiles.role` setelah login;
pengguna tidak memilih peran sendiri pada halaman masuk.

## Owner

- Ringkasan: pembayaran masuk, nilai order, ongkos tim, piutang seluruh periode,
  diskon, ongkos per pegawai, dan order terbaru.
- Order: input, detail, pembayaran, foto, dan tindakan koreksi khusus owner.
- Layanan: pencarian, penambahan, perubahan tarif, dan penonaktifan layanan.
- Pegawai: akun aktif dan pending, aktivasi, perubahan peran, dan penonaktifan.

## Pegawai

- Beranda: ongkos pribadi untuk seluruh periode yang dipilih dan order yang
  memiliki layanan dengan `worker_id` milik akun tersebut.
- Order: beralih antara pekerjaan sendiri dan seluruh order untuk operasional.
- Layanan: pencarian dan pembacaan harga/ongkos layanan aktif.
- Menu pengelolaan pegawai dan perubahan tarif tidak tersedia pada UI pegawai.

Pekerjaan sendiri disaring di query Supabase sebelum paginasi. Angka ongkos
pribadi diambil dari hasil RPC `period_report` berdasarkan ID akun, bukan dari
penjumlahan satu halaman order. Pada kartu pekerjaan sendiri, layanan dan ongkos
yang ditampilkan hanya bagian milik pegawai; sisa tagihan tetap milik order pelanggan.

Tidak ada migrasi database baru untuk perubahan UI ini. Aturan backend yang
ada tetap berlaku: akun aktif bisa membaca data operasional bersama, sedangkan
pengelolaan tarif/peran, penghapusan order, dan koreksi pembayaran memerlukan owner.
Home pribadi bukan pembatasan privasi upah pada API. Ongkos tercatat belum
menunjukkan apakah gaji sudah dibayar.

## Pemeriksaan

- `flutter analyze lib test`: lulus tanpa temuan.
- `flutter test --dart-define=UI_PREVIEW=true`: 32 tes lulus, mencakup peran,
  penugasan, ongkos seluruh periode, menu pegawai, layar 360 px dengan teks 150%,
  keadaan kosong, pemulihan dari kegagalan pemuatan, input pembayaran/foto,
  retry tanpa order/pembayaran/foto ganda, dan pembukaan detail dari rekap.
- `flutter build apk --debug --dart-define-from-file=config.json`: berhasil.

Preview berikut memakai data contoh dari tes, bukan transaksi usaha:

![Home owner](ui/owner-home.png)
![Home pegawai](ui/staff-home.png)
![Pekerjaan pegawai](ui/staff-work.png)
![Pengelolaan pegawai](ui/owner-team.png)

Untuk membuat ulang preview, jalankan tes dengan flag `UI_PREVIEW` di atas.
Tes biasa tidak menulis gambar. Untuk melihat perubahan pada sesi Flutter yang
sedang berjalan, lakukan hot restart (`R`) atau jalankan ulang aplikasi dengan
`flutter run --dart-define-from-file=config.json`.

## Tema logo dan form order

Tema menggunakan hijau logo (`#8CB719`) dan cream (`#FAF5E7`), dengan kartu cream
terang dan teks gelap. PNG logo asli disimpan tanpa perubahan sebagai asset dan
ditampilkan di login serta header home.

Order baru menyediakan tiga pilihan pembayaran awal:

- **Tunai**: mencatat pelunasan dengan metode Tunai.
- **QRIS**: mencatat pelunasan QRIS yang sudah diterima kasir; belum verifikasi
  otomatis atau pembuatan QR pembayaran.
- **Belum lunas** (default): tidak membuat pembayaran. Pembayaran bertahap/DP
  atau pelunasan dapat ditambahkan lewat detail order.

Foto dapat dipilih dari kamera/galeri sebelum menyimpan; beberapa foto didukung.
Preview dapat dihapus sebelum penyimpanan. Batas dan Storage privat yang sudah
ada tetap digunakan. Kartu order menampilkan metode pembayaran, lunas/belum
lunas, dan jumlah foto. Ketuk kartu untuk membuka layanan, pegawai, pembayaran,
catatan pelanggan, dan foto yang terkait.

Order disimpan terlebih dahulu melalui RPC yang sudah ada, lalu pembayaran dan
foto. Jika tahap lanjutan gagal, form menampilkan bahwa order sudah tersimpan
dan menawarkan retry atau membuka detail. Retry memakai ID order/pembayaran/foto
yang sama dan melewati tahap yang sudah selesai. Jangan memulai order baru untuk
mengulangi tahap lanjutan yang gagal. Jika tarif server berbeda dari tagihan yang
ditampilkan, kasir harus meninjau dan mencatat pembayaran dari detail order.

Tidak perlu mengulang schema/seed atau menjalankan SQL tambahan untuk fitur ini.
Tes pembayaran/foto memakai repository dan HTTP tiruan; pengujian transaksi,
QRIS, kamera, dan unggah Storage sebenarnya di perangkat nyata belum dilakukan.

![Form order](ui/order-form.png)
![Pembayaran dan foto pada form](ui/order-payment-photo.png)
