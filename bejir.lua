--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║           SAMBUNG KATA PRO - REACTIVE v13.3                          ║
    ║           Auto-Interrupt (Bisa Batal Ngetik) + Auto-Correct Salah    ║
    ╚══════════════════════════════════════════════════════════════════════╝
]]

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    CoreGui = game:GetService("CoreGui"),
    RunService = game:GetService("RunService")
}

local LocalPlayer = Services.Players.LocalPlayer

local State = {
    IsRunning = true,
    AutoEnabled = false,
    AutoBlacklist = true,
    UsedWords = {},
    RejectedWords = {},
    Index = {},
    GlobalDict = {},
    ActiveTask = false,
    CurrentSoal = "",
    LastWordAttempted = "",
    LastSubmitTime = 0,
    LockedWord = "",
    LockedPrefix = "",
    TotalWordsFound = 0,
    TotalCorrect = 0,
    TotalErrors = 0,
    ConsecutiveErrors = 0,
    TypingDelayMin = 0.45,
    TypingDelayMax = 0.95,
    ThinkDelayMin = 0.8,
    ThinkDelayMax = 2.5,
    WordPreference = "balanced",
    PreferredLength = 0,
}


-- ═══════════════════════════════════════════════════════════════════════
-- 1. DATABASE KAMUS (KBBI 3+ Huruf)
-- ═══════════════════════════════════════════════════════════════════════
local RAW_KAMUS = {
    ["a"]={"abu","ada","adik","adil","adu","agar","agen","ahli","aib","air","aja","ajak","ajar","akal","akan","akar","akrab","aksi","aku","alah","alam","alas","alat","alis","alur","amal","aman","amat","ambil","ampuh","anak","anda","aneh","angin","angka","angsa","anjing","antar","antik","apa","apel","api","apik","arah","arak","arti","arus","asa","asal","asam","asap","asin","asing","asli","atap","atas","atau","atur","awak","awal","awan","awas","awet","ayah","ayam","ayat","ayo","azab"},
    ["b"]={"bab","babi","baca","badai","badak","badan","badut","bagai","bagi","bagus","bahas","bahu","baik","baja","bajak","baju","bakar","bakat","baku","bakso","balap","balas","balik","balok","balon","bambu","ban","banci","bandar","bangga","bangun","banjir","bantal","bantu","banyak","bapak","bara","barang","barat","baris","baru","basah","basi","batal","batas","batik","batin","batu","batuk","bau","bawa","bawah","bawang","bayam","bayar","bayi","bebas","bebek","beda","bedak","bekal","bekas","beku","bela","belah","belajar","beliau","belok","belum","benang","benar","bencana","benci","benda","bendera","benih","bening","bentuk","berani","beras","berat","beres","beri","berita","berkah","bersih","besar","besi","besok","betina","betis","betul","biar","biasa","biaya","bibir","bibit","bicara","bidang","bikin","bila","bilang","bina","binatang","bintang","biru","bisa","bisik","bising","bisu","bius","bocor","bodoh","bohong","bola","boleh","bolos","boneka","bosan","botak","botol","buah","buang","buas","buat","buaya","bubar","bubuk","bubur","budak","budaya","budi","bugil","bujang","bujuk","buka","bukan","bukit","bukti","buku","bulan","bulat","bulu","bumbu","bumi","bundar","bunga","buntut","bunuh","bunyi","buru","buruh","buruk","burung","busa","busana","busuk","busur","buta","butir","butuh"},
    ["c"]={"cabe","cabut","cacat","caci","cacing","cadang","cahaya","cair","cakap","cakar","cakep","calon","campur","canda","candi","cantik","capai","capek","cara","cari","cat","catat","cegah","cek","cekik","celana","celaka","cemas","cemburu","cepat","cerah","cerai","cerdas","cerdik","cerita","cermat","cermin","cetak","cincin","cinta","cipta","ciri","citra","cium","coba","cocok","cokelat","colek","colok","copot","coret","cuaca","cubit","cuci","cucu","cuka","cukup","cukur","cuma","cumi","curam","curang","curi","curiga","cuti"},
    ["d"]={"dada","dadu","daerah","daftar","daging","dagu","dahulu","daki","dalam","damai","danau","dandan","dapat","dapur","darah","darat","dari","dasar","data","datang","datar","daun","daya","dayung","debat","debu","dekat","delapan","demam","demi","denda","dendam","dengar","depan","deras","derita","desa","desain","desak","detail","detak","detik","dewa","dewasa","dewi","diam","didik","diet","dikit","dina","dinding","dingin","diri","diskon","doa","dobrak","domba","dompet","dorong","dosa","dosen","drama","dua","duduk","duet","duga","duit","duka","dukun","dukung","dulu","dungu","dunia","duri","durian","dusta","duta"},
    ["e"]={"ecer","edar","edisi","edit","efek","ego","egois","eja","ejek","ekor","ekspor","ekspresi","ekstra","elang","elok","elus","emas","ember","embun","emosi","empat","empuk","enak","enam","encer","endap","energi","enggan","engsel","entah","eram","erat","erti","esok","estetika","etika","eyang"},
    ["f"]={"fajar","fakir","fakta","faktor","fana","fanatik","farmasi","fase","fasih","fasilitas","fatal","fatwa","fauna","favorit","fenomena","fiksi","film","filsafat","filter","final","firasat","fisik","fitnah","flora","fokus","formal","format","foto","frekuensi","fungsi"},
    ["g"]={"gabung","gading","gadis","gaduh","gagah","gagak","gagal","gagang","gagap","gaib","gairah","gajah","gaji","galak","galang","galau","gali","galon","gambar","gampang","ganas","ganda","gandeng","gandum","gang","ganggu","ganja","ganjal","ganjil","ganteng","ganti","gantung","gapai","garam","garang","garansi","garis","garpu","garuda","garuk","gas","gatal","gaul","gaun","gawang","gawat","gaya","gayung","gejala","gelang","gelap","gelar","gelas","geli","gelisah","gelombang","gema","gemar","gemas","gembala","gembira","gembok","gempa","gempar","gemuk","genap","gendang","gendong","genggam","gengsi","genius","gentar","genting","gerak","geram","gerbang","gereja","gergaji","gerhana","gerimis","gesek","geser","gesit","getah","getar","giat","gigi","gigit","gila","gilir","gitar","gizi","global","goda","golok","golong","gombal","goreng","gores","gosip","gosok","gosong","gotong","goyang","gram","gratis","grup","gua","gubuk","gudang","gugat","gugup","gugur","gula","gulat","guling","gulung","gumam","guna","gundul","gunting","guntur","gunung","gurau","gurih","guru","guruh","gurun","gusar","gusi","gusur"},
    ["h"]={"habis","hadap","hadiah","hadir","hafal","hajar","haji","hak","hakim","hal","halal","halaman","halang","halus","hama","hamba","hambar","hambat","hamil","hampa","hampir","hancur","handuk","hangat","hantu","hanya","hanyut","hapus","haram","harap","harga","hari","harimau","harta","haru","harum","harus","hasil","hasrat","hati","haus","hawa","hebat","heboh","hewan","hibur","hidang","hidung","hidup","hijau","hikmah","hilang","himpun","hina","hindar","hingga","hirau","hiruk","hirup","hisap","hitam","hitung","hiu","hobi","hormat","hotel","hubung","hujan","hukum","hulu","humas","humor","huni","huruf","hutan","hutang"},
    ["i"]={"ia","ialah","iba","ibadah","ibarat","iblis","ibu","ideal","idola","ijin","ijazah","ikan","ikat","ikhlas","iklan","iklim","ikut","ilahi","ilham","ilmiah","ilmu","ilusi","imam","iman","imbang","imbas","indah","induk","infeksi","info","ingat","ingin","ingkar","ingus","ini","injak","insaf","insan","intan","inti","intip","intuisi","ipar","irama","iri","iring","iris","irit","isak","isap","isi","islam","istana","istilah","istri","isu","isyarat","itik","itu","iuran","izin"},
    ["j"]={"jabat","jadi","jadwal","jaga","jagung","jahat","jahe","jahil","jahit","jajan","jala","jalak","jalan","jalang","jalin","jalur","jam","jamak","jambu","jamin","jamu","jamur","janda","jangan","janggal","jangka","jangkar","jangkau","janji","jantan","jantung","jarak","jarang","jari","jaring","jarum","jas","jasa","jasad","jatuh","jauh","jawa","jawab","jaya","jebak","jebol","jeda","jejak","jelek","jeli","jelita","jemari","jempol","jemput","jenaka","jenazah","jendela","jenderal","jenis","jenius","jenuh","jepit","jera","jeram","jerat","jerih","jerit","jeruk","jihad","jijik","jika","jilat","jilid","jimat","jinak","jingga","jiplak","jitu","jiwa","jodoh","joget","jual","juang","juara","jubah","judi","judul","juga","jujur","jumat","jumlah","jumpa","juni","juru","juta","jutawan"},
    ["k"]={"kabar","kabel","kabur","kabut","kaca","kacang","kacau","kadal","kadang","kadar","kado","kafan","kafe","kafir","kaget","kagum","kaidah","kail","kain","kaisar","kait","kaji","kakak","kakek","kaki","kaku","kala","kalah","kalang","kalau","kaldu","kaleng","kali","kalian","kalimat","kalung","kalut","kamar","kambing","kamera","kami","kamis","kampung","kampus","kamu","kamus","kanan","kancing","kandas","kandang","kandung","kangen","kangkung","kanguru","kantin","kantong","kantor","kantuk","kaos","kapak","kapal","kapan","kapas","kapur","karam","karang","karat","kardus","karena","karet","karib","karir","karnaval","karpet","kartu","karya","kasar","kasih","kasir","kasur","kasus","kata","katak","kategori","katun","kaum","kaus","kawah","kawal","kawan","kawasan","kawat","kawin","kaya","kayu","kayuh","kebal","kebun","kecewa","kecil","kecoa","kecuali","kecup","kedai","kejam","kejang","kejar","keji","keju","kejut","kekal","kelak","kelam","kelapa","kelas","keliling","kelinci","keliru","kelok","kelompok","keluar","keluarga","keluh","kemah","kemarin","kemas","kembali","kembang","kembar","kemeja","kemih","kemis","kemudian","kena","kenal","kenang","kenapa","kencang","kencing","kendali","kendara","kendi","kendur","kental","kentang","kentara","kentut","kenyang","kepala","keping","kepiting","kepul","kepung","kera","kerabat","kerah","kerak","keramas","keran","keranjang","kerap","keras","kerbau","keren","kereta","kering","keringat","keris","keriting","kerja","kertas","kerudung","keruh","kesal","kesan","kesat","ketam","ketan","ketat","ketawa","ketek","ketel","ketemu","ketiak","ketik","ketimun","ketok","ketua","ketuk","ketupat","khawatir","khayal","khianat","khidmat","khilaf","khitan","khotbah","khusus","kiamat","kias","kiat","kibar","kibas","kiblat","kicau","kidal","kikir","kikis","kikuk","kilas","kilat","kilau","kilo","kimia","kini","kios","kipas","kira","kiri","kirim","kisah","kisi","kismis","kisruh","kita","kitab","klaim","klasik","klien","klik","klinik","klip","klub","knalpot","kobar","koboi","kocak","kocok","kode","kodok","koki","kokoh","kokok","kolam","koleksi","kolom","kolong","koloni","kolor","koma","komandan","komando","komedi","komentar","komik","komisi","komite","komodo","kompak","kompas","kompetisi","kompleks","komplit","kompor","kompres","kompromi","komputer","komunikasi","kondisi","konferensi","konflik","kongres","konon","konsep","konser","konsisten","konspirasi","konstruksi","konsul","konsultan","konsumen","konsumsi","kontak","kontan","konteks","konten","kontes","kontra","kontrak","kontras","kontrol","konyol","koperasi","kopi","kopiah","koper","koran","korban","korek","koreksi","kores","korupsi","kosakata","kosmetik","kosong","kostum","kota","kotak","kotor","koyak","kreatif","kredit","kriminal","krisis","kristal","kriteria","kritik","kritis","kuah","kuak","kuala","kuali","kualitas","kuantitas","kuap","kuas","kuasa","kuat","kubah","kubang","kubis","kubu","kubur","kucing","kuda","kudeta","kudis","kudung","kudus","kue","kuil","kuis","kujur","kuku","kukuh","kukus","kuli","kuliah","kulit","kultur","kuman","kumis","kumpul","kumuh","kumur","kunci","kuning","kunjung","kuno","kuntilanak","kupas","kuping","kupon","kupu","kurang","kurap","kuras","kurban","kurcaci","kurikulum","kurma","kursi","kursus","kurun","kurung","kurus","kusam","kusir","kusta","kusut","kutang","kutik","kutip","kutub","kutuk","kutu"},
    ["l"]={"laba","labu","laci","lada","ladang","lafal","laga","lagi","lagu","lahir","lain","laju","laki","lakon","laku","lalai","lalat","lalu","lama","laman","lamar","lambai","lamban","lambang","lambat","lambung","lampau","lampu","lancar","landak","landas","langit","langka","langkah","langsung","lanjut","lantai","lantas","lantik","lapang","lapar","lapis","lapor","larang","lari","laris","larut","latar","latih","lauk","laut","lawak","lawan","layak","layan","layang","layar","layu","lebah","lebar","lebaran","lebat","lebih","lebur","lecet","ledak","lega","legal","legenda","legit","leher","lekas","lekat","lelah","lelaki","lelang","lelap","lele","leleh","leluasa","lelucon","leluhur","lemah","lemak","lemari","lemas","lembah","lembar","lembing","lembu","lembur","lembut","lempar","lempeng","lemper","lempung","lena","lencana","lendir","lengan","lengkap","lengket","lengkung","lensa","lentera","lentik","lenyap","lepas","lepat","lepau","lepek","lepuh","lereng","leret","lesu","lesung","letak","letih","letnan","letup","letus","level","lewat","liar","libur","licik","licin","lidah","lihat","lilin","lilit","lima","limbah","limpah","lincah","lindung","lingkar","lingkung","lingkup","linglung","lintah","lintang","lintas","lipan","lipat","lirik","lisan","lisensi","listrik","liter","liur","loba","lobak","lobi","logam","logika","logis","lokal","lokasi","loket","lomba","lombok","lompat","loncat","lonceng","longgar","longsor","lonjak","lontar","lontong","lorong","loteng","lotre","lowong","loyal","luang","luap","luar","luas","lubang","luber","lubuk","lucu","lucut","ludah","ludes","lugu","luhur","luka","lukis","luku","luluh","luluk","lulus","lumas","lumat","lumpuh","lumpur","lumrah","lumur","lumut","lunak","lunas","luncur","lungguh","lunglai","lunta","luntang","luntur","lupa","lurah","lurik","luruh","lurus","lurut","lusa","lusin","lusuh","lutut","luwes"},
    ["m"]={"maaf","mabuk","macam","macan","macet","madu","mahal","mahasiswa","mahir","mahkota","main","maju","maka","makalah","makam","makan","maki","makin","maklum","makmur","makna","maksimal","maksud","malaikat","malam","malang","malas","maling","malu","mama","mampu","mana","manajemen","manajer","mandi","mandiri","manfaat","mangga","mangkuk","mangsa","manis","manja","mantan","mantap","mantel","mantra","manusia","marah","mari","markas","martabak","martabat","masa","masak","masalah","masam","masyarakat","masih","masjid","maskapai","masker","massa","masuk","mata","matahari","matang","matematika","materi","mati","matras","mau","maupun","maut","mawar","maya","mayat","mayor","medali","medan","media","medis","meditasi","mega","megah","megap","mei","meja","mekanik","mekanisme","mekar","melambai","melarat","melati","melayu","melek","meleset","melihat","melodi","melon","memang","memar","memori","menang","menantu","menara","mencak","mendung","menganga","mengerti","menilai","meninggal","menir","menit","menjadi","mentah","mental","mentari","mentas","mentega","menteri","mentok","menung","menu","menyan","meong","merah","merak","merana","merang","merdeka","merdu","mereka","merem","meriah","meriam","merica","meringis","merpati","mesin","mesra","mesti","mestika","mesum","metabolisme","metamorfosis","metafora","metode","metrik","mewah","mewakili","mewujudkan","mi","milik","mimpi","minat","mineral","minggat","minggir","minggu","minim","minimum","minor","minta","minum","minus","minyak","mirip","misal","misi","miskin","misteri","mistik","mitologi","mitra","mobil","mobilisasi","modal","modar","mode","model","modern","modernisasi","modifikasi","modis","modul","moga","mogok","mohon","mohor","molek","molekul","molor","momen","momok","monarki","mondar","monitor","monopoli","monyet","moral","moralitas","mosi","motif","motivasi","motor","muara","muat","muazam","muda","mudah","mufakat","muhibah","mujur","muka","mukadimah","mukena","mukim","mukjizat","mula","mulai","mulas","mulia","mulus","mulut","mumet","mumi","mumpung","munafik","munajat","muncrat","muncul","muncung","mundur","mungil","mungkar","mungkin","mungkir","muntah","murah","murni","murid","murka","murtad","musang","museum","musik","musim","muslihat","mustahil","mustajab","mustika","musuh","musyawarah","mutakhir","mutasi","mutiara","mutlak","mutu","muzakarah"},
    ["n"]={"nabi","nada","nadi","nafas","naga","nagih","nahas","nahkoda","naif","naik","najis","nakal","nalar","naluri","nama","nampak","namun","nanah","nanar","nanas","nanda","nangka","nanti","napas","napi","narkoba","narasi","narasumber","nasi","nasib","nasihat","nasional","naskah","natal","naung","navigasi","nazar","nebeng","negara","negatif","negeri","nego","negosiasi","nekad","nekat","nelayan","nelpon","nenek","neon","nepotisme","neraca","neraka","neto","netral","ngabuburit","nganga","ngantuk","ngawur","ngeri","ngomong","niaga","nian","niat","nihil","nikah","nikmat","nila","nilai","nilam","nilon","nina","ningrat","nipis","nira","nirwana","nisan","nisbi","niscaya","nista","nobat","noda","nol","nomaden","nominal","nominasi","nomor","non","nona","nongol","nonton","norak","norma","normal","not","nota","notaris","novel","nuansa","nubuat","nujum","nukil","nuklir","numerik","nunda","nurani","nusa","nusantara","nutfah","nutrisi","nyah","nyai","nyak","nyala","nyalang","nyali","nyaman","nyamuk","nyana","nyanyi","nyaring","nyaris","nyata","nyawa","nyelekit","nyenyak","nyeri","nyinyir","nyonya","nyuci"},
    ["o"]={"oase","obat","obeng","obesitas","objek","objektif","obligasi","obor","obral","obras","obrol","observasi","obsesi","obstetri","oceh","ocehan","odol","oditur","ofset","ogah","ogak","oknum","oksigen","oktober","olah","olahraga","oles","oli","olimpiade","olok","ombak","omel","omong","ompol","omset","onak","onani","onar","oncen","oncom","ondel","onderdil","ongkir","ongkos","ons","onta","onyok","opas","opelet","open","oper","operasi","operator","opini","opium","oplos","opor","opsi","optimal","optimis","optimum","orak","oral","orang","oranye","orbit","orde","order","ordinat","organ","organik","organisasi","orgel","orientasi","orisinal","orkes","orok","orong","ornamen","ortodoks","ortu","osilasi","osis","otak","otentik","otentikasi","otitis","oto","otobiografi","otodidak","otomasi","otomatis","otonom","otopsi","otoritas","otoriter","otot","oval","ovasi","oven","ovulasi","ovum","oyak","oyek","oyok","oyong","ozon"},
    ["p"]={"pabrik","pacar","pacu","pada","padahal","padam","padan","padang","padas","padat","padri","padu","paes","pagar","pagi","pagoda","pagut","paha","pahala","paham","pahat","pahit","pahlawan","paing","pajak","pajang","pakai","pakar","paket","pakis","paksa","paksi","paku","pala","palang","palestina","paling","palit","palsu","palu","paman","pamer","pamit","pamong","pampang","pampas","pampat","pamrih","panah","panas","panau","panca","panci","pancing","panco","pancong","pancung","pancur","pandai","pandak","pandan","pandang","pandir","pandu","panel","panen","pangan","panggang","panggil","panggul","panggung","pangkah","pangkas","pangkat","pangku","panglima","panik","panitia","panjang","panjar","panjat","panji","pantai","pantak","pantang","pantar","pantas","pantat","pantau","pantek","panti","pantik","pantis","pantul","pantun","papa","papah","papak","papan","papar","papas","papaya","para","parade","paraf","parah","parak","paralel","param","parang","parap","paras","parasit","parau","parfum","pari","parit","parkir","parlemen","parodi","paron","parsel","partai","partikel","partisipasi","paru","paruh","parun","parut","pasah","pasai","pasak","pasal","pasang","pasar","pasat","pasca","pasi","pasien","pasif","pasir","paspampres","paspor","pasta","pasti","pastur","pasukan","pasu","pasung","patah","paten","pater","pateri","pati","patih","patik","patriot","patroli","patuh","patuk","patung","patut","pauh","paus","paut","pawai","pawang","paya","payah","payang","payar","payau","payu","payung","peci","pecah","pecak","pecal","pecat","pecel","pecut","peda","pedagang","pedal","pedanda","pedang","pedar","pedas","pedati","pede","pedih","peduli","pegangan","pegawai","pejabat","pejam","peka","pekak","pekan","pekat","pekerti","pekik","pelangi","pelan","pelangi","pelat","pelaut","peledak","pelepas","pelita","pelopor","peluang","peluk","pelupa","pemalas","pemancing","pemanda","pemanah","pemarah","pemasaran","pembantu","pemburu","pemda","pemerintah","pemilihan","pemilu","pemuda","pemukul","pena","penalti","pencak","pencuri","pendeta","pendidikan","penerbangan","pengaruh","pengemis","penghuni","penjaga","penjara","penjelasan","pentas","penting","penuh","penulis","penumpang","penyakit","penyanyi","peot","pepaya","pepes","pepet","perabot","perahu","peran","perang","perangkat","perantara","peras","perasaan","perawat","perban","perbedaan","perbincangan","percaya","perdana","perempuan","pergi","perhiasan","perhitungan","peri","perihal","perikanan","perilaku","perintah","peristiwa","perjamuan","perjuangan","perkara","perkasa","perkawinan","perkebunan","perkembangan","perkiraan","perlahan","perlengkapan","perlu","perlumbaan","permainan","permata","permen","permintaan","pernah","pernikahan","perompak","peron","perpustakaan","pers","persahabatan","persamaan","persawahan","persegi","persen","persetan","persiapan","persilatan","persis","persneling","personil","perspektif","pertahanan","pertama","pertanian","pertanyaan","pertarungan","pertemuan","pertengkaran","pertimbangan","pertunangan","pertunjukan","perubahan","perumahan","perumpamaan","perusahaan","pesan","pesangon","pesawat","peserta","pesiar","pesona","pesta","pestisida","pesugihan","peta","petai","petak","petal","petam","petang","petani","petaram","petas","petasan","petek","peti","petik","petil","petir","petualang","petugas","petunjuk","pewarna","peyek","peyot","piala","pialang","piama","piara","pias","piawai","pica","picak","pici","picik","picis","picu","pidan","pidana","pidato","pigmen","pigura","pihak","pijah","pijak","pijar","pijat","pikat","pikau","piket","pikir","piknik","pikul","pikun","pilah","pilar","pilek","pilih","pilin","pilis","pilot","pilu","pimpin","pinang","pinar","pincang","pincuk","pindah","pinggang","pinggir","pinggul","pingsan","pinjal","pinjam","pintar","pintu","pinus","pion","pipa","pipi","piranti","pirau","piring","pisah","pisang","pisau","pita","piutang","pizza","plafon","plagiat","plakat","plan","planet","plastik","platinum","plato","plebisit","pleno","plester","plintir","plong","plontos","pluralisme","plus","poci","pocong","podium","pohon","pojok","pokat","pokok","pokrol","polah","polan","polang","polarisasi","polemik","poles","polet","poli","poligami","polisi","politik","polos","polutan","pomade","pompa","pondasi","pondok","pondong","pongah","poni","ponsel","ponten","pop","popok","popor","populasi","populer","porah","pori","porno","poros","porot","porsi","portabel","porter","posisi","positif","posko","posyandu","potensi","potong","potret","prabu","praduga","pragmatis","prakarsa","prakiraan","praktek","pramuka","pramuniaga","prasangka","prasmanan","prasyarat","predator","prediksi","preferensi","preman","premi","premis","presiden","presisi","prestasi","pretensi","pria","pribadi","pribumi","prihatin","prima","primadona","primbon","primitif","prinsip","prioritas","privasi","privat","proaktif","probabilitas","problema","produsen","produksi","produktif","profesional","profesor","profil","program","progresif","proyek","psikis","psikologi","pual","pualam","puan","puas","puasa","puber","publik","publikasi","pucat","pucuk","pudar","pudi","puding","puing","puisi","puitis","puja","pujangga","puji","pukang","pukat","pukau","pukul","pula","pulai","pulang","pulas","pulau","pule","puli","pulih","pulpen","puls","pulu","puluh","pulun","pulung","pulut","pumpun","punah","punai","punak","punca","puncak","pundak","pundi","punggah","pungguk","punggung","pungli","pungut","puntal","puntir","punya","pupil","pupuh","pupuk","pupus","puput","pura","purba","purnama","purnawirawan","puru","puruk","pusaka","pusar","pusat","pusing","puso","pustaka","pustakawan","pusung","pusuk","putar","putat","putera","putih","putik","puting","putra","putri","putu","putus","puyuh"},
    ["q"]={"qari","qasidah","qiamullail"},
    ["r"]={"raba","rabat","rabies","rabu","rabun","rada","radang","radiasi","radikal","radio","radium","radius","radon","rafia","raga","ragam","ragu","rahang","rahasia","rahayu","rahib","rahim","rahman","rahmat","raib","raih","rais","raja","rajah","rajam","rajawali","rajin","rajuk","rajut","rakaat","rakasa","raket","rakit","raksa","raksasa","raksi","rakyat","ralat","ralip","ramadan","ramah","ramai","ramal","rambah","rambang","rambut","rambu","rames","rami","rampa","rampai","rampas","ramping","rampok","ramu","ramuan","rana","ranah","rancak","rancang","rancu","randa","randu","rangga","rangka","rangkai","rangkak","rangkap","rangkul","rangkum","rangkung","rangsang","rangsek","rani","ranjang","ranjau","ranji","ranjau","ransel","ransum","rantai","rantam","rantang","rantas","rantau","ranti","ranting","ranum","ranya","rapat","rapel","rapi","rapor","rapu","rapuh","rasa","rasai","rasam","rasamala","rasi","rasio","rasional","rasuk","rasul","rata","ratapan","ratas","ratib","ratna","ratu","ratus","raum","raun","raung","raup","raut","rawa","rawai","rawak","rawan","rawat","rawi","rawit","rawon","raya","rayap","rayon","rayu","reagen","reaksi","reaktor","real","realisasi","realitas","realitas","rebab","rebah","reban","rebana","rebas","rebat","rebeh","rebek","rebok","rebon","rebuk","rebung","rebus","rebut","reca","recana","receh","recik","recok","reda","redaksi","redam","redang","redap","redas","redup","reduksi","referensi","refleksi","reformasi","regang","regat","regel","regen","reges","regim","register","regu","reguk","regup","rehab","rehal","rehat","reja","rejah","rejan","rejang","rejeki","rejen","reka","rekah","rekam","rekan","rekap","rekat","rekayasa","reken","rekening","rekes","rekod","rekor","rekomendasi","rekonsiliasi","rekreasi","rekrutmen","rektor","rel","rela","relai","relaksasi","relap","relas","relatif","relau","relawan","relevan","relevansi","relief","religi","relung","rem","rema","remah","remaja","remak","remang","remas","rematik","rembah","rembes","remburs","remedi","remet","remis","remo","rempa","rempah","rempak","rempelas","rempes","rempet","rempi","rempong","rempuh","remujung","remuk","renah","renai","renang","rencah","rencak","rencana","rencang","rencat","rencong","renda","rendabel","rendah","rendam","rendang","rendeng","rendong","renek","renes","rengat","rengeh","rengek","rengeng","renggam","renggang","rengges","rengginang","renggut","rengit","rengkah","rengkam","rengket","rengkih","rengkit","rengkuh","rengreng","rengsa","rengus","rengut","renik","renin","renjana","renjis","renjul","renovasi","renta","rentak","rentaka","rentan","rentang","rentap","rentas","rente","rentenir","renteng","rentet","renti","rentik","reo","reog","reorganisasi","reot","repak","repang","reparasi","repas","repek","repes","repet","repetisi","repih","replika","repor","reportase","reporter","repot","represif","reptil","republik","repui","reput","reputasi","rerata","reras","resah","resak","resam","resan","resap","resek","resep","resepsi","reserse","reses","resi","residen","resik","resiko","resimen","resing","resital","resmi","resolusi","resonansi","resor","respirasi","respek","respons","restan","restoran","restorasi","restu","resleting","resus","ret","reta","retak","retal","retas","retek","retih","retina","retok","retorika","retret","retul","retur","reuni","revolusi","reog","rewak","rewan","rewang","rewel","rewet","reyot","rezim","ria","riadah","riah","riak","rial","riam","rian","riang","riap","rias","riba","ribu","ribut","rica","ricau","ricik","ricis","ricuh","rida","ridan","ridi","ridip","ridho","rig","rihat","rihlah","riil","rijal","rikuh","rikues","ril","rila","rilis","rim","rima","rimas","rimba","rimbas","rimbat","rimbit","rimbu","rimbuh","rimbun","rimbung","rimis","rimpang","rimpelu","rimpi","rimpuh","rimpung","rinai","rinci","rincis","rincu","rindang","rinding","rindu","ring","ringan","ringgit","ringih","ringik","ringin","ringis","ringit","ringkai","ringkas","ringkasan","ringkik","ringking","ringkis","ringkok","ringkuh","ringkus","ringsek","rini","rintang","rintangan","rintas","rintih","rintik","rintip","rintis","rinu","rinya","rinye","rioli","riparian","ripuh","ripuk","ririt","risak","risalah","risau","riset","risi","risik","risiko","risit","rit","ritme","ritual","riuh","riuk","riung","rival","riwan","riwayat","roba","robak","robek","roboh","robok","robot","rocet","rod","roda","rodan","rodat","rodi","rodok","rodong","rogoh","rogok","rogol","roh","rohani","rohmat","rojah","rojak","rojol","rok","roker","roket","roki","rokok","roma","roman","romansa","romantik","rombak","rombeng","rombo","rombok","rombongan","romok","romong","rompal","rompang","rompeng","rompes","rompi","rompil","rompok","rompong","rompwang","romusa","rona","roncet","ronda","ronde","rondo","roneo","rong","rongak","rongga","ronggang","ronggeng","ronggo","ronggok","rongkoh","rongkok","rongkong","rongos","rongrong","rongseng","rongsok","ronta","rontak","rontok","ronyeh","rorod","ros","rosok","rosot","rotan","roti","rotok","rowot","royal","royalti","royan","royer","royong","rua","ruah","ruai","ruak","ruam","ruan","ruang","ruap","ruas","ruat","ruba","rubah","rubai","ruban","rubel","rubik","rubin","rubing","rubrik","rubu","rubung","rubuh","rucah","rudah","rudal","rudi","rudin","rudu","rudus","rugi","ruh","ruing","ruis","ruit","rujah","rujak","ruji","rujuk","rukam","ruku","rukuh","rukuk","rukun","rumah","rumal","rumba","rumbah","rumbai","rumbun","rumenia","rumi","rumin","rumit","rumor","rumpaka","rumpi","rumpil","rumpon","rumpun","rumput","rumrum","rumuk","rumung","rumus","runcing","runcit","runding","rundu","runduk","rundung","rungau","rungguh","rungu","rungus","rungut","runjam","runjang","runjau","runjung","runtai","runtas","runti","runtih","runtuh","runtun","runtut","runut","runyak","runyam","runyut","rupa","rupanya","rupawan","rupiah","ruruh","rurut","rusa","rusak","rusuh","rusuk","rutin","rutuk","ruwah","ruwat","ruwet","ruyak","ruyap","ruyung"},
    ["s"]={"saat","sabar","sabas","sabat","sabda","sabel","saben","sabil","sabit","sablon","sabot","sabotase","sabrang","sabtu","sabuk","sabun","sabung","sabur","sabut","sadah","sadai","sadak","sadap","sadar","sadau","sadel","sadik","sading","sadir","sadis","sado","sadrah","sadur","saf","safa","safari","safi","safir","saga","sagai","sagar","sagu","sagun","sah","sahabat","sahaja","saham","sahan","sahap","sahara","sahaya","sahdu","sahi","sahib","sahid","sahih","sahn","sahur","sahut","saif","sail","saing","sains","sair","sais","sait","saja","sajadah","sajak","sjarah","saji","sajian","sak","saka","sakal","sakap","sakar","sakarat","sakat","sake","sakh","sakit","saklar","sakratulmaut","sakral","sakramen","saksofon","saksi","sakti","saku","sal","sala","salah","salai","salak","salam","salang","salap","salar","salat","saldo","sale","saleh","salep","sali","salib","salih","salim","salin","salinan","salip","salir","saliwir","salju","salmon","salol","salon","salto","saluang","saluir","saluk","salung","salur","salut","sama","samad","samak","saman","samar","samara","samas","samba","sambal","sambang","sambar","sambat","sambau","sambi","sambil","sambit","sambuk","sambung","sambur","sambut","samek","sami","samir","sampa","sampah","sampai","sampak","sampan","sampar","sampat","sampe","sampel","samper","sampi","samping","sampir","samplok","sampo","sampu","sampuk","sampul","samsak","samsu","samudera","samum","samun","sana","sanak","sanat","sanatorium","sanda","sandal","sandang","sandar","sandera","sandi","sandung","sandiwara","sane","sang","sanga","sangai","sangan","sangar","sangat","sangau","sanggah","sanggai","sanggal","sanggam","sanggama","sanggan","sanggar","sanggat","sanggep","sangger","sanggit","sanggon","sanggraloka","sanggrah","sanggul","sanggup","sanggur","sangka","sangkak","sangkal","sangkan","sangkar","sangkil","sangkin","sangking","sangku","sangkur","sangkut","sangli","sangsai","sangsaka","sangsi","sangu","sani","saniter","sanjai","sanjung","sanksi","sansai","sansekerta","senta","santai","santam","santan","santap","santau","santer","santet","santri","santun","sanyawa","sapa","sapai","sapak","sapar","sapat","sapau","sapi","sapih","sapir","sapit","sapta","sapu","saput","sar","sara","saraf","sarak","saran","sarana","sarang","sarap","sarat","sarau","sarden","sarekat","saren","sareh","sareng","sarhad","sari","saring","sarip","sarirah","sarit","sarjana","sarju","sarkas","saron","sarong","sarsar","sarta","saru","saruk","sarun","sarung","sarut","sarwa","sarwal","sas","sasa","sasak","sasaran","sasar","sasau","sasi","sasian","sasis","sastra","sastrawan","sat","sata","satai","satak","satan","sate","satelit","saten","satir","satpam","satria","satron","satu","satuan","satwa","sau","saudagar","saudara","sauh","sauk","saum","sauna","saung","saus","saw","sawa","sawadikap","sawah","sawai","sawak","sawala","sawang","sawar","sawat","sawer","sawi","sawit","sawo","saya","sayak","sayang","sayap","sayat","sayembara","sayet","sayib","sayid","sayu","sayup","sayur","sebab","sebah","sebai","sebak","sebal","sebam","sebanding","sebangsa","sebar","sebat","sebaur","sebeh","sebek","sebel","sebelah","sebelas","sebentar","seberang","seberat","sebet","sebih","sebis","sebrot","sebu","sebuk","sebum","sebun","sebut","secang","secerek","seda","sedah","sedak","sedam","sedan","sedang","sedap","sedat","sedekah","sedeng","sederhana","sedia","sediakala","sedih","sedikit","sedong","sedot","sedu","seduh","seg","segah","segak","segala","segan","segani","segar","segara","segeh","segel","segen","segera","segi","segmen","segoro","sehat","seia","sejahtera","sejak","sejarah","sejati","sejingkat","sejoli","sejuk","seka","sekah","sekak","sekal","sekali","sekam","sekang","sekap","sekar","sekarang","sekat","sekaten","sekatup","sekaut","sekedar","sekeh","sekel","sekeri","sekertaris","sekil","sekip","sekira","sekitar","sekoi","sekolah","sekongkol","sekop","sekoteng","sekretaris","sekrup","seksi","sekian","sektor","sekul","sekunder","sekuritas","sekutu","sel","sela","selabar","selada","seladang","selai","selain","selaju","selak","selaka","selalu","selam","selamat","selamba","selampai","selampe","selan","selang","selangka","selaput","selar","selaras","selasa","selasar","selasih","selat","selatan","selawat","selaya","sele","selebaran","selebriti","seledri","seleguri","selekeh","selekor","seleksi","selempang","selendang","selenggara","selentik","seleo","selepa","selepat","selepet","selepi","selera","selesa","selesai","seletuk","seleweng","selia","selidik","seligi","seligit","selimpang","selimut","selinap","seling","selingkuh","selip","selir","selisih","selisik","selit","seliwer","selo","selodang","selok","seloka","selokan","seloki","selom","selonjor","selonong","selop","seloroh","selot","seloyak","seloyong","selu","seluar","selubung","seludup","selui","seluk","selulu","selulup","selumur","seluler","selundup","selungkang","selup","selurah","seluru","seluruh","selusuh","selusup","selusur","selut","semadi","semah","semai","semak","semakin","semalam","semambu","semampai","seman","semang","semangat","semangka","semangkok","semantik","semar","semara","semarak","semat","semata","semawang","sembab","sembada","sembah","sembahyang","sembai","sembak","sembam","sembap","sembar","sembarang","sembat","sembayan","sembelih","sembelit","sember","semberip","sembrono","sembu","sembuh","sembul","sembunyi","sembur","semburit","semek","semen","semena","semenanjung","semenda","semenggah","sementara","sementung","semerawang","semerbak","semesta","semi","semiang","semifinal","semik","seminar","seminau","semilir","semir","semoga","semok","sempada","sempadan","sempak","sempal","sempana","sempat","sempelih","semper","semperit","sempit","semplak","sempoa","semprot","sempur","sempurna","semrawut","semu","semua","semugut","semuka","semula","semur","semut","sen","sena","senak","senam","senandum","senang","senantan","senyap","senar","senari","senat","senawi","senda","sendal","sendang","sendar","sendat","sendawa","sendeng","sender","sendi","sendiri","sendok","senen","seng","sengaja","sengal","sengam","sengap","sengar","sengat","sengau","senggak","senggang","senggat","sengget","senggol","sengguk","senggut","sengih","sengir","sengit","sengkak","sengkang","sengkar","sengkayan","sengkela","sengketa","sengkuap","sengsai","sengsara","senguk","sengut","seni","senigai","senil","senin","senior","seniwan","seniman","senja","senjang","senjar","senjata","senjolong","senjong","senohong","sensasi","sensitif","sensus","senta","sentada","sentadu","sentagi","sentak","sentali","sentana","sentap","sentara","senteng","senter","senteri","senti","sentil","sentimen","senting","sentong","sentosa","sentra","sentral","sentuh","sentuk","sentul","sentung","senuh","senuk","senung","senyak","senyam","senyap","senyar","senyum","senyur","senyawa","sep","sepa","sepah","sepai","sepak","sepal","sepam","sepan","sepanjang","sepang","sepasang","sepat","sepatu","sepeda","sepegoh","sepele","sepen","sepeninggal","sepenuh","seperi","sepet","sepi","sepihak","sepih","sepir","sepit","sepoi","sepon","sepor","september","sepuh","sepuit","sepuk","sepul","sepuluh","sepur","seput","sepupu","serabai","serabut","seraga","serah","serai","serak","serakah","seram","serama","serambi","serampang","seran","serana","serandau","serang","serangga","serani","seranta","serap","serapah","serat","serau","seraut","serawa","serawal","serawan","serawat","serba","serbak","serban","serbat","serbet","serbu","serbuk","serdadu","serdam","serdawa","sere","sereat","seregang","sereh","serem","seremoni","serempak","seren","serendeng","sereng","serengeh","serenjak","serenta","serep","seret","sergah","sergam","sergap","seri","seriap","seriat","seribulan","serigala","serik","serikat","serimpi","serindit","sering","seringai","serit","serius","serkah","serkai","serkap","serkup","serlah","serling","sermangin","sero","serobok","serobot","seroda","seroja","serok","serombong","serondol","serong","seronok","seropot","serosoh","serot","serpa","serpai","serpak","serpang","serpih","sersan","serta","sertifikat","sertu","seru","seruak","serual","seruda","serudi","seruduk","seruh","serui","seruit","seruk","serul","seruling","serum","serumpun","serun","serunda","seruni","serupa","serut","serutu","sesah","sesai","sesak","sesal","sesam","sesap","sesar","sesat","sesira","sesuai","set","seta","setabel","setai","setal","setala","setan","setang","setangan","setanggi","setara","setat","setawar","seteger","setek","setel","setem","seten","setengah","seter","seterap","seteru","setia","setiar","setik","setin","seting","setip","setir","setop","setora","setori","setra","setrap","setrika","setru","setrum","setu","setua","setul","setum","setung","setup","seturi","sewa","sewah","sewal","sewar","sewat","sewet","sex","si","sia","siaga","siah","siak","sial","sialang","siam","siamang","sian","siang","sianu","siap","siapa","siar","siasat","siat","sibak","sibar","siber","sibir","sibuk","sibur","sidai","sidang","sidik","siding","siduga","sifat","sigai","sigak","sigap","sigar","siga","sigasir","sigi","sigma","signifikan","sigot","sigung","sih","sihir","sijil","sika","sikah","sikak","sikap","sikas","sikat","sikeras","sikik","sikin","sikit","siksa","siku","sikud","sikut","sila","silah","silam","silang","silap","silat","silau","silet","silih","silik","silinder","silir","silok","silsilah","silu","siluk","siluman","silung","sim","sima","simak","simbah","simbai","simbak","simbang","simbar","simbat","simbur","simbol","simfoni","simpai","simpak","simpan","simpang","simpati","simpel","simpir","simpul","simulasi","simuntu","sin","sina","sinambung","sinan","sinar","sinau","sindap","sinder","sindir","sindu","sing","singa","singah","singgah","singgan","singgang","singgasana","singgul","singit","singkang","singkap","singkat","singkeh","singkil","singkir","singkong","singkur","singsat","singset","singsing","sini","sinis","sinjal","sinka","sinkron","sinom","sinse","sintal","sintar","sinting","sintir","sintua","sintuk","sintung","sinu","sinuh","sinyal","sinyo","sio","sioca","siong","sip","sipa","sipahi","sipat","sipi","sipil","sipir","sipit","sipo","sipong","sipu","sipur","siput","sir","sira","sirah","siram","sirap","sirat","sirep","sirih","sirik","siring","sirip","sirkuit","sirkulasi","sirkus","sirna","sirop","sirsak","siruk","sirup","sisa","sisal","sisi","sisih","sisik","sisip","sisir","sistem","siswa","sit","sita","sitar","siti","siting","sito","situ","situasi","siuk","siul","siuman","siung","siur","siut","siwer","skala","skandal","skema","skenario","sketsa","skiz","skor","skors","skrip","skripsi","skuadron","slang","slendro","slogan","smes","soak","soal","soang","soba","soban","sobat","sobek","sobok","soda","sodok","sodor","soek","sofa","sofis","soga","sogang","sogok","sohor","soja","sok","soka","soker","soket","sokom","sokong","sol","solah","solak","solang","solar","soldadu","solek","solid","solidaritas","solis","solo","solok","solot","solum","solusi","som","soma","sombong","someng","sompak","somplak","sompoh","sompok","sompong","sompret","sonar","sonder","sondok","sondong","songar","songel","songgeng","songkok","songong","songsong","sonik","sono","sontak","sontok","sop","sopak","sopan","sopi","sopir","sopor","sorak","sorang","sore","sorek","sorga","sorog","sorong","sorot","sosial","sosialis","sosiawan","sosis","sosoh","sosok","soto","sotoh","sotong","sowan","soyak","soyang","spanduk","spasi","spesial","spesifik","spesimen","spons","sponsor","spontan","sport","srempet","stabil","stabilitas","stadion","staf","stagnasi","stamina","standar","start","stasiun","status","stempel","stiker","stimulus","stok","stop","stoples","strata","strategi","stres","struktur","studi","studio","sua","suai","suak","sual","suam","suami","suang","suap","suar","suara","suarang","suarawati","suari","suasa","suasana","suat","suatu","sub","subak","subal","subam","suban","subang","subhana","subjek","subsidi","subuh","subur","suci","suda","sudah","sudi","sudip","sudra","sudu","suduk","sudung","sudut","suf","sufi","sufrah","suga","sugesti","sugi","suguh","sugul","suh","suhad","suhu","suhuf","suhun","suing","suir","suit","sujad","sujarah","sujud","suka","sukacita","sukar","sukarela","sukaria","sukat","sukma","sukses","suku","sukun","sula","sulah","sulam","sulang","sulap","sulbi","sulfat","suli","sulih","suling","sulit","sultan","suluh","suluk","sulung","sulup","sulur","sulut","sum","sumah","sumak","sumarah","sumba","sumbang","sumbar","sumbat","sumber","sumbi","sumbu","sumbul","sumbur","sumbut","sumir","sumpah","sumpal","sumpek","sumpel","sumping","sumpit","sumsum","sumur","sun","sunah","sunam","sunan","sunat","sundai","sundak","sundal","sundang","sundep","sundik","sunduk","sundul","sundut","sungai","sungga","sunggit","sungguh","sungkah","sungkai","sungkal","sungkan","sungkap","sungkawa","sungkuk","sungkup","sungkur","sunglap","sungsang","sungsum","sungut","suni","sunjam","sunti","sunting","suntuk","sunu","sunyi","sup","supaya","supel","super","supervisi","supir","suplai","suplemen","sur","sura","surah","surai","suralaya","suram","surat","surau","surga","suri","surian","suruh","suruk","surung","surup","surut","survai","survei","surya","suryakanta","susah","susastra","susu","susuh","susuk","susul","susun","susung","susup","susur","susut","sut","sutan","suten","sutera","sutil","sutra","sutradara","suun","suvenir","suwir","swadesi","swadidik","swalayan","swara","swarga","swasembada","swasta","swasembada","swatantra","swasta","syabas","syah","syahdu","syahid","syair","syak","syarat","syariah","syirik","syok","syukur"},
    ["t"]={"tabah","tabrak","tabu","tabung","tadi","tafsir","tagih","tahan","tahu","tahun","taib","taiga","taiko","tain","tajam","takabur","takaran","takdir","takluk","takraw","taksir","takut","tala","talak","tali","taman","tamat","tambah","tambak","tambal","tambang","tampak","tampan","tampar","tampil","tampung","tamu","tanah","tanam","tanang","tancap","tanda","tandang","tanduk","tangan","tangga","tanggal","tanggap","tangguh","tanggung","tangis","tangkai","tangkap","tani","tanjung","tantang","tante","tanur","tanya","taoisme","tapak","tari","tarif","tarik","taruh","tas","tata","tatap","tato","tau","taufik","tauladan","tauran","tawaf","tawan","tawar","tawon","tayang","teater","tebal","tebang","tebar","tebing","tebu","tebus","teduh","tegak","tegang","tegar","tegas","teguk","tegur","tekad","tekan","teking","teknis","teknologi","tekstur","tekuk","teladan","telah","telak","telan","telanjang","telapak","telat","telik","teliti","telur","teman","temani","temaram","tematik","tembaga","tembak","tembakau","tembikar","tembok","temon","tempat","tempe","tempel","temperamen","tempik","templok","tempo","tempur","temu","tenaga","tenang","tendang","tendensi","tengadah","tengah","tenggelam","tenggorokan","tengik","tengkar","tengkorak","tengkulak","tenis","tentang","tentara","tentatif","tenteram","tentu","tenun","teori","tepa","tepat","tepi","tepu","terakhir","teralis","terang","teras","teratai","terawang","terbang","terbit","terbitan","terdalam","tergantung","terhormat","teri","teriak","terik","terima","terjal","terjamah","terjun","terka","terkam","terkini","terkurung","termal","termanis","termometer","ternak","terompet","teror","terowongan","terpal","tertawa","tertib","terumbu","teruna","terus","tetes","tetua","tewas","tiada","tiang","tiap","tiba","tidak","tidur","tiga","tikam","tikar","tikas","tiket","tilang","tilik","tim","timah","timbal","timbang","timbul","timur","tindak","tinggal","tinggi","tingkah","tingkat","tinja","tinjau","tinta","tipis","tipu","tirai","tirakat","tiru","tis","titah","titi","titik","titip","tiup","tobat","tobrut","tokcer","toko","tokoh","tolak","tolol","tomat","tombak","tong","tonggak","tongkat","tonjok","topan","topeng","topi","topik","torak","total","tua","tuban","tubuh","tuding","tugas","tugu","tujuan","tukang","tukar","tulang","tulis","tulisan","tuli","tumbas","tumbuh","tumbuk","tumor","tunai","tunanetra","tunas","tunda","tunduk","tungau","tunggak","tunggal","tunggang","tunjuk","tuntas","tuntut","tupai","turun","turut","tusuk","tutup","tutur","tuyul"},
    ["u"]={"uang","uap","ubah","uban","ubun","ucap","udang","udara","ufuk","ujar","uji","ujian","ujung","ukhuwah","ukiran","ukur","ulah","ulak","ulang","ular","ulas","ulat","ultah","ultimatum","ultra","ulu","ulung","umat","umbi","umbul","umpan","umpat","umroh","umum","umur","unggas","unggul","unggun","ungkap","ungu","unguis","uni","unik","unit","universitas","unsur","untai","untung","upacara","upah","upaya","upgrade","upil","uraian","urak","uranium","urapan","urat","urban","urip","urusan","usaha","usang","usap","user","usia","usik","usil","usul","usus","utama","utang","utara","utuh","utusan","uud","uzur"},
    ["v"]={"vaksin","vakum","valas","valid","valuta","vandalisme","vanila","varian","variasi","varietas","vasektomi","vegan","vegetarian","vektor","velg","velvet","vena","ventilasi","ventrikel","verbal","verifikasi","versi","vertikal","vespa","veteran","veto","via","vibrasi","video","vignet","vila","vinil","vintaj","viral","virtual","virus","visi","visiual","vital","vitamin","vokabuler","vokal","vokalis","vokasi","voli","volume","volumetrik","voodoo","votum","voyerisme","vulkan","vulgar"},
    ["w"]={"wabah","wadah","waduk","wafat","wafel","waga","wajah","wajar","wajib","wakaf","wakil","waktu","walau","walet","wali","walikota","wanita","wanti","waralaba","waras","warden","warek","warga","waris","warna","warung","wasiat","wasit","waspada","watak","watan","watap","wawancara","wawasan","wayang","wayuh","wedang","wedar","wedus","wegah","wejang","welasan","welirang","welu","wenang","wereng","wesel","wibawa","widuri","wijen","wijayakusuma","wiken","wilis","wira","wiracarita","wirid","wiru","wisata","wisma","wiwara","wiyata","wol","wolfram","wong","wono","wudhu","wujud","wungon","wuwung"},
    ["x"]={"xantat","xenofobia","xenon","xerografi","xerosis","xilem","xilofon","xiloid","xilol"},
    ["y"]={"yakin","yakni","yang","yankee","yard","yayasan","yodium","yoga","yakis","yaksa","yakub","yamtuan","yogi","yogyakarta","yokel","yolk","yuda","yudikatif","yudisial","yudisium","yuk","yukata","yumi","yunda","yuppie"},
    ["z"]={"zaitun","zakar","zakat","zalim","zaman","zamrud","zat","zebra","zenith","ziggurat","zikir","zina","zionis","zodiak","zohal","zona","zonder","zoo","zoologi","zuhud","zulhijah","zulmat","zuriat"}
}

