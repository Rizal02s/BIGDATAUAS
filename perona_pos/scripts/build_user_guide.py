"""Build the Indonesian operator handbook from reviewed application behavior."""
from pathlib import Path
from html import escape
import json
import re

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, KeepTogether,
)
from PIL import Image as PILImage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'pdf'
TMP = ROOT / 'tmp' / 'pdfs'
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
PDF = OUT / 'Panduan_Lengkap_Perona_Kasir.pdf'
pdfmetrics.registerFont(TTFont('Roboto', str(ROOT / 'assets/fonts/Roboto-Regular.ttf')))
pdfmetrics.registerFont(TTFont('RobotoBold', str(ROOT / 'assets/fonts/Roboto-Bold.ttf')))
pdfmetrics.registerFontFamily('Roboto', normal='Roboto', bold='RobotoBold', italic='Roboto', boldItalic='RobotoBold')
INK = colors.HexColor('#252a26')
GREEN = colors.HexColor('#58730b')
BRAND = colors.HexColor('#8cb719')
PALE = colors.HexColor('#edf4df')
MUTED = colors.HexColor('#687169')
LINE = colors.HexColor('#e3e7e0')
WIDTH, HEIGHT = A4
MARGIN = 43
BODY_W = WIDTH - 2 * MARGIN
styles = {
    'body': ParagraphStyle('body', fontName='Roboto', fontSize=10.5, leading=15.2, textColor=INK, spaceAfter=8),
    'small': ParagraphStyle('small', fontName='Roboto', fontSize=9, leading=12.7, textColor=MUTED, spaceAfter=7),
    'h2': ParagraphStyle('h2', fontName='RobotoBold', fontSize=12, leading=16, textColor=GREEN, spaceBefore=10, spaceAfter=7, keepWithNext=True),
    'title': ParagraphStyle('title', fontName='RobotoBold', fontSize=24, leading=29, textColor=INK, spaceAfter=11),
    'eyebrow': ParagraphStyle('eyebrow', fontName='RobotoBold', fontSize=9, leading=12, textColor=GREEN, spaceAfter=9),
    'table': ParagraphStyle('table', fontName='Roboto', fontSize=9.2, leading=12.8, textColor=INK),
    'th': ParagraphStyle('th', fontName='RobotoBold', fontSize=9.2, leading=12.8, textColor=GREEN),
    'caption': ParagraphStyle('caption', fontName='Roboto', fontSize=9, leading=13, textColor=MUTED, spaceBefore=9),
    'toc': ParagraphStyle('toc', fontName='Roboto', fontSize=10, leading=13, textColor=INK),
}

def markup(text):
    return re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', escape(str(text))).replace('\n', '<br/>')

def p(text, style='body'):
    return Paragraph(markup(text), styles[style])

def P(text): return ('p', text)
def H(text): return ('h', text)
def S(*items): return ('steps', items)
def B(*items): return ('bullets', items)
def T(headers, rows, weights=None): return ('table', headers, rows, weights)
def N(title, text): return ('note', title, text)

chapters = []
def section(title, roles, *blocks):
    chapters.append({'title': title, 'roles': roles, 'blocks': blocks})

section('Mengenal aplikasi dan hak akses', 'SEMUA PENGGUNA',
 P('Perona Kasir membantu mencatat penerimaan sepatu, layanan, pembayaran pelanggan, pengerjaan, ongkos, serta urusan internal toko. Satu nota dapat berisi beberapa layanan dan beberapa pasang sepatu.'),
 T(['Peran', 'Menu bawah', 'Tanggung jawab utama'], [
  ['Owner', 'Ringkasan, Order, Layanan, Ongkos, Internal', 'Mengelola usaha, tarif, akses akun, kas, biaya, ongkos, dan absensi tim.'],
  ['Admin', 'Beranda, Order, Layanan, Laporan', 'Operasional pelanggan, pengerjaan, penerimaan, laporan dan tutup kas pertama.'],
  ['Teknisi', 'Ringkasan, Order, Layanan, Ongkos', 'Mencatat pekerjaan, status, pembayaran/foto, dan membaca ongkos tim.'],
 ], [0.15,0.35,0.50]),
 H('Batas akses yang perlu diingat'),
 B('Owner, admin, dan teknisi aktif dapat membuat/mengedit order, mencatat pembayaran, menambah foto, dan membuat nota pelanggan.',
   'Admin tidak melihat ongkos, pembayaran upah, kontribusi setelah ongkos, atau data Internal. Layanan admin hanya berisi harga pelanggan.',
   'Teknisi saat ini boleh membaca ongkos seluruh tim. Pilihan Pekerjaan saya membantu fokus pada tugasnya, bukan mengubah izin baca seluruh tim.',
   'Hanya owner mengubah tarif, mengatur akun, menghapus order, mengoreksi pembayaran, mencatat ongkos dibayar, dan mengelola Internal.',
   'Absensi pribadi tersedia untuk semua akun aktif. Hanya owner melihat rekap absensi tim dan melakukan koreksi.'),
 N('Satu usaha, data bersama', 'Aplikasi disiapkan untuk satu usaha/outlet pada satu proyek Supabase. Setiap orang masuk dengan akun masing-masing; perubahan dari HP lain terlihat setelah dimuat ulang.'))

section('Masuk, mendaftar, dan aktivasi akun', 'SEMUA PENGGUNA / AKTIVASI OLEH OWNER',
 H('Pendaftaran pegawai baru'),
 S('Buka aplikasi, pilih menu daftar akun pegawai.',
   'Isi Nama pegawai, Email, dan Password. Gunakan email milik pegawai agar identitas akun jelas. Password mengikuti validasi pada layar.',
   'Tekan Daftar akun pegawai. Jika proyek meminta konfirmasi email, buka kotak masuk dan ikuti konfirmasinya.',
   'Masuk dengan email dan password. Akun baru berada pada status menunggu aktivasi sampai owner memberikan peran.'),
 H('Aktivasi oleh owner'),
 S('Owner masuk lalu membuka Internal > Kelola pegawai.',
   'Cari nama akun yang benar, ketuk Atur akses, lalu pilih Aktifkan sebagai admin atau Aktifkan sebagai teknisi. Pilih owner hanya untuk pemilik yang memang memerlukan akses penuh.',
   'Pegawai menekan Periksa status. Bila menu belum berubah, keluar lalu masuk kembali.'),
 H('Login berikutnya dan keluar'),
 P('Pada halaman Masuk, isi email/password lalu tekan Masuk. Ikon keluar di bagian atas halaman utama digunakan untuk mengakhiri sesi. Jangan berbagi satu akun untuk beberapa orang karena pencatatan operator mengikuti akun yang sedang masuk.'),
 N('Akun belum aktif atau nonaktif', 'Akun menunggu aktivasi, dinonaktifkan, atau dihapus tidak bisa menjalankan operasional. Hubungi owner. Akun yang sudah dihapus memerlukan pendaftaran baru bila orang tersebut bergabung kembali.'),
 N('Konfirmasi email', 'Kebutuhan konfirmasi ditentukan pengaturan Supabase proyek. Jika muncul email rate limit exceeded, minta pengelola memeriksa pengiriman email. Itu bukan bukti bahwa password atau alamat email salah.'))

section('Alur harian dan halaman utama', 'OWNER, ADMIN, DAN TEKNISI',
 T(['Tahap', 'Tindakan di aplikasi'], [
  ['Mulai kerja', 'Masuk ke akun, muat ulang data, catat absen masuk. Owner/admin memeriksa kas.'],
  ['Barang diterima', 'Buat order, pilih pelanggan, layanan/pegawai, estimasi, pembayaran dan foto.'],
  ['Pengerjaan', 'Periksa Prioritas pengerjaan, lalu perbarui status layanan.'],
  ['Barang diambil', 'Periksa sisa tagihan, catat pembayaran yang diterima, ubah status menjadi Diambil, dan kirim nota terbaru.'],
  ['Akhir kerja', 'Catat absen pulang. Owner/admin mencocokkan kas; owner meninjau biaya dan ongkos.'],
 ], [0.22,0.78]),
 H('Ringkasan untuk owner dan teknisi'),
 P('Menampilkan nota yang masuk pada bulan berjalan dalam WIB: jumlah order, pelanggan belum lunas, pembayaran QRIS, dan pembayaran Tunai. Kartu belum lunas menampilkan jumlah pelanggan unik serta sisa tagihannya. Ketuk kartu pembayaran/piutang untuk membuka rincian pelanggan dan nota.'),
 P('Nota dengan pembayaran campuran dapat muncul di kategori Tunai dan QRIS. Nominal tiap kartu hanya menjumlahkan metode terkait. Pembayaran Transfer tetap tercatat pada nota dan tersedia di laporan kas/penerimaan yang mendukungnya.'),
 H('Beranda untuk admin'),
 P('Admin melihat periode Harian/Bulanan/Tahunan, nota masuk, belum selesai, terlambat, dan penerimaan pelanggan. Gunakan Buat order baru, Kas harian, Prioritas pengerjaan, atau buka nota terbaru.'),
 N('Muat ulang', 'Ketuk ikon muat ulang atau tarik daftar ke bawah setelah perubahan dari HP lain, setelah melewati tengah malam, atau bila angka belum berubah. Aplikasi membutuhkan internet dan belum memiliki antrean transaksi offline.'))

