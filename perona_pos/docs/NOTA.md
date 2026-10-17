# Nota gambar dan WhatsApp

Versi `0.1.5+6`, 17 Oktober 2026.

Pilih **Simpan & buat nota** pada form order atau **Nota pelanggan** pada detail
order. Nota menampilkan logo, nomor dan tanggal order dalam WIB, pelanggan,
nomor WA, layanan, jumlah, harga, diskon, tagihan, pembayaran aktif, sisa dan
status lunas. Ongkos, identitas teknisi, serta catatan internal tidak disertakan.

## Unduh gambar

Tekan **Unduh gambar**, pilih lokasi seperti Downloads, lalu simpan. Hasilnya
PNG selebar 1080 piksel. Nota panjang dibagi menjadi beberapa gambar agar tidak
terpotong dan ukuran gambar tetap terbatas. Gunakan panah bagian lalu unduh
bagian yang dipilih; nama berkas mencantumkan nomor order dan nomor bagian.
Membatalkan penyimpanan tidak mengubah order atau pembayaran.

## Bagikan ke WhatsApp

1. Nomor tujuan otomatis diisi dari order. Nomor dapat diperbaiki untuk
   pengiriman ini tanpa mengubah nomor pada data order.
2. Tekan **Bagikan ke WhatsApp**. Jika WhatsApp biasa dan WhatsApp Business
   terpasang bersamaan, pilih aplikasi yang akan digunakan.
3. Periksa penerima dan gambar di WhatsApp, kemudian tekan kirim. Semua bagian
   nota dilampirkan jika nota terdiri dari beberapa gambar.

Nomor Indonesia `08…`, `8…`, dan `+628…` dinormalisasi menjadi `628…`.
Untuk nomor negara lain gunakan awalan internasional seperti `+44…`.
Nomor kosong atau tidak valid harus diperbaiki sebelum berbagi; unduhan tetap
bisa dilakukan. Validasi format tidak membuktikan nomor memiliki akun WhatsApp.

Android meneruskan gambar sebagai `image/png` melalui `ACTION_SEND` atau
`ACTION_SEND_MULTIPLE`, URI FileProvider dan izin baca sementara. Berkas berada
di cache privat; tidak membutuhkan izin membaca kontak atau seluruh galeri.
Cache lampiran berumur lebih dari 48 jam dibersihkan ketika berbagi berikutnya.

Nomor tujuan disertakan melalui hint `jid` milik WhatsApp. **Hint ini bukan
kontrak API publik dan tidak menjamin penerima terpilih pada semua versi
WhatsApp**, terutama untuk nomor yang belum dikenal atau kiriman beberapa
gambar. Jika WhatsApp tetap membuka pemilih penerima, pilih pelanggan sesuai
nomor tujuan. Aplikasi tidak mengklaim nota sudah terkirim ketika WhatsApp dibuka.

Pilihan **Buka chat pelanggan** memakai tautan resmi `wa.me` untuk membuka
percakapan sesuai nomor. Tombol ini hanya membuka chat. Jika diperlukan,
unduh nota terlebih dahulu lalu lampirkan gambar secara manual di chat tersebut.
WhatsApp yang belum terpasang menampilkan pesan agar pengguna mengunduh nota
atau memasang WhatsApp. Berbagi langsung ini tersedia di Android.

Order, pembayaran dan foto disimpan sebelum pembuatan nota. Tombol
**Coba buat nota lagi** hanya mengambil ulang data dan membuat gambar, tanpa
mengulang penyimpanan order/pembayaran. Membuka nota kembali mengambil data
pembayaran terbaru dari server. Rekap order dan rincian ongkos tetap memakai PDF.

## Pemeriksaan di HP

- Uji WhatsApp biasa, Business, atau keduanya; nomor tersimpan dan belum tersimpan.
- Periksa penerima dan seluruh gambar sebelum mengirim, termasuk nota beberapa bagian.
- Uji nomor kosong/salah, WhatsApp tidak terpasang, batal menyimpan, dan kembali
  dari WhatsApp tanpa mengirim. Semua harus tetap memungkinkan percobaan ulang.
- Karena ada perubahan Android native, hentikan aplikasi lalu jalankan kembali
  `flutter run --dart-define-from-file=config.json`; hot reload saja tidak cukup.

## Verifikasi pengembangan

74 tes Flutter lulus, termasuk unduhan PNG, batal/gagal lalu mencoba kembali,
normalisasi nomor, pilihan WhatsApp/Business, lampiran beberapa bagian, nomor
kosong, WhatsApp tidak tersedia, dan pengulangan nota tanpa order ganda. Kanal
WhatsApp pada tes memakai mock; penerima otomatis pada WhatsApp asli belum
diverifikasi. PNG contoh dan nota 100 layanan telah dibuat dan diperiksa secara
visual. Perubahan data internal (ongkos, teknisi, catatan) tidak mengubah PNG.

Referensi: [Android berbagi data](https://developer.android.com/training/sharing/send),
[FileProvider](https://developer.android.com/training/secure-file-sharing/setup-sharing),
[WhatsApp click to chat](https://faq.whatsapp.com/5913398998672934).
