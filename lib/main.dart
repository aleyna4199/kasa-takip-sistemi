import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KasaTakipApp());
}

class KasaTakipApp extends StatelessWidget {
  const KasaTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kasa Takip Sistemi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  List<Map<String, dynamic>> _islemListesi = [];
  double _toplamBakiye = 0.0;
  double _toplamGelir = 0.0;
  double _toplamGider = 0.0;

  // Filtreleme için değişken (null = Tüm Zamanlar, 'YYYY-MM' = Ay, 'YYYY-MM-DD' = Gün)
  String? _secilenFiltre;
  List<String> _filtrelenebilirDonemler = [];

  @override
  void initState() {
    super.initState();
    _verileriVeDonemleriYukle();
  }

  // Türkçe ay ve gün isimlerini düzenli göstermek için yardımcı fonksiyon
  String _donemiFormatla(String donem) {
    try {
      if (donem.length == 7) {
        // Örn: "2026-07" -> "Temmuz 2026"
        List<String> parcalar = donem.split('-');
        int yil = int.parse(parcalar[0]);
        int ay = int.parse(parcalar[1]);
        
        const aylar = [
          '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        return '${aylar[ay]} $yil';
      } else if (donem.length == 10) {
        // Örn: "2026-07-24" -> "24 Temmuz 2026"
        List<String> parcalar = donem.split('-');
        int yil = int.parse(parcalar[0]);
        int ay = int.parse(parcalar[1]);
        int gun = int.parse(parcalar[2]);
        
        const aylar = [
          '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        return '$gun ${aylar[ay]} $yil (Günlük)';
      }
    } catch (e) {
      // Hata durumunda orijinal metni döndür
    }
    return donem;
  }

  Future<void> _verileriVeDonemleriYukle() async {
    try {
      // 1. Tüm işlemleri çekerek veritabanındaki benzersiz ayları VE günleri tespit edelim
      List<Map<String, dynamic>> tumVeriler = await DatabaseHelper.instance.getTransactions();
      
      Set<String> donemSeti = {};
      for (var item in tumVeriler) {
        String tarih = item['date'].toString(); // Beklenen format: YYYY-MM-DD
        if (tarih.length >= 7) {
          donemSeti.add(tarih.substring(0, 7)); // Ay bazlı ekle (Örn: 2026-07)
        }
        if (tarih.length == 10) {
          donemSeti.add(tarih); // Gün bazlı da ekle (Örn: 2026-07-24)
        }
      }

      setState(() {
        // Yeniden eskiye doğru sıralama
        _filtrelenebilirDonemler = donemSeti.toList()..sort((a, b) => b.compareTo(a));
      });

      // 2. Seçili filtreye göre ana listeyi doldur
      List<Map<String, dynamic>> veriler;
      if (_secilenFiltre != null && _secilenFiltre!.isNotEmpty) {
        if (_secilenFiltre!.length == 7) {
          // Ay seçildiyse
          veriler = await DatabaseHelper.instance.getTransactionsByMonth(_secilenFiltre!);
        } else {
          // Gün seçildiyse (YYYY-MM-DD)
          veriler = tumVeriler.where((element) => element['date'] == _secilenFiltre).toList();
        }
      } else {
        veriler = tumVeriler;
      }

      double gelir = 0;
      double gider = 0;

      for (var item in veriler) {
        double tutar = (item['amount'] as num).toDouble();
        if (item['type'] == 'Gelir') {
          gelir += tutar;
        } else {
          gider += tutar;
        }
      }

      setState(() {
        _islemListesi = veriler;
        _toplamGelir = gelir;
        _toplamGider = gider;
        _toplamBakiye = gelir - gider;
      });
    } catch (e) {
      print("Veri yükleme hatası: $e");
    }
  }

  void _islemEkleDialogGoster() {
    final TextEditingController baslikController = TextEditingController();
    final TextEditingController tutarController = TextEditingController();
    String secilenTur = 'Gelir';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni İşlem Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: baslikController,
                      decoration: const InputDecoration(labelText: 'Açıklama (Örn: Maaş, Kira)'),
                    ),
                    TextField(
                      controller: tutarController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tutar (TL)'),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Gelir'),
                          selected: secilenTur == 'Gelir',
                          selectedColor: Colors.green.shade200,
                          onSelected: (selected) {
                            setStateDialog(() {
                              secilenTur = 'Gelir';
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('Gider'),
                          selected: secilenTur == 'Gider',
                          selectedColor: Colors.red.shade200,
                          onSelected: (selected) {
                            setStateDialog(() {
                              secilenTur = 'Gider';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (baslikController.text.isNotEmpty && tutarController.text.isNotEmpty) {
                      double? tutar = double.tryParse(tutarController.text);
                      if (tutar != null) {
                        await DatabaseHelper.instance.insertTransaction({
                          'title': baslikController.text,
                          'amount': tutar,
                          'type': secilenTur,
                          'date': DateTime.now().toString().split(' ')[0],
                        });
                        Navigator.pop(context);
                        await _verileriVeDonemleriYukle();
                      }
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _islemSil(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    _verileriVeDonemleriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa Takip Sistemi'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Gelişmiş Ay/Gün/Dönem Filtreleme Dropdown Alanı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Filtrele: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _secilenFiltre,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    hint: const Text('Tüm Zamanlar'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tüm Zamanlar'),
                      ),
                      ..._filtrelenebilirDonemler.map((donem) {
                        return DropdownMenuItem<String?>(
                          value: donem,
                          child: Text(_donemiFormatla(donem)),
                        );
                      }),
                    ],
                    onChanged: (String? yeniDeger) {
                      setState(() {
                        _secilenFiltre = yeniDeger;
                      });
                      _verileriVeDonemleriYukle();
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ozetKutu('Toplam Bakiye', '${_toplamBakiye.toStringAsFixed(2)} TL', Colors.black),
                _ozetKutu('Gelir', '${_toplamGelir.toStringAsFixed(2)} TL', Colors.green),
                _ozetKutu('Gider', '${_toplamGider.toStringAsFixed(2)} TL', Colors.red),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'İşlem Listesi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _islemListesi.isEmpty
                ? const Center(child: Text('Bu dönemde kayıt bulunamadı.'))
                : ListView.builder(
                    itemCount: _islemListesi.length,
                    itemBuilder: (context, index) {
                      final islem = _islemListesi[index];
                      bool gelirMi = islem['type'] == 'Gelir';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: gelirMi ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              gelirMi ? Icons.arrow_downward : Icons.arrow_upward,
                              color: gelirMi ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(islem['title']),
                          subtitle: Text(_donemiFormatla(islem['date'])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${gelirMi ? '+' : '-'}${islem['amount']} TL',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: gelirMi ? Colors.green : Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.grey),
                                onPressed: () => _islemSil(islem['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _islemEkleDialogGoster,
        label: const Text('İşlem Ekle'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _ozetKutu(String baslik, String deger, Color renk) {
    return Column(
      children: [
        Text(baslik, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(deger, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk)),
      ],
    );
  }
}