section('Membuat order: data pelanggan', 'OWNER, ADMIN, DAN TEKNISI',
 S('Buka Order atau halaman utama, lalu tekan Buat order baru.',
   'Periksa Tanggal order dan Jam order. Default adalah waktu sekarang; gunakan tanggal masuk sebenarnya jika mencatat order lama. Semua waktu ditampilkan dalam WIB.',
   'Isi Nama pelanggan dan Nomor WhatsApp. Nomor membantu pencocokan pelanggan lama dan peringkat kunjungan.',
   'Isi Kondisi barang / catatan pengerjaan, misalnya warna, noda, kerusakan awal, atau permintaan khusus.',
   'Ketuk Pilih estimasi selesai jika sudah ada target. Estimasi berlaku untuk seluruh nota dan boleh dikosongkan.',
   'Lanjutkan ke pilihan layanan, pembayaran awal, serta foto sebelum menyimpan.'),
 H('Memilih pelanggan yang pernah datang'),
 P('Pada Tambah order, ketik minimal dua karakter nama atau nomor WhatsApp. Setelah berhenti mengetik sebentar, maksimal lima saran tampil. Periksa nama, nomor, tanggal terakhir datang, dan jumlah kunjungan, lalu ketuk pilihan yang sesuai. Nama dan nomor terisi bersamaan.'),
 P('Jika tidak ada yang cocok, lanjutkan mengisi pelanggan baru. Saran hanya membantu pengisian; data tetap boleh diperbaiki sebelum disimpan. Kunjungan baru dihitung setelah nota berhasil disimpan. Saran otomatis tidak ditampilkan pada Edit order.'),
 N('Nomor yang konsisten', '08..., 8..., 628..., +628..., dan format Indonesia setara dicocokkan sebagai nomor yang sama. Jika nomor kosong, aplikasi memakai nama tanpa membedakan huruf besar/kecil dan spasi berulang. Nama sama tanpa nomor berpotensi tergabung.'),
 N('Catatan tanggal', 'Pembayaran awal Tunai/QRIS mengikuti tanggal order yang dipilih. Mengedit tanggal order tidak memindahkan pembayaran yang sudah tersimpan. Jangan mencatat uang baru sebagai pembayaran awal order lama.'))

section('Membuat order: layanan dan simpan', 'OWNER, ADMIN, DAN TEKNISI',
 S('Tekan Tambah layanan, cari nama layanan atau pilih kategori, lalu pilih layanan yang dipesan.',
   'Periksa jumlah unit/pasang. Menambah layanan yang sama dari pemilih akan menaikkan jumlah pada baris yang sudah ada; periksa kembali penanggung jawabnya.',
   'Buka rincian baris untuk memilih Penanggung jawab layanan dan Status pengerjaan. Admin memilih teknisi/owner yang mengerjakan layanan; admin bukan penerima ongkos teknisi.',
   'Isi Diskon total dalam rupiah bila ada. Diskon berlaku pada total nota dan tidak boleh melebihi nilai layanan.',
   'Pada Pembayaran awal, pilih Tunai atau QRIS hanya jika tagihan sudah dibayar penuh. Pilih Belum lunas untuk belum bayar, DP, atau pembayaran yang akan dicatat lewat detail.',
   'Tambahkan Foto barang dari Kamera atau Galeri bila perlu. Tekan Simpan order atau Simpan & buat nota.'),
 H('DP dan pembayaran Transfer saat order baru'),
 P('Form awal Tunai/QRIS mencatat pelunasan sebesar seluruh tagihan, bukan kolom DP bebas. Untuk DP atau Transfer: simpan sebagai Belum lunas, buka detail order, lalu Tambah pembayaran dengan nominal serta metode yang benar.'),
 H('Foto dan hasil penyimpanan'),
 P('Setiap foto maksimal 2 MB; gunakan JPG, PNG, atau WebP. Foto lebih besar/format lain ditolak. Foto tersimpan privat bersama order. Catatan internal dan foto barang tidak otomatis disertakan dalam nota pelanggan.'),
 N('Jika proses terputus', 'Order, pembayaran, dan foto disimpan bertahap. Gunakan Coba lagi pada form yang sama atau Buka detail order yang tersimpan sesuai pesan. Periksa bagian yang sudah berhasil sebelum membuat order baru agar tidak menggandakan nota.'))

section('Detail order dan status pengerjaan', 'OWNER, ADMIN, DAN TEKNISI',
 P('Ketuk nama pelanggan atau baris nota untuk membuka Detail order. Halaman memuat nomor nota, tanggal masuk, WhatsApp, catatan, estimasi, layanan/penanggung jawab, diskon, total tagihan, pembayaran, sisa, riwayat pembayaran, dan foto.'),
 T(['Status layanan', 'Dipakai ketika'], [
  ['Masuk', 'Barang diterima dan layanan belum dikerjakan.'],
  ['Dikerjakan', 'Layanan sedang dalam proses.'],
  ['Selesai', 'Pengerjaan layanan selesai, tetapi barang belum ditandai diambil.'],
  ['Diambil', 'Barang/layanan terkait sudah diserahkan kepada pelanggan.'],
 ], [0.23,0.77]),
 H('Mengubah status dengan cepat'),
 S('Pada kartu order, ketuk label Pengerjaan.',
   'Pilih status di bagian atas untuk semua layanan yang ditampilkan, atau atur dropdown setiap layanan jika kemajuannya berbeda.',
   'Tekan Simpan status, lalu periksa kartu yang diperbarui.'),
 P('Dalam Pekerjaan saya, dialog status cepat hanya menampilkan dan memperbarui layanan milik teknisi tersebut. Pembayaran tetap milik seluruh nota. Untuk memperbaiki data pelanggan, jumlah, pegawai, atau estimasi, buka Edit order.'),
 H('Foto setelah order tersimpan'),
 P('Buka Detail order > Foto barang > Kamera/Galeri. Penambahan foto dapat dilakukan kemudian. Foto yang sudah terhubung belum memiliki tombol ganti/hapus melalui aplikasi.'),
 N('Status pengerjaan dan pembayaran terpisah', 'Selesai tidak otomatis berarti Lunas, dan Lunas tidak berarti barang sudah Diambil. Periksa keduanya sebelum menyerahkan barang. Jika data berubah di HP lain, muat ulang sebelum menyimpan perubahan.'))

section('Pembayaran, DP, pelunasan, dan koreksi', 'PENCATATAN: SEMUA PERAN AKTIF / KOREKSI: OWNER',
 S('Buka Detail order > Tambah pembayaran, atau ketuk label Pembayaran pada kartu.',
   'Nominal awal mengikuti sisa tagihan. Ganti dengan uang yang benar-benar diterima jika pelanggan membayar sebagian.',
   'Pilih metode Tunai, QRIS, atau Transfer, lalu simpan. Nominal harus lebih dari nol dan tidak melebihi sisa tagihan.',
   'Periksa riwayat, total sudah dibayar, dan sisa terbaru. Buka ulang nota pelanggan bila perlu dikirim ulang.'),
 T(['Label', 'Arti'], [
  ['Belum bayar', 'Belum ada pembayaran aktif, tagihan masih tersisa.'],
  ['DP', 'Sebagian tagihan sudah dibayar, masih ada sisa.'],
  ['Lunas', 'Sisa tagihan nol. Nota tanpa tagihan juga dianggap lunas.'],
  ['Belum lunas', 'Kelompok filter yang mencakup Belum bayar dan DP.'],
 ], [0.23,0.77]),
 P('Pembayaran susulan menggunakan waktu server saat dicatat, ditampilkan dalam WIB. Pelunasan nota bulan lalu yang diterima hari ini masuk penerimaan hari ini. Setiap pembayaran disimpan terpisah; jangan menambahkan jumlah seluruh pembayaran lama sebagai pembayaran baru.'),
 H('Koreksi salah input oleh owner'),
 S('Pada riwayat pembayaran, ketuk ikon Koreksi salah input di pembayaran yang keliru.',
   'Isi alasan minimal 5 karakter lalu konfirmasi. Pembayaran lama ditandai dikoreksi dan tidak dihitung lagi.',
   'Jika perlu, buat pembayaran pengganti dengan nominal/metode yang benar. Periksa kembali piutang dan kas pada tanggal terkait.'),
 N('Koreksi bukan refund', 'Koreksi membatalkan pencatatan yang salah. Aplikasi belum menyediakan alur refund uang nyata kepada pelanggan. Saat respons terputus, coba lagi dalam dialog yang sama lalu muat ulang untuk memastikan hasilnya.'))