-- INDEXING
for key, wordList in pairs(RAW_KAMUS) do
    local validWords = {}
    for _, word in ipairs(wordList) do
        if #word >= 3 then
            table.insert(validWords, word)
            State.GlobalDict[word] = true
        end
    end
    table.sort(validWords, function(a, b) return #a < #b end)
    State.Index[key] = validWords
end

-- ═══════════════════════════════════════════════════════════════════════
-- 2. SMART LOGIC (REACTIVE)
-- ═══════════════════════════════════════════════════════════════════════

-- A. Cari Kata - IMPROVED with smarter selection and LOCK SYSTEM
local function FindWord(prefix, forceNew)
    if not prefix or prefix == "" then return nil end
    
    -- LOCK SYSTEM: If prefix hasn't changed and we have a locked word, return it
    if not forceNew and State.LockedPrefix == prefix and State.LockedWord ~= "" then
        -- Verify locked word is still valid (not used)
        if not State.UsedWords[State.LockedWord] then
            return State.LockedWord
        end
    end
    
    local bucket = State.Index[prefix:sub(1,1):lower()]
    if not bucket then return nil end
    
    local candidates = {}
    
    -- Collect valid candidates
    for _, word in ipairs(bucket) do
        if word:sub(1, #prefix) == prefix and not State.UsedWords[word] then
            table.insert(candidates, word)
        end
    end
    
    -- Smart selection based on preference
    if #candidates > 0 then
        local selectedWord = nil
        
        -- If we have consecutive errors, prefer shorter words
        if State.ConsecutiveErrors > 2 and State.PreferredLength > 0 then
            for _, word in ipairs(candidates) do
                if #word <= State.PreferredLength + 2 then
                    selectedWord = word
                    break
                end
            end
        end
        
        -- Balanced: pick from middle of list to avoid most common
        if not selectedWord and State.WordPreference == "balanced" then
            local midIdx = math.floor(#candidates / 2) + math.random(0, math.floor(#candidates / 2))
            midIdx = math.max(1, math.min(midIdx, #candidates))
            selectedWord = candidates[midIdx]
        end
        
        -- Default: return first available
        if not selectedWord then
            selectedWord = candidates[1]
        end
        
        -- LOCK THE WORD
        State.LockedWord = selectedWord
        State.LockedPrefix = prefix
        State.TotalWordsFound = State.TotalWordsFound + 1
        
        return selectedWord
    end
    
    -- No candidates found - clear lock
    State.LockedWord = ""
    State.LockedPrefix = ""
    return nil
end

-- Function to unlock/clear locked word
local function UnlockWord()
    State.LockedWord = ""
    State.LockedPrefix = ""
end


-- B. Deteksi Kata Pemain Lain (Scan & Blacklist)
local function ScanForUsedWords(args)
    if not State.AutoBlacklist then return end
    for _, val in pairs(args) do
        if type(val) == "string" and #val > 2 then
            local clean = val:lower():gsub("%s+", "")
            if State.GlobalDict[clean] and not State.UsedWords[clean] then
                State.UsedWords[clean] = true
            end
        end
    end
end




-- D. RNG Human Delay - More natural variation
local function GetDelay()
    -- Add small random pauses occasionally for human-like behavior
    local baseDelay = State.TypingDelayMin + (math.random() * (State.TypingDelayMax - State.TypingDelayMin))
    
    -- 15% chance to pause slightly longer (like human thinking)
    if math.random() < 0.15 then
        baseDelay = baseDelay + math.random(5, 15) / 100
    end
    
    return baseDelay
end



-- E. EKSEKUSI UTAMA (REACTIVE LOOP) with LOCK SYSTEM
local function ExecuteReactivePlay(word, prefixLen, submitRemote, visualRemote)
    if State.ActiveTask then return end
    State.ActiveTask = true
    
    -- Store the word we're working with (LOCK IT)
    local currentWord = word
    local currentPrefix = State.CurrentSoal
    
    local think = State.ThinkDelayMin + (math.random() * (State.ThinkDelayMax - State.ThinkDelayMin))
    task.wait(think)
    
    -- 2. KETIK (Loop dengan Pengecekan)
    local startIdx = prefixLen + 1
    if startIdx < 1 then startIdx = 1 end
    
    for i = startIdx, #currentWord do
        -- CEK 1: Apakah Auto dimatikan?
        if not State.AutoEnabled then State.ActiveTask = false; return end
        
        -- CEK 2: Apakah prefix berubah? (soal baru)
        if State.CurrentSoal ~= currentPrefix then
            -- Prefix changed, abort current word - DON'T CLEAR, just stop
            State.ActiveTask = false
            UnlockWord() -- Clear lock since prefix changed
            return
        end
        
        -- CEK 3: Apakah kata ini BARUSAN dipakai orang lain?
        if State.UsedWords[currentWord] then
            -- Don't clear - just stop and retry with new word
            UnlockWord() -- Unlock since word is used
            
            -- Langsung cari kata baru (Retry Instant) - FORCE NEW WORD
            local retry = FindWord(State.CurrentSoal, true)
            if retry then
                State.ActiveTask = false
                task.spawn(function() ExecuteReactivePlay(retry, #State.CurrentSoal, submitRemote, visualRemote) end)
            else
                State.ActiveTask = false
            end
            return
        end
        
        -- CEK 4: Verify locked word hasn't changed mid-typing
        if State.LockedWord ~= currentWord and State.LockedPrefix == currentPrefix then
            -- Word was changed by system, switch to new word without clearing
            State.ActiveTask = false
            task.spawn(function() 
                ExecuteReactivePlay(State.LockedWord, #State.CurrentSoal, submitRemote, visualRemote) 
            end)
            return
        end

        
        -- Ketik huruf
        visualRemote:FireServer(currentWord:sub(1, i))
        task.wait(GetDelay())
    end
    
    -- 3. SUBMIT & POST-CHECK
    task.wait(0.5)
    if State.AutoEnabled and State.CurrentSoal == currentPrefix then
        submitRemote:FireServer(currentWord)
        State.LastWordAttempted = currentWord
        State.LastSubmitTime = tick()
        State.UsedWords[currentWord] = true -- Tandai sendiri
        
        -- Keep lock until we confirm success or failure
    end
    
    State.ActiveTask = false
end


-- ═══════════════════════════════════════════════════════════════════════
-- 3. UI CONSTRUCTION
-- ═══════════════════════════════════════════════════════════════════════
local Window = Fluent:CreateWindow({
    Title = "SKP v13.3 Reactive",
    SubTitle = "Auto-Correct Logic",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = { Main = Window:AddTab({ Title = "Main", Icon = "home" }) }

local AutoToggle = Tabs.Main:AddToggle("Auto", {Title = "Auto Play", Default = false })
AutoToggle:OnChanged(function() State.AutoEnabled = AutoToggle.Value end)

-- CUSTOM SPEED CONTROLS
local SpeedSection = Tabs.Main:AddSection("Kecepatan Mengetik")

local MinSpeedSlider = Tabs.Main:AddSlider("MinSpeed", {
    Title = "Delay Minimum (detik)",
    Default = 0.45,
    Min = 0.1,
    Max = 2.0,
    Rounding = 2
})
MinSpeedSlider:OnChanged(function(value)
    State.TypingDelayMin = value
    if State.TypingDelayMin > State.TypingDelayMax then
        State.TypingDelayMax = State.TypingDelayMin
    end
end)

local MaxSpeedSlider = Tabs.Main:AddSlider("MaxSpeed", {
    Title = "Delay Maksimum (detik)",
    Default = 0.95,
    Min = 0.1,
    Max = 3.0,
    Rounding = 2
})
MaxSpeedSlider:OnChanged(function(value)
    State.TypingDelayMax = value
    if State.TypingDelayMax < State.TypingDelayMin then
        State.TypingDelayMin = State.TypingDelayMax
    end
end)

local ThinkSpeedSlider = Tabs.Main:AddSlider("ThinkSpeed", {
    Title = "Waktu Mikir (detik)",
    Default = 2.5,
    Min = 0.5,
    Max = 5.0,
    Rounding = 1
})
ThinkSpeedSlider:OnChanged(function(value)
    State.ThinkDelayMax = value
    State.ThinkDelayMin = value * 0.4
end)

local OverlayScroll

local function CreateOverlay()
    pcall(function() if Services.CoreGui:FindFirstChild("SKP_Overlay") then Services.CoreGui.SKP_Overlay:Destroy() end end)
    local Screen = Instance.new("ScreenGui", Services.CoreGui) Screen.Name = "SKP_Overlay"
    local Frame = Instance.new("Frame", Screen)
    Frame.Size = UDim2.new(0, 180, 0, 250)
    Frame.Position = UDim2.new(0.85, 0, 0.35, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Frame.Active = true; Frame.Draggable = true
    Instance.new("UICorner", Frame)
    
    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "SARAN KATA"
    Title.TextColor3 = Color3.fromRGB(0, 255, 150)
    Title.BackgroundTransparency = 1
    
    OverlayScroll = Instance.new("ScrollingFrame", Frame)
    OverlayScroll.Size = UDim2.new(0.9, 0, 0.85, 0)
    OverlayScroll.Position = UDim2.new(0.05, 0, 0.12, 0)
    OverlayScroll.BackgroundTransparency = 1
    Instance.new("UIListLayout", OverlayScroll).Padding = UDim.new(0, 2)
end

local function UpdateOverlay(prefix, submitRemote)
    if not OverlayScroll then return end
    for _, v in pairs(OverlayScroll:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
    
    local bucket = State.Index[prefix:sub(1,1):lower()] or {}
    local count = 0
    for _, w in ipairs(bucket) do
        if count >= 10 then break end
        if w:sub(1, #prefix) == prefix and not State.UsedWords[w] then
            local btn = Instance.new("TextButton", OverlayScroll)
            btn.Size = UDim2.new(1, 0, 0, 25)
            btn.Text = w
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            btn.TextColor3 = Color3.fromRGB(220, 220, 220)
            Instance.new("UICorner", btn)
            btn.MouseButton1Click:Connect(function()
                submitRemote:FireServer(w)
                State.UsedWords[w] = true
                btn.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            end)
            count = count + 1
        end
    end
    OverlayScroll.CanvasSize = UDim2.new(0, 0, 0, count * 27)
end

-- ═══════════════════════════════════════════════════════════════════════
-- 4. MAIN LOOP
-- ═══════════════════════════════════════════════════════════════════════
local function Init()
    CreateOverlay()
    local MatchRemote = Services.ReplicatedStorage:FindFirstChild("MatchUI", true)
    local SubmitRemote = Services.ReplicatedStorage:FindFirstChild("SubmitWord", true)
    local VisualRemote = Services.ReplicatedStorage:FindFirstChild("BillboardUpdate", true)
    
    if not MatchRemote or not SubmitRemote then
        Fluent:Notify({Title = "Error", Content = "Remote tidak ditemukan!", Duration = 5})
        return
    end

    -- EVENT LISTENER
    MatchRemote.OnClientEvent:Connect(function(...)
        local args = {...}
        ScanForUsedWords(args) -- Selalu scan kata orang lain
        
        if args[1] == "UpdateServerLetter" and args[2] then
            local letter = tostring(args[2]):lower()
            
            if State.CurrentSoal ~= letter then
                if State.LockedPrefix ~= letter then
                    UnlockWord()
                end
                
                State.CurrentSoal = letter
                State.ActiveTask = false
                State.ConsecutiveErrors = 0
                State.TotalCorrect = State.TotalCorrect + 1
                UpdateOverlay(letter, SubmitRemote)
                
                if State.AutoEnabled then
                    local word = FindWord(letter)
                    if word then
                        task.spawn(function()
                            ExecuteReactivePlay(word, #State.CurrentSoal, SubmitRemote, VisualRemote)
                        end)
                    end
                end
            end
        end
    end)


    -- POST-SUBMIT WATCHDOG - IMPROVED v14.0 (Cek Salah/Gagal + Statistics)
    task.spawn(function()
        while State.IsRunning do
            task.wait(0.5)
            -- Logic: Jika Auto ON + Tidak sedang ngetik + Soal belum ganti > 3 detik sejak submit terakhir
            if State.AutoEnabled and not State.ActiveTask and State.CurrentSoal ~= "" and tick() - State.LastSubmitTime > 3.0 then
                
                State.TotalErrors = State.TotalErrors + 1
                State.ConsecutiveErrors = State.ConsecutiveErrors + 1
                State.RejectedWords[State.LastWordAttempted] = true
                State.UsedWords[State.LastWordAttempted] = true
                State.ActiveTask = true
                
                task.wait(0.2)
                UnlockWord()
                
                local retry = FindWord(State.CurrentSoal, true)
                if retry then
                    State.ActiveTask = false
                    ExecuteReactivePlay(retry, #State.CurrentSoal, SubmitRemote, VisualRemote)
                else
                    State.ActiveTask = false
                    State.RejectedWords = {}
                end
                
                State.LastSubmitTime = tick()
            end
        end
    end)
    
    Fluent:Notify({Title = "Beverly Hub", Content = "Sambung Kata 1.0", Duration = 5})
end

Init()