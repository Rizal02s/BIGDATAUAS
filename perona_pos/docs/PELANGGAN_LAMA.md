# Memilih pelanggan lama saat input order

Jalankan seluruh `supabase/011_customer_suggestions.sql` di SQL Editor Supabase
setelah 010, lalu lakukan hot restart aplikasi. Fitur memakai riwayat nota yang
sudah ada dan tidak memerlukan impor atau tabel pelanggan baru.

## Penggunaan

1. Buka **Tambah order**.
2. Ketik minimal dua karakter pada **Nama pelanggan** atau **Nomor WhatsApp**.
3. Setelah berhenti mengetik sebentar, maksimal lima saran muncul tepat di bawah
   kolom yang sedang diisi. Setiap saran menampilkan nama, WA (atau Tanpa nomor
   WhatsApp), tanggal kunjungan terakhir dalam WIB, dan jumlah kunjungan.
4. Ketuk pelanggan yang sesuai. Nama dan WhatsApp otomatis terisi bersama.
5. Tambahkan layanan, estimasi selesai, dan pembayaran seperti biasa, lalu simpan.

Jika tidak cocok dengan saran, teruskan mengetik dan simpan sebagai pelanggan
baru. Nama dan WA yang terisi dari pilihan tetap boleh diedit. Pilihan pelanggan
tidak mengubah nota lama dan tidak langsung mencatat kunjungan. Satu nota baru
yang berhasil disimpan tetap dihitung sebagai satu kunjungan, berapa pun jumlah
layanan atau pasang sepatu di dalamnya.

## Aturan pencocokan

- Nomor WA/telepon menjadi identitas utama. `0812...`, `+62812...`,
  `62812...`, `0062812...`, dan `812...` dicocokkan sebagai nomor Indonesia
  yang sama. Tanda spasi, kurung, dan tanda hubung pada nomor diabaikan.
- Jika nomor kosong, identitas memakai nama tanpa membedakan huruf besar/kecil
  dan spasi berulang. Nama sama dengan nomor berbeda tetap menjadi pilihan
  terpisah; periksa nomor sebelum memilih.
- Sumbernya seluruh nota aktif, bukan hanya nota dalam periode laporan yang
  sedang dibuka. Nota yang dihapus tidak menjadi sumber saran/kunjungan.
- Pencarian nama juga mencakup variasi penulisan pada nota lama. Nama dan nomor
  yang ditampilkan diambil dari nota aktif dengan tanggal masuk paling baru.
  Pencocokan persis diprioritaskan, kemudian kunjungan paling baru.
- Tanggal terakhir datang mengikuti tanggal masuk pada nota, bukan waktu input
  atau waktu membuat nota. Tanggal yang dicatat mundur tetap berlaku.
- Mengubah nomor pada order baru tidak menggabungkan atau memperbaiki identitas
  nota lama secara otomatis. Pelanggan tanpa nomor yang kemudian diberi nomor
  juga belum otomatis digabung ke riwayat dengan identitas nama.

Saran tersedia untuk owner, admin, dan teknisi yang aktif. Server hanya
mengirim nama, nomor, tanggal terakhir datang, jumlah kunjungan, dan kunci
identitas untuk maksimal lima pelanggan. Data ongkos, pembayaran, catatan
internal, dan foto tidak masuk hasil pencarian. Akun pending/nonaktif serta
pengguna tanpa login ditolak.

## Saat koneksi bermasalah

Jika saran gagal dimuat, ketuk **Coba lagi** atau isi nama dan WhatsApp secara
manual. Kegagalan saran tidak menghalangi pengisian dan penyimpanan order melalui
fungsi simpan yang sudah tersedia. Jika migrasi 011 belum diterapkan, aplikasi
menampilkan petunjuk migrasi pada area saran.

Pencarian menunggu 350 milidetik setelah ketikan terakhir untuk mengurangi
permintaan berulang. Respons untuk ketikan lama diabaikan ketika pengguna sudah
mengganti pencarian. Pada **Edit order**, kolom tetap dapat diperbaiki manual;
saran otomatis hanya ditambahkan pada alur Tambah order.