section('Mencari order dan memakai filter', 'OWNER, ADMIN, DAN TEKNISI',
 S('Buka Order, pilih Harian, Bulanan, atau Tahunan, lalu pilih tanggal/bulan/tahun yang memuat nota.',
   'Isi Cari order dengan sebagian nama, WhatsApp, atau nomor nota; contoh Nadia, 0812, 24, atau #24.',
   'Gabungkan dengan filter pengerjaan dan pembayaran jika perlu. Hasil berasal dari seluruh halaman data dalam periode terpilih.',
   'Ketuk hasil untuk membuka detail. Gunakan daftar lanjutan bila hasil belum seluruhnya terlihat.'),
 H('Filter pengerjaan pada satu nota'),
 T(['Pilihan', 'Cara membaca'], [
  ['Masuk', 'Semua layanan terkait masih Masuk.'],
  ['Dikerjakan', 'Masih dalam proses atau kemajuan layanan bercampur dan belum seluruhnya selesai.'],
  ['Selesai', 'Seluruh layanan terkait Selesai/Diambil, dengan setidaknya satu Selesai.'],
  ['Diambil', 'Semua layanan terkait Diambil.'],
  ['Belum diambil', 'Masih ada layanan belum Diambil, termasuk yang masih Masuk/Dikerjakan.'],
 ], [0.23,0.77]),
 P('Filter pembayaran menyediakan Belum lunas, Belum bayar, DP, dan Lunas. Pencarian tidak membedakan huruf besar/kecil; variasi format nomor Indonesia dinormalisasi.'),
 H('Tampilan bulanan dan reset'),
 P('Tanpa pencarian/filter, tampilan Bulanan dapat mengelompokkan nota berdasarkan tanggal. Ketuk tanggal untuk daftar hari itu. Saat filter aktif, hasil langsung berupa nota yang cocok. Ikon silang menghapus teks saja; Reset pencarian & filter membersihkan keduanya.'),
 N('Pekerjaan saya dan PDF', 'Teknisi dapat memilih Pekerjaan saya atau melihat tim. Filter pengerjaan pribadi mengikuti layanan miliknya; pembayaran tetap seluruh nota. Unduh rekap PDF mengikuti periode dan pilihan pekerjaan, bukan teks pencarian/filter status di layar.'))

section('Estimasi selesai dan prioritas pekerjaan', 'OWNER, ADMIN, DAN TEKNISI',
 P('Estimasi membantu menemukan pekerjaan yang harus segera diselesaikan. Nilainya satu tanggal untuk seluruh nota, bersifat opsional, dan ditampilkan pada kartu, detail, serta nota pelanggan.'),
 S('Pada Tambah/Edit order, tekan Pilih estimasi selesai.',
   'Pilih tanggal yang sama atau sesudah tanggal masuk. Jika belum ada target, biarkan kosong.',
   'Simpan order. Jika tanggal order diubah melewati estimasi, pilih target baru atau Hapus estimasi.'),
 H('Daftar Prioritas pengerjaan'),
 P('Buka tombol Prioritas pengerjaan pada Ringkasan atau Beranda. Daftar ini memeriksa pekerjaan belum selesai dari seluruh tanggal, termasuk nota bulan/tahun sebelumnya; tidak mengikuti periode rekap yang sedang dipilih.'),
 T(['Filter', 'Isi daftar'], [
  ['Semua', 'Seluruh pekerjaan belum selesai; estimasi terdekat lebih dulu, tanpa estimasi di bawah.'],
  ['Terlambat', 'Masih Masuk/Dikerjakan dan estimasi sebelum hari ini.'],
  ['Hari ini', 'Estimasi tepat hari ini dalam WIB.'],
  ['Mendatang', 'Estimasi setelah hari ini.'],
  ['Tanpa estimasi', 'Belum selesai dan belum memiliki target tanggal.'],
 ], [0.23,0.77]),
 P('Teknisi awalnya melihat Pekerjaan saya; matikan untuk melihat tim. Buka detail atau label Pengerjaan/Pembayaran dari daftar. Gunakan Muat lebih banyak untuk nota berikutnya.'),
 N('Contoh batas tanggal', 'Estimasi 25 Oktober tetap Hari ini sampai akhir 25 Oktober WIB. Pada 26 Oktober menjadi Terlambat jika masih Masuk/Dikerjakan. Layanan Selesai/Diambil tidak dianggap terlambat. Belum ada notifikasi otomatis ke HP atau WhatsApp.'))

section('Nota pelanggan dan WhatsApp', 'OWNER, ADMIN, DAN TEKNISI',
 S('Pilih Simpan & buat nota di form, atau buka Detail order > Nota pelanggan.',
   'Periksa nama, layanan, jumlah, diskon, nilai tagihan, pembayaran aktif, sisa, dan status lunas.',
   'Di bawah NOTA ORDER, periksa Tanggal masuk sepatu dan Estimasi selesai. Estimasi yang kosong tertulis Belum ditentukan.',
   'Tekan Unduh gambar, pilih folder penyimpanan, lalu simpan. Nota panjang dibagi beberapa bagian; pilih bagian dengan panah untuk mengunduhnya.',
   'Untuk kirim, periksa Nomor WhatsApp tujuan lalu tekan Bagikan ke WhatsApp. Jika tersedia dua aplikasi, pilih WhatsApp atau WhatsApp Business.',
   'Periksa penerima dan seluruh gambar di WhatsApp, kemudian tekan kirim di WhatsApp.'),
 H('Isi yang aman untuk pelanggan'),
 P('Nota pelanggan saat ini menggunakan gambar PNG. Ongkos/upah, identitas teknisi, foto barang, dan catatan internal tidak ditampilkan. Rincian tanggal tetap muncul pada setiap bagian nota. Nama/nomor tujuan pengiriman tidak mengubah data order jika hanya diedit di layar kirim.'),
 H('Jika penerima tidak otomatis dipilih'),
 P('WhatsApp dapat tetap membuka pemilih penerima. Pilih pelanggan yang sesuai dengan nomor tujuan. Tombol Buka chat pelanggan hanya membuka percakapan; unduh nota dan lampirkan manual jika diperlukan. Membuka WhatsApp belum berarti nota sudah terkirim.'),
 N('Nota setelah DP/pelunasan', 'Buka kembali nota untuk mengambil pembayaran terbaru. Jika pembuatan nota gagal setelah order tersimpan, gunakan Coba buat nota lagi. Tombol ini mengulang pembuatan gambar, bukan membuat order/pembayaran baru.'),
 N('Unduh dan berbagi', 'Unduh tetap bisa dipakai bila nomor WA kosong atau WhatsApp belum terpasang. Berbagi langsung tersedia di Android. Nota yang tersimpan di HP merupakan salinan pada waktu dibuat; buat ulang setelah data berubah.'))

section('Rekap PDF dan arti tanggal laporan', 'REKAP: SEMUA PERAN / ONGKOS: OWNER DAN TEKNISI',
 H('Mengunduh rekap order'),
 S('Buka Order, pilih periode Harian/Bulanan/Tahunan beserta tanggalnya.',
   'Teknisi memeriksa pilihan Pekerjaan saya atau tim, lalu menekan Unduh rekap PDF.',
   'Periksa pratinjau. Gunakan Unduh PDF untuk menyimpan, Bagikan PDF untuk memilih aplikasi/penerima, atau Cetak melalui layanan cetak Android.'),
 P('Rekap mengambil seluruh nota dalam periode, bukan hanya halaman yang terlihat. Laporan admin tidak memiliki kolom/ringkasan ongkos. Rekap owner/teknisi memuat ongkos dan nilai order setelah ongkos. Untuk ongkos satu teknisi saja, gunakan rincian pegawai pada tab Ongkos.'),
 T(['Tampilan', 'Tanggal yang menjadi dasar'], [
  ['Order, rekap PDF order, hak ongkos, peringkat pelanggan', 'Tanggal masuk nota.'],
  ['Ringkasan owner/teknisi', 'Nota yang masuk bulan berjalan; pembayaran aktif pada nota tersebut.'],
  ['Kas harian dan penerimaan pada Laporan admin', 'Tanggal pembayaran diterima. Bisa berasal dari nota lama.'],
  ['Pembayaran ongkos', 'Hak mengikuti tanggal nota; riwayat menyebut waktu upah benar-benar dibayar.'],
  ['Pengeluaran / absensi', 'Tanggal biaya dibayar / tanggal masuk absensi WIB.'],
 ], [0.45,0.55]),
 N('Perbedaan angka bisa benar', 'Nota masuk September dilunasi Oktober: tetap menjadi nota September, tetapi penerimaannya masuk Oktober. Piutang yang ditampilkan memakai pembayaran aktif terbaru, termasuk pelunasan setelah periode laporan; bukan saldo historis yang dikunci pada akhir bulan.'),
 P('PDF tidak mengikuti teks pencarian/filter status. Pilihan Pekerjaan saya pada rekap memilih nota yang memuat tugas teknisi; tagihan/pembayaran dan ongkos rekap nota itu tetap seluruh layanan nota.'))

section('Top 5 pelanggan dan riwayat kunjungan', 'RINGKASAN OWNER DAN TEKNISI',
 P('Kartu Top 5 pelanggan menampilkan pelanggan yang paling sering datang dalam rentang tanggal pilihan. Fitur ini membantu owner mengenali pelanggan rutin tanpa menambah tab bawah.'),
 S('Buka Ringkasan, gulir ke Top 5 pelanggan.',
   'Ketuk tombol kalender/rentang tanggal, pilih tanggal mulai dan akhir, lalu Terapkan. Kedua tanggal ikut dihitung.',
   'Baca lima pelanggan teratas beserta jumlah kunjungannya. Gunakan Lihat semua pelanggan untuk daftar peringkat lengkap.',
   'Ketuk nama pelanggan untuk melihat daftar nota pada periode yang sama: tanggal, layanan, dan nilai transaksi.',
   'Ketuk nota untuk membuka detailnya jika ingin menelusuri pembayaran atau pengerjaan.'),
 H('Aturan hitung'),
 B('**1 nota = 1 kunjungan.** Satu nota berisi lima pasang sepatu dan beberapa layanan tetap dihitung satu kunjungan.',
   'Nomor WA/telepon menjadi identitas utama. Nama yang berbeda penulisan tetapi bernomor sama digabung.',
   'Jika nomor kosong, identitas memakai nama yang dinormalisasi. Nama sama dengan nomor berbeda tetap pelanggan berbeda.',
   'Jika kunjungan sama banyak, kunjungan paling baru diprioritaskan. Nama yang ditampilkan berasal dari nota terbaru dalam kelompok/periode.',
   'Nota yang dihapus tidak ikut peringkat. Total transaksi adalah nilai tagihan nota, bukan semata uang yang sudah diterima.'),
 N('Pelanggan lama dan pelanggan tanpa nomor', 'Memilih saran pelanggan saat input membuat penulisan lebih konsisten. Menambahkan nomor baru tidak otomatis menggabungkan riwayat lama yang hanya beridentitas nama. Periksa data lama jika pelanggan terlihat terpisah.'),
 P('Mengubah periode Top 5 tidak mengubah Ringkasan bulan berjalan atau tanggal Kas harian. Muat ulang setelah perubahan nota untuk memperbarui peringkat.'))

section('Laporan operasional admin', 'ADMIN',
 P('Tab Laporan merangkum operasional pelanggan tanpa menampilkan ongkos atau biaya Internal. Pilih Harian, Bulanan, atau Tahunan, lalu tentukan tanggal periode.'),
 T(['Bagian', 'Fungsinya'], [
  ['Nota masuk', 'Jumlah nota berdasarkan tanggal masuk pada periode pilihan.'],
  ['Nilai sebelum diskon, diskon, omzet nota', 'Nilai layanan kotor, pengurang tagihan, dan tagihan setelah diskon.'],
  ['Sisa tagihan periode ini', 'Sisa terbaru pada nota yang masuk dalam periode pilihan.'],
  ['Piutang semua tanggal', 'Total sisa tagihan semua nota aktif, termasuk luar periode.'],
  ['Penerimaan pelanggan', 'Uang diterima pada periode pembayaran, dipisah Tunai, QRIS, dan Transfer.'],
  ['Status pengerjaan', 'Belum selesai, siap diambil, sudah diambil, dan pekerjaan terlambat dari nota periode itu.'],
 ], [0.38,0.62]),
 H('Menelusuri pembayaran'),
 S('Gulir ke daftar penerimaan. Periksa nama, nomor nota, nominal, metode, waktu pembayaran, dan operator.',
   'Ketuk pembayaran untuk membuka nota asal. Gunakan Muat pembayaran lainnya untuk halaman berikutnya.',
   'Ketuk Lihat nota masuk periode ini jika ingin membuka tab Order pada periode yang sama. Pencarian/filter sebelumnya dikosongkan.',
   'Gunakan Kas harian untuk pencocokan laci atau Unduh rekap PDF untuk rekap nota masuk tanpa ongkos.'),
 N('Cakupan terlambat', 'Angka terlambat pada Laporan/Beranda admin hanya untuk nota masuk di periode terpilih. Prioritas pengerjaan memeriksa semua tanggal. Gunakan menu prioritas untuk memastikan nota lama tidak terlewat.'),
 P('Status dan piutang menggambarkan keadaan terbaru ketika laporan dimuat. Pembayaran yang dikoreksi dan nota yang dihapus tidak masuk total aktif. Total laporan mencakup seluruh data walaupun rincian tampil bertahap.'))

section('Katalog layanan dan pengaturan tarif', 'LIHAT: SEMUA PERAN / UBAH: OWNER',
 P('Tab Layanan menyimpan daftar layanan, kategori, serta harga pelanggan per unit/pasang. Owner dan teknisi dapat melihat tarif ongkos sesuai aksesnya. Form order dan nota pelanggan tetap berfokus pada harga pelanggan.'),
 H('Mencari layanan'),
 S('Buka Layanan, ketik nama pada Cari layanan atau gunakan kategori yang tersedia.',
   'Periksa nama dan harga pelanggan sebelum memilih layanan pada order. Layanan nonaktif tidak ditawarkan untuk order baru.'),
 H('Menambah atau mengubah layanan oleh owner'),
 S('Pilih Tambah layanan, atau ketuk layanan yang akan diedit.',
   'Isi Nama layanan, Kategori, Harga pelanggan (rupiah), dan Ongkos kerja per unit (rupiah).',
   'Tentukan Layanan aktif. Matikan bila layanan tidak lagi dijual, lalu Simpan layanan.',
   'Muat ulang katalog di HP lain agar harga/pilihan terbaru terlihat.'),
 H('Harga lama pada order yang sudah masuk'),
 P('Order menyimpan salinan harga dan ongkos saat layanan ditambahkan. Mengubah master tidak otomatis mengganti nilai layanan lama. Edit status pada item lama mempertahankan salinannya; layanan baru yang ditambahkan memakai tarif master yang berlaku ketika disimpan.'),
 N('Pastikan tarif ongkos ditetapkan', 'Sebelum menjual layanan baru, owner menentukan harga pelanggan dan ongkosnya. Ongkos dikalikan jumlah unit untuk penanggung jawab layanan. Diskon pelanggan tidak mengurangi ongkos.'),
 P('Katalog awal berasal dari daftar harga usaha, tetapi tarif dapat berubah oleh owner. Gunakan angka pada aplikasi yang sudah dimuat ulang sebagai acuan operasional, bukan mengandalkan contoh harga di panduan ini.'))

section('Ongkos: hak upah dan rincian per nota', 'OWNER DAN TEKNISI',
 P('Tab Ongkos menampilkan hak upah layanan yang masuk pada periode pilihan. Hak tercatat sejak nota masuk, termasuk layanan yang belum selesai dan tagihan pelanggan yang belum dibayar.'),
 S('Buka Ongkos, pilih periode Harian/Bulanan/Tahunan serta tanggalnya.',
   'Ketuk Total ongkos tim untuk rincian seluruh penanggung jawab, atau ketuk nama pegawai pada Ongkos kerja tim.',
   'Teknisi dapat mengetuk Ongkos kerja saya untuk rincian pribadinya.',
   'Baca tabel per nota: No, Tanggal masuk, Nama customer/nomor nota, Jenis order, dan Total ongkos. Geser tabel ke samping jika kolom belum terlihat.',
   'Ketuk baris untuk membuka order. Pada rincian pegawai tertentu, gunakan Unduh rincian PDF atau Pembayaran ongkos.'),
 H('Dasar perhitungan'),
 P('Hak ongkos = tarif ongkos yang tersimpan pada layanan x jumlah unit/pasang, dialokasikan kepada pegawai penanggung jawab. Hanya layanan pegawai yang dipilih masuk rincian pribadinya. Jika satu nota memuat beberapa layanan milik orang yang sama, ongkosnya dijumlahkan per nota.'),
 N('Contoh', 'Dua Deep Clean dengan tarif ongkos contoh Rp10.000 per pasang menghasilkan hak Rp20.000. Jika satu layanan ODS dengan ongkos contoh Rp20.000 ditugaskan ke orang lain, masing-masing pegawai mendapat Rp20.000 dari nota yang sama.'),
 H('Tiga angka yang berbeda'),
 B('Hak ongkos: nilai upah yang timbul dari pekerjaan/nota.',
   'Dibayar: alokasi pembayaran ongkos yang sudah dicatat owner.',
   'Sisa: bagian hak yang belum dibayar. Buka Pembayaran ongkos untuk melihat saldo dan riwayatnya.'),
 N('Bukan bukti gaji lunas', 'PDF rincian ongkos merupakan laporan hak upah. Nilai order setelah ongkos juga belum merupakan laba bersih karena bahan, sewa, listrik, dan biaya lain belum dikurangi.'))

section('Mencatat pembayaran ongkos pegawai', 'CATAT/KOREKSI: OWNER / LIHAT: OWNER DAN TEKNISI',
 S('Buka Ongkos > Pembayaran ongkos. Pilih rentang tanggal nota melalui kalender.',
   'Ketuk pegawai untuk melihat Hak ongkos, Dibayar, Sisa, Kelebihan bila ada, serta saldo per nota.',
   'Owner membuka form bayar, mengisi nominal, metode Tunai/Transfer/QRIS, serta catatan opsional.',
   'Gunakan waktu saat ini untuk pembayaran baru; pembayaran lama dapat diisi tanggal/jam WIB yang sebenarnya. Waktu masa depan ditolak.',
   'Simpan lalu periksa riwayat dan alokasi. Nominal boleh sebagian, maksimal sisa pada periode terpilih.'),
 H('Pembayaran dialokasikan ke nota terlama'),
 P('Contoh: sisa nota A Rp20.000 dan B Rp30.000. Pembayaran Rp25.000 melunasi A dan membayar Rp5.000 pada B; sisa B menjadi Rp25.000. Alokasi mengikuti pegawai + nota, sehingga berganti periode tidak membuat nota yang sudah dibayar menjadi belum dibayar lagi.'),
 H('Koreksi salah catat'),
 P('Owner memilih Koreksi salah catat dan mengisi alasan minimal 5 karakter. Seluruh alokasi pada pembayaran itu dibatalkan, termasuk alokasi ke nota periode lain. Riwayat tetap ada dengan penanda Dikoreksi. Buat catatan baru jika diperlukan; koreksi bukan refund uang nyata.'),
 H('Jika hak berubah setelah dibayar'),
 P('Menghapus nota, mengurangi jumlah, atau mengganti penanggung jawab dapat menimbulkan kelebihan pembayaran. Aplikasi menampilkannya terpisah; tidak otomatis dipakai membayar nota lain. Owner meninjau kejadian dan mengoreksi pencatatan bila memang keliru.'),
 N('Hindari hitung ganda', 'Pembayaran ongkos tidak mengurangi tagihan pelanggan. Jika dibayar Tunai dari laci, masukkan sekali ke total Tunai keluar / disetor saat tutup kas. Jangan mencatat pembayaran yang sama lagi sebagai Pengeluaran usaha. Riwayat bayar memakai tanggal pembayaran, sedangkan periode hak mengikuti tanggal nota.'))

section('Kas harian dan tutup kas', 'OWNER DAN ADMIN',
 P('Buka Ringkasan/Beranda > Kas harian; admin juga dapat membuka dari Laporan. Pilih satu tanggal sampai hari ini. Daftar menghitung pembayaran yang diterima pada tanggal tersebut dalam WIB, termasuk pelunasan nota lama.'),
 S('Periksa penerimaan Tunai, QRIS, dan Transfer. Gunakan filter metode dan Tampilkan lagi untuk rincian. Ketuk pembayaran untuk membuka nota.',
   'Isi Saldo awal tunai: uang fisik di laci sebelum transaksi hari itu. Saldo ini diisi manual, tidak otomatis mengambil penutupan sebelumnya.',
   'Isi Tunai keluar / disetor: seluruh uang yang keluar dari laci, termasuk setoran, biaya yang dibayar dari laci, dan pembayaran ongkos tunai.',
   'Hitung uang fisik, lalu isi Uang tunai yang dihitung.',
   'Periksa selisih. Isi Catatan minimal 5 karakter jika ada selisih atau memperbarui penutupan, lalu simpan.'),
 T(['Rumus', 'Perhitungan'], [
  ['Tunai seharusnya', 'Saldo awal + penerimaan Tunai - tunai keluar/disetor.'],
  ['Selisih', 'Tunai dihitung - tunai seharusnya. Nol: Sesuai; negatif: Kurang; positif: Lebih.'],
 ], [0.28,0.72]),
 P('Contoh: saldo awal Rp100.000, penerimaan Tunai Rp300.000, keluar Rp80.000. Seharusnya Rp320.000. Jika uang dihitung Rp315.000, kas kurang Rp5.000. QRIS/Transfer tidak ditambahkan ke uang fisik laci.'),
 H('Penutupan pertama dan pembaruan'),
 P('Owner/admin dapat menyimpan penutupan pertama. Hanya owner memperbarui penutupan yang sudah ada. Pembaruan menyimpan catatan baru dan mempertahankan catatan sebelumnya.'),
 N('Perlu periksa ulang', 'Tutup kas tidak mengunci transaksi. Pembayaran, nota, ongkos Tunai, atau biaya dari laci yang berubah dapat memunculkan tanda ini. Muat ulang, cocokkan ulang uang fisik, lalu owner memperbarui catatan. Isian tunai keluar tetap manual dan dimasukkan satu kali.'))

section('Internal dan pengeluaran usaha', 'OWNER',
 P('Tab Internal memuat Absensi pegawai, Pengeluaran usaha, dan Kelola pegawai. Menu ini dipisahkan dari operasional pelanggan dan tidak tampil pada admin atau teknisi.'),
 H('Mencatat biaya yang sudah dibayar'),
 S('Buka Internal > Pengeluaran usaha > Catat pengeluaran.',
   'Pilih tanggal biaya benar-benar dibayar dalam WIB. Boleh tanggal lama; bukan masa depan.',
   'Isi keterangan, misalnya Beli cairan pembersih. Pilih kategori Bahan & peralatan, Listrik & air, Sewa, Transportasi, Perawatan, atau Lainnya.',
   'Isi nominal lebih dari nol, pilih Tunai/Transfer/QRIS, lalu catatan tambahan bila diperlukan.',
   'Jika Tunai, tentukan Diambil dari kas toko. Matikan bila memakai uang pribadi atau sumber lain di luar laci.',
   'Simpan. Periksa laporan pada periode biayanya; kalender rentang menghitung tanggal awal dan akhir.'),
 H('Laporan dan koreksi'),
 P('Total dan rincian kategori memakai seluruh catatan aktif. Riwayat memuat tanggal, nominal, metode/sumber tunai, operator, dan catatan. Gunakan daftar lanjutan untuk baris berikutnya. Koreksi salah catat memerlukan alasan minimal 5 karakter; catatan tetap ada sebagai Dikoreksi dan tidak menambah total. Buat pengganti jika perlu.'),
 N('Biaya, ongkos, dan setoran berbeda', 'Catat pembayaran ongkos pada Pembayaran ongkos. Setoran ke bank atau pengambilan pemilik masuk Tunai keluar / disetor bila keluar dari laci, bukan otomatis biaya operasional. Biaya Tunai dari laci masuk sekali ke total tunai keluar saat tutup kas.'),
 P('Pengeluaran belum digabung menjadi laporan laba bersih otomatis. Fitur ini mencatat biaya yang sudah dibayar; belum mencakup utang biaya, pengingat berulang, foto bukti pengeluaran, atau ekspor laporan biaya.'))

section('Mengelola dan menghapus akun pegawai', 'OWNER',
 H('Mengubah akses atau menonaktifkan sementara'),
 S('Buka Internal > Kelola pegawai, periksa nama serta status akun.',
   'Ketuk Atur akses pada akun lain. Pilih teknisi, admin, owner, atau Nonaktifkan sesuai kebutuhan.',
   'Pegawai memeriksa status atau keluar/masuk kembali setelah perubahan peran.'),
 P('Pilih Nonaktifkan jika pegawai hanya perlu dihentikan aksesnya sementara dan mungkin diaktifkan lagi. Owner tidak mengubah perannya sendiri dari menu ini.'),
 H('Menghapus akun secara permanen'),
 S('Pada akun non-owner, pilih Atur akses > Hapus akun pegawai.',
   'Periksa nama sasaran dan isi alasan 5-500 karakter.',
   'Konfirmasi Hapus akun. Tunggu hingga aplikasi mengonfirmasi hasil dan memuat ulang daftar.'),
 P('Akun sendiri dan akun berperan owner dilindungi dari penghapusan lewat menu pegawai. Setelah selesai, login tidak dapat dipulihkan melalui Atur akses dan akun hilang dari daftar pengelolaan. Riwayat nota, penanggung jawab layanan, foto, pembayaran, ongkos, dan absensi tetap tersimpan.'),
 H('Jika penghapusan belum selesai'),
 P('Akses aplikasi dicabut lebih dahulu. Jika penghapusan login terputus, baris dapat bertuliskan Penghapusan belum selesai. Ketuk ikon ulang dengan keterangan Selesaikan penghapusan pada akun yang sama. Jangan membuat perubahan peran untuk mengaktifkan kembali akun yang sudah ditandai dihapus.'),
 N('Bergabung kembali', 'Daftarkan akun baru jika orang yang sama kembali bekerja. Riwayat akun lama tidak otomatis dipindahkan. Hak ongkos lama tetap dapat diperiksa dan dibayar owner.'),
 P('Penghapusan login memerlukan migrasi 013 dan fungsi server delete-employee-account yang aktif. Petunjuk aktivasi tersedia pada lampiran pengelola.'))

section('Absensi: masuk, pulang, izin, dan sakit', 'ABSENSI SENDIRI: SEMUA AKUN AKTIF / REKAP TIM: OWNER',
 P('Admin/teknisi membuka ikon Absensi saya pada bagian atas halaman utama. Owner membuka Internal > Absensi pegawai; kartu teratas adalah absensinya sendiri.'),
 S('Saat mulai bekerja, ketuk Absen masuk lalu Simpan absensi. Jam/tanggal otomatis dicatat server dalam WIB.',
   'Saat selesai, ketuk Absen pulang dan konfirmasi.',
   'Jika tidak masuk, pilih Catat izin atau Catat sakit, isi keterangan minimal 5 karakter, lalu simpan untuk hari ini.',
   'Gunakan kalender untuk riwayat sendiri. Owner dapat memfilter pegawai dan melihat total hadir, izin, sakit, durasi, serta catatan belum pulang.'),
 H('Koreksi oleh owner'),
 P('Ketuk Koreksi pada baris yang sudah ada. Untuk hari tanpa catatan, gunakan Isi / koreksi absensi lalu pilih pegawai aktif dan tanggal. Isi alasan minimal 5 karakter. Hadir memerlukan jam masuk; jam pulang boleh kosong. Izin/Sakit memerlukan keterangan dan tidak menyimpan jam masuk/pulang. Riwayat perubahan menampilkan aktor, waktu, data sebelum/sesudah, dan alasan.'),
 H('Aturan perhitungan'),
 B('Satu catatan per pegawai per tanggal masuk WIB. Periode kalender inklusif, maksimal 366 hari.',
   'Pulang melewati tengah malam tetap mengikuti catatan masuk sebelumnya. Selesaikan catatan terbuka sebelum masuk lagi.',
   'Setelah lebih dari 48 jam belum pulang, minta owner mengoreksi jam pulang yang sebenarnya. Waktu koreksi tidak boleh masa depan.',
   'Durasi hanya dari catatan sudah pulang, dibulatkan ke bawah per menit. Tidak ada pemotongan istirahat atau hitung lembur otomatis.'),
 N('Cakupan tahap ini', 'Izin/sakit dicatat langsung tanpa persetujuan. Belum ada jadwal shift, penanda terlambat/alpa, GPS, atau selfie. Hari tanpa catatan tidak otomatis dianggap tidak hadir. Absensi tidak mengubah hak ongkos; pegawai/admin hanya melihat absensinya sendiri.'))

section('Menghapus nota dan menangani salah catat', 'OWNER',
 H('Hapus satu order'),
 S('Temukan nota yang benar di daftar atau Detail order.',
   'Ketuk ikon tempat sampah atau Hapus order.',
   'Periksa pelanggan/nomor nota yang ditampilkan, lalu pilih Ya untuk menghapus atau Tidak untuk membatalkan.'),
 H('Hapus seluruh order satu tanggal'),
 S('Buka Order > Bulanan, pilih bulan dan tanggal yang benar.',
   'Gunakan ikon hapus di sebelah tanggal atau buka tanggal lalu Hapus semua order tanggal ini.',
   'Periksa tanggal WIB dan jumlah nota dalam konfirmasi. Pilih Ya hanya jika seluruh catatan hari itu memang harus dihapus.'),
 P('Penghapusan per tanggal mencakup seluruh halaman pada hari itu, bukan hanya nota di layar. Tombol hapus semua disembunyikan saat filter aktif. Hapus satu nota tetap tersedia bagi owner.'),
 H('Dampak ke laporan'),
 P('Nota belum dibayar, DP, maupun lunas dapat dihapus. Pencatatan pembayaran aktifnya otomatis dibatalkan. Nota, pembayaran, piutang, hak ongkos, dan kunjungan pelanggan dikeluarkan dari perhitungan aktif. Riwayat dan jejak audit tetap disimpan; penghapusan tidak mengembalikan uang pelanggan.'),
 N('Periksa ongkos yang sudah dibayar', 'Jika hak pada nota itu sudah dibayar ke pegawai, pembayaran ongkos tetap memiliki riwayat dan dapat menjadi kelebihan. Owner meninjau saldo pada Pembayaran ongkos; aplikasi tidak otomatis mengalihkan pembayaran lama ke nota lain.'),
 N('Jika proses berhenti', 'Perhatikan jumlah nota yang sudah terkonfirmasi dihapus. Tutup dialog, muat ulang, dan periksa data terbaru sebelum mengulang. Tidak ada tombol pemulihan nota terhapus pada antarmuka saat ini.'),
 P('Gunakan Edit order untuk kesalahan data yang masih bisa diperbaiki. Untuk nominal/metode pembayaran salah, gunakan Koreksi pembayaran dengan alasan. Jangan memakai penghapusan untuk menyamarkan transaksi nyata.'))

section('Contoh satu transaksi dari awal sampai akhir', 'CONTOH LATIHAN DENGAN TARIF ILUSTRASI',
 P('Pelanggan membawa dua pasang untuk Deep Clean dan satu pasang untuk One Day Service (ODS). Tanggal masuk 23 Oktober, estimasi 25 Oktober. Tarif di bawah hanya contoh; periksa tarif master usaha sebelum input.'),
 T(['Layanan', 'Tagihan pelanggan', 'Hak ongkos'], [
  ['2 Deep Clean - Teknisi A', '2 x Rp30.000 = Rp60.000', '2 x Rp10.000 = Rp20.000'],
  ['1 ODS - Teknisi B', '1 x Rp50.000 = Rp50.000', '1 x Rp20.000 = Rp20.000'],
  ['Jumlah sebelum diskon', 'Rp110.000', 'Rp40.000'],
  ['Diskon pelanggan', 'Rp10.000', 'Tidak mengurangi ongkos'],
  ['Tagihan setelah diskon', 'Rp100.000', 'Hak tetap Rp40.000'],
 ], [0.36,0.34,0.30]),
 S('Buat order, pilih pelanggan/WA, tanggal masuk dan estimasi. Masukkan dua layanan beserta jumlah dan penanggung jawab yang benar.',
   'Isi diskon Rp10.000. Karena pelanggan baru membayar DP Rp30.000, pilih Belum lunas pada form awal lalu simpan.',
   'Pada detail, Tambah pembayaran Rp30.000 Tunai. Nota menjadi DP dan sisa Rp70.000. Kirim nota bila diperlukan.',
   'Saat dikerjakan, ubah status tiap layanan menjadi Dikerjakan, lalu Selesai setelah benar-benar selesai.',
   'Pada 25 Oktober pelanggan membayar Rp70.000 via QRIS. Catat pembayaran susulan, periksa sisa Rp0, ubah menjadi Diambil saat barang diserahkan, lalu buat nota terbaru.'),
 N('Membaca hasil', 'Satu nota ini dihitung satu kunjungan. Hak ongkos A Rp20.000 dan B Rp20.000 diakui pada 23 Oktober. Kas 23 Oktober menerima Tunai Rp30.000; kas 25 Oktober menerima QRIS Rp70.000. Lunas pelanggan belum berarti ongkos pegawai sudah dibayar.'),
 P('Nilai order setelah ongkos adalah Rp100.000 - Rp40.000 = Rp60.000. Angka itu belum laba bersih karena biaya operasional lain belum dikurangi.'))

section('Rutinitas yang disarankan untuk tim', 'PANDUAN KERJA HARIAN',
 H('Admin / penerima pelanggan'),
 B('Mulai: login akun sendiri, muat ulang, absen masuk, dan periksa Prioritas pengerjaan.',
   'Saat menerima barang: cari pelanggan lama dahulu, pastikan WA, jumlah, kondisi barang, pegawai penanggung jawab, dan estimasi.',
   'Saat menerima uang: catat tepat satu kali dengan metode yang benar. Untuk DP, gunakan Tambah pembayaran setelah order tersimpan.',
   'Saat serah barang: cek layanan sudah selesai, sisa pembayaran, status Diambil, lalu kirim nota terbaru.',
   'Akhir hari: hitung uang fisik dan simpan tutup kas pertama sesuai kewenangan; catat absen pulang.'),
 H('Teknisi'),
 B('Absen masuk, lihat Prioritas pengerjaan > Pekerjaan saya, dan baca catatan kondisi/pengerjaan.',
   'Ubah status layanan milik sendiri sesuai progres. Jangan menandai seluruh nota selesai bila layanan pegawai lain belum selesai.',
   'Periksa estimasi, koordinasikan target yang terlambat, dan tambahkan foto yang diperlukan.',
   'Baca rincian hak ongkos serta riwayat pembayarannya. Catat absen pulang setelah selesai kerja.'),
 H('Owner'),
 B('Periksa piutang, pekerjaan terlambat, aktivasi akun baru, dan catatan absensi yang perlu koreksi.',
   'Tinjau biaya yang benar-benar dibayar serta pembayaran ongkos. Hindari mencatat satu pengeluaran dua kali.',
   'Periksa selisih kas/tanda Perlu periksa ulang; perbarui tutup kas dengan catatan bila diperlukan.',
   'Pada akhir periode, unduh rekap order dan rincian ongkos. Tinjau pelanggan rutin pada rentang tanggal yang diinginkan.'),
 N('Saat pergantian petugas', 'Pastikan transaksi terakhir sudah tersimpan dan akun yang dipakai sesuai petugas. Setelah membuka data dari HP lain, muat ulang sebelum menambah pembayaran atau mengoreksi.'))

section('Mengatasi pesan dan kendala umum', 'SEMUA PENGGUNA / PENGELOLA SESUAI KASUS',
 T(['Gejala / pesan', 'Tindakan'], [
  ['Akun menunggu aktivasi / nonaktif', 'Minta owner memeriksa Internal > Kelola pegawai. Tekan Periksa status atau masuk kembali setelah akses diberikan.'],
  ['email rate limit exceeded', 'Pengiriman email Auth dibatasi. Hindari menekan daftar berulang; minta pengelola memeriksa pengaturan email/SMTP atau konfirmasi email.'],
  ['Data / rincian belum bisa dimuat', 'Periksa internet, tekan Coba lagi atau muat ulang. Periksa peran dan periode yang dipilih.'],
  ['Order/absensi berubah di HP lain', 'Muat ulang, baca data terbaru, baru ulangi perubahan. Jangan menimpa memakai data lama.'],
  ['Penyimpanan belum lengkap', 'Lanjutkan di form yang sama atau buka detail yang sudah tersimpan. Pastikan apakah order, pembayaran, atau foto yang belum selesai.'],
  ['Saran pelanggan tidak muncul', 'Ketik minimal dua karakter. Coba lagi atau isi manual; cek nomor jika pelanggan terpisah.'],
  ['Nota sudah tersimpan, gambar gagal', 'Gunakan Coba buat nota lagi atau buka Nota pelanggan dari detail; jangan membuat order baru.'],
  ['WhatsApp tidak membuka pelanggan', 'Pilih penerima manual atau gunakan Buka chat pelanggan dan lampirkan PNG hasil unduhan.'],
  ['Foto ditolak / gagal dimuat', 'Pilih foto <=2 MB berformat JPG/PNG/WebP. Buka ulang detail untuk memperbarui akses foto.'],
  ['Absensi sebelumnya belum pulang', 'Selesaikan absen pulang; lebih dari 48 jam minta owner mengoreksi waktu sebenarnya.'],
  ['Fitur belum aktif / nama file SQL', 'Minta pengelola menerapkan migrasi yang disebut dan memastikan APK terbaru dipakai.'],
  ['Deploy fungsi delete-employee-account', 'Pengelola memeriksa nama fungsi, deployment pada proyek yang sama, serta migrasi 013.'],
 ], [0.34,0.66]),
 N('Koneksi terputus saat menyimpan', 'Jika hasil belum pasti, gunakan tombol coba lagi pada form yang sama. Setelah form ditutup, periksa riwayat terbaru sebelum membuat catatan pengganti.'))

section('Istilah dan batas fitur saat ini', 'ACUAN SAAT MEMBACA LAPORAN',
 T(['Istilah', 'Makna dalam aplikasi'], [
  ['Nota / order', 'Satu transaksi pelanggan; bisa berisi beberapa layanan dan jumlah unit.'],
  ['Omzet nota', 'Tagihan setelah diskon, termasuk bagian yang belum dibayar.'],
  ['Penerimaan', 'Pembayaran pelanggan yang sudah dicatat aktif. Bukan nilai semua tagihan.'],
  ['Piutang / sisa tagihan', 'Bagian tagihan yang belum tertutup pembayaran aktif terbaru.'],
  ['Hak ongkos', 'Ongkos layanan x jumlah unit untuk penanggung jawab, berdasarkan tanggal nota.'],
  ['Ongkos dibayar', 'Pembayaran upah yang dicatat owner dan dialokasikan ke nota.'],
  ['Nilai setelah ongkos', 'Omzet nota dikurangi hak ongkos; belum laba bersih.'],
  ['Audit', 'Jejak pelaku/perubahan; riwayat umum tersedia untuk owner melalui pengelola, riwayat absensi juga bisa dilihat dari aplikasinya.'],
 ], [0.26,0.74]),
 H('Fitur yang belum disertakan'),
 B('Antrean transaksi offline, pembaruan realtime otomatis, dan banyak outlet dalam satu alur usaha.',
   'Refund uang nyata, gaji pokok/bonus, atau laporan laba bersih otomatis gabungan biaya.',
   'Notifikasi otomatis tenggat ke HP/WhatsApp; cetak langsung ke printer Bluetooth khusus.',
   'Absensi dengan GPS/selfie, jadwal shift, alpa/terlambat, persetujuan izin, dan lembur otomatis.',
   'Impor/master pelanggan mandiri, penggabungan otomatis identitas nama menjadi nomor, dan hapus/ganti foto order melalui UI.'),
 N('Cetak dan pembaruan data', 'PDF dapat memakai dialog cetak Android bila layanan printer yang sesuai tersedia. Data di layar/PDF adalah kondisi saat dimuat/dibuat, bukan periode keuangan yang dikunci. Gunakan salinan ekspor untuk arsip dan buat ulang bila transaksi berubah.'))

section('Lampiran pengelola: kesiapan aplikasi', 'OWNER DAN PENGELOLA TEKNIS',
 P('Panduan ini mengikuti kode proyek Perona Kasir per 23 Oktober 2026, versi pubspec 0.1.5+6 dengan fitur hingga migrasi 014. Ketersediaan fitur di HP bergantung pada APK yang dipasang dan pembaruan backend proyek. Dokumen ini tidak mengonfirmasi bahwa semua pembaruan online telah diterapkan.'),
 T(['Pembaruan', 'Fitur yang diaktifkan'], [
  ['003', 'Peran admin/teknisi dan pembatasan data ongkos admin.'],
  ['004 - 006', 'Tanggal order manual, penghapusan order, dan status cepat.'],
  ['007 - 008', 'Kas harian/tutup kas dan pembayaran ongkos.'],
  ['009 - 011', 'Estimasi/prioritas, pengeluaran Internal, dan saran pelanggan lama.'],
  ['012', 'Laporan operasional admin.'],
  ['013 + fungsi server', 'Direktori/penandaan akun dan penghapusan login pegawai.'],
  ['014', 'Absensi pribadi, rekap tim, koreksi dan riwayat perubahan.'],
 ], [0.30,0.70]),
 H('Pemasangan dan perawatan'),
 B('Pastikan semua HP memakai proyek Supabase yang sama. Laptop pengembang tidak perlu menyala untuk memakai APK yang sudah dipasang; HP tetap memerlukan internet ke backend.',
   'Terapkan migrasi yang belum ada secara berurutan. Jangan mengulang schema awal 001 pada proyek yang sudah berjalan. Penghapusan akun juga memerlukan Edge Function delete-employee-account; absensi cukup migrasi SQL.',
   'Pembaruan APK menggunakan identitas paket dan signing key yang sama agar dapat dipasang sebagai update. Perubahan ikon/native memerlukan build ulang, bukan hot reload saja.',
   'Simpan signing key dan konfigurasi dengan aman, pantau kapasitas data/foto, dan siapkan pencadangan database serta file oleh pengelola.'),
 N('Sumber panduan', 'Disusun dari halaman aplikasi pada lib/, fungsi SQL 001-014, dan dokumentasi fitur pada docs/. Gambar pada halaman berikut berasal dari pengujian dengan data contoh; susunan layar dapat berbeda menurut peran, ukuran HP, dan pembaruan aplikasi.'))

section('Contoh layar: menerima dan mencari order', 'ILUSTRASI DENGAN DATA UJI',
 ('figures', [
  ('order-estimate.png', 'Data pelanggan dan estimasi', 'Periksa tanggal masuk serta target selesai sebelum menyimpan. Lihat langkah lengkap pada bagian Membuat order.'),
  ('order-search-results.png', 'Pencarian dan filter nota', 'Pilih periode, lalu gabungkan nama/nomor nota dengan filter pengerjaan atau pembayaran.'),
 ]),
 N('Gunakan data usaha sendiri', 'Nama, nominal, dan tanggal pada ilustrasi adalah contoh pengujian. Kolom dan fungsi dijelaskan pada bagian terkait; jangan menjadikan angka contoh sebagai tarif usaha.'))

section('Contoh layar: kas dan ongkos', 'ILUSTRASI DENGAN DATA UJI',
 ('figures', [
  ('cash-closing-form.png', 'Mencocokkan uang fisik', 'Isi saldo awal, total tunai keluar, dan uang yang dihitung. QRIS/Transfer tidak menambah uang laci.'),
  ('wage-payment-form.png', 'Mencatat ongkos yang dibayar', 'Owner mengisi pembayaran sebagian/lunas. Hak ongkos dan pembayaran pelanggan tetap catatan terpisah.'),
 ]),
 N('Satu pencatatan untuk setiap kejadian', 'Jika ongkos dibayar dari laci, masukkan sekali dalam total tunai keluar saat tutup kas. Jangan membuat biaya usaha kedua untuk pembayaran upah yang sama.'))

section('Contoh layar: pelanggan dan absensi', 'ILUSTRASI DENGAN DATA UJI',
 ('figures', [
  ('top-customers-summary.png', 'Top 5 pelanggan', 'Pilih rentang tanggal dan ketuk nama untuk menelusuri nota. Satu nota tetap satu kunjungan.'),
  ('attendance-self.png', 'Absensi pribadi', 'Jam masuk/pulang dicatat otomatis. Jika hari sebelumnya belum pulang, selesaikan catatan terbukanya dahulu.'),
 ]),
 N('Akses absensi', 'Admin/teknisi memakai ikon Absensi saya di bagian atas halaman utama. Owner membuka Internal > Absensi pegawai. Hanya owner membaca rekap tim dan melakukan koreksi.'))


def make_table(headers, rows, weights=None):
    weights = weights or [1/len(headers)] * len(headers)
    weights = [w/sum(weights) for w in weights]
    data = [[p(c,'th') for c in headers]] + [[p(c,'table') for c in row] for row in rows]
    table = Table(data, colWidths=[BODY_W*w for w in weights], repeatRows=1, hAlign='LEFT')
    table.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),PALE), ('VALIGN',(0,0),(-1,-1),'TOP'),
        ('LEFTPADDING',(0,0),(-1,-1),9), ('RIGHTPADDING',(0,0),(-1,-1),9),
        ('TOPPADDING',(0,0),(-1,-1),8), ('BOTTOMPADDING',(0,0),(-1,-1),8),
        ('LINEBELOW',(0,0),(-1,0),0.6,LINE),
        ('LINEBELOW',(0,1),(-1,-1),0.4,LINE),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#fafbf8')]),
    ]))
    return [table, Spacer(1,8)]

def note(title, text):
    cell = [p(title,'h2'), p(text,'small')]
    table = Table([[cell]], colWidths=[BODY_W])
    table.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),PALE), ('BOX',(0,0),(-1,-1),0.5,LINE),
        ('LEFTPADDING',(0,0),(-1,-1),12), ('RIGHTPADDING',(0,0),(-1,-1),12),
        ('TOPPADDING',(0,0),(-1,-1),2), ('BOTTOMPADDING',(0,0),(-1,-1),6),
    ]))
    return [Spacer(1,4),table,Spacer(1,8)]

def render_blocks(blocks):
    result=[]
    for block in blocks:
        kind=block[0]
        if kind=='p': result.append(p(block[1]))
        elif kind=='h': result.append(p(block[1],'h2'))
        elif kind in ('steps','bullets'):
            for n,text in enumerate(block[1],1):
                # A separate number column keeps wraps aligned and avoids symbol glyph dependencies.
                item=Table([[p(f'{n:02d}' if kind=='steps' else '-', 'th'),p(text)]], colWidths=[24,BODY_W-24])
                item.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),1),('BOTTOMPADDING',(0,0),(-1,-1),3)]))
                result.append(item)
            result.append(Spacer(1,4))
        elif kind=='table': result.extend(make_table(*block[1:]))
        elif kind=='note': result.extend(note(*block[1:]))
        elif kind=='figures':
            cells=[]
            for file,title,caption in block[1]:
                path=ROOT/'docs/ui'/file
                with PILImage.open(path) as im: iw,ih=im.size
                scale=min(228/iw,445/ih)
                cells.append([p(title,'h2'),Image(str(path),width=iw*scale,height=ih*scale,kind='direct'),p(caption,'caption')])
            images=Table([cells], colWidths=[BODY_W/2,BODY_W/2])
            images.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),12)]))
            result.append(images)
    return result


class GuideDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(str(filename),pagesize=A4,leftMargin=MARGIN,rightMargin=MARGIN,topMargin=56,bottomMargin=49,
                         title='Panduan Lengkap Penggunaan Perona Kasir',author='Perona Sepatu',subject='Panduan owner, admin, dan teknisi; fitur hingga migrasi 014')
        frame=Frame(MARGIN,49,BODY_W,HEIGHT-105,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)
        self.addPageTemplates(PageTemplate(id='guide',frames=[frame],onPage=self.decorate))
        self.locations={}
        self.current_title='Panduan penggunaan'
    def decorate(self,canvas,doc):
        if doc.page==1:
            canvas.setFillColor(BRAND); canvas.rect(0,0,13,HEIGHT,fill=1,stroke=0)
            return
        canvas.setStrokeColor(LINE);canvas.setLineWidth(.6)
        canvas.line(MARGIN,HEIGHT-34,WIDTH-MARGIN,HEIGHT-34)
        canvas.setFillColor(GREEN);canvas.setFont('RobotoBold',8)
        canvas.drawString(MARGIN,HEIGHT-25,'PERONA SEPATU  /  PANDUAN PENGGUNAAN')
        canvas.setFillColor(MUTED);canvas.setFont('Roboto',8)
        canvas.drawRightString(WIDTH-MARGIN,HEIGHT-25,'Edisi 23 Oktober 2026')
        canvas.line(MARGIN,35,WIDTH-MARGIN,35)
        canvas.drawString(MARGIN,22,'Owner  |  Admin  |  Teknisi')
        canvas.drawRightString(WIDTH-MARGIN,22,f'{doc.page:02d}')
    def afterFlowable(self, flowable):
        if hasattr(flowable,'chapter_id'):
            cid=flowable.chapter_id
            self.locations[cid]=self.page
            self.canv.bookmarkPage(cid)
            self.canv.addOutlineEntry(flowable.getPlainText(),cid,0,False)


def story(locations=None):
    items=[]
    logo=ROOT/'assets/perona-logo.png'
    with PILImage.open(logo) as im: lw,lh=im.size
    items += [Spacer(1,28),Image(str(logo),width=310,height=310*lh/lw,hAlign='LEFT'),Spacer(1,52)]
    items += [p('PANDUAN OPERASIONAL APLIKASI','eyebrow')]
    cover=ParagraphStyle('cover',parent=styles['title'],fontSize=40,leading=46,spaceAfter=20)
    items += [Paragraph('Semua fitur.<br/>Satu panduan.',cover),p('Perona Kasir','h2'),
              p('Panduan lengkap untuk owner, admin, dan teknisi. Dari menerima sepatu hingga menutup kas dan meninjau absensi.'),Spacer(1,22)]
    items += make_table(['PELANGGAN','OPERASIONAL','INTERNAL'],[
        ['Order, pembayaran, nota, dan riwayat kunjungan.','Layanan, status pengerjaan, estimasi, dan laporan.','Ongkos, biaya usaha, akun pegawai, dan absensi.']])
    items += [Spacer(1,25),p('Edisi 23 Oktober 2026  |  Android','eyebrow'),
              p('Sesuai kode versi 0.1.5+6 dan fitur sampai pembaruan 014. Gunakan APK serta backend yang mendukung fitur terkait.','small'),
              p('Contoh layar memakai data uji. Angka tarif pada contoh transaksi bukan pengganti tarif master usaha.','small'),PageBreak()]
    items += [p('PETA PANDUAN','eyebrow'),p('Daftar isi','title'),p('Mulai dari bagian yang sesuai tugas Anda. Nomor halaman dan judul di bawah dapat diketuk pada pembaca PDF yang mendukung tautan.','small')]
    toc=[]
    for i,chapter in enumerate(chapters,1):
        cid=f'chapter-{i}'
        page=(locations or {}).get(cid,i+2)
        label=f'<link href="#{cid}" color="#252a26">{i:02d}   {escape(chapter["title"])}</link>'
        toc.append([Paragraph(label,styles['toc']),p(f'{page:02d}','th')])
    table=Table(toc,colWidths=[BODY_W-28,28])
    table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),('LINEBELOW',(0,0),(-1,-1),.35,LINE)]))
    items += [table,PageBreak()]
    for i,chapter in enumerate(chapters,1):
        items.append(p(f'BAGIAN {i:02d}  /  {chapter["roles"]}','eyebrow'))
        title=p(chapter['title'],'title'); title.chapter_id=f'chapter-{i}'
        items.append(title)
        items.extend(render_blocks(chapter['blocks']))
        if i!=len(chapters): items.append(PageBreak())
    return items

first=GuideDoc(TMP/'guide-first-pass.pdf')
first.build(story())
final=GuideDoc(PDF)
final.build(story(first.locations))
assert first.locations==final.locations, 'TOC pagination changed between passes'
manifest={
    'pdf':str(PDF),'pages':final.page,'chapters':[
        {'number':i,'title':c['title'],'page':final.locations[f'chapter-{i}']}
        for i,c in enumerate(chapters,1)],
    'source_date':'2026-10-23','version':'0.1.5+6','latest_migration':'014',
}
(TMP/'guide_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
