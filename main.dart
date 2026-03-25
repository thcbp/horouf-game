import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:async'; 

// =================== مدير قاعدة البيانات (السحابة) ===================
class FirebaseManager {
  static const String dbUrl = "https://horuf-game-default-rtdb.firebaseio.com";
  static String roomCode = "";

  static Future<void> createRoom(String t1, String t2) async {
    roomCode = (Random().nextInt(9000) + 1000).toString(); 
    try {
      var url = Uri.parse("$dbUrl/rooms/$roomCode.json");
      var request = await HttpClient().putUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        "state": "waiting",
        "buzzerTeam": "",
        "buzzerName": "",
        "lock1": false,
        "lock2": false,
        "team1": t1,
        "team2": t2
      }));
      await request.close();
    } catch (e) {
      print("Firebase Error: $e");
    }
  }

  static Future<void> updateRoom({
    required String state,
    required String buzzerTeam,
    required String buzzerName,
    required bool lock1,
    required bool lock2,
  }) async {
    if (roomCode.isEmpty) return;
    try {
      var url = Uri.parse("$dbUrl/rooms/$roomCode.json");
      var request = await HttpClient().patchUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        "state": state,
        "buzzerTeam": buzzerTeam,
        "buzzerName": buzzerName,
        "lock1": lock1,
        "lock2": lock2,
      }));
      await request.close();
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> fetchRoom() async {
    if (roomCode.isEmpty) return null;
    try {
      var url = Uri.parse("$dbUrl/rooms/$roomCode.json");
      var request = await HttpClient().getUrl(url);
      var response = await request.close();
      var responseBody = await response.transform(utf8.decoder).join();
      return jsonDecode(responseBody);
    } catch (e) {
      return null;
    }
  }
}

// =================== سيرفر الهوست السري ===================
class HostServer {
  static String currentLetter = "-";
  static String currentQuestion = "اختر حرفاً لتبدأ اللعبة";
  static String currentAnswer = "في انتظار اختيار الحرف...";

  static Future<void> start() async {
    try {
      var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      await for (HttpRequest request in server) {
        if (request.uri.path == '/api/current') {
          request.response
            ..headers.contentType = ContentType.json
            ..headers.add('Access-Control-Allow-Origin', '*')
            ..write(jsonEncode({
              'letter': currentLetter,
              'question': currentQuestion,
              'answer': currentAnswer
            }))
            ..close();
        } else {
          request.response
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html lang="ar" dir="rtl">
              <head>
                <meta charset="UTF-8">
                <title>لوحة تحكم المضيف</title>
                <style>
                  body { font-family: 'Segoe UI', Tahoma, sans-serif; background-color: #4A148C; color: white; text-align: center; padding: 50px; }
                  .card { background-color: #311B92; padding: 40px; border-radius: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.5); display: inline-block; min-width: 60%; border: 3px solid #7E57C2; }
                  h1 { color: #FFCA28; font-size: 40px; }
                  .letter { font-size: 100px; font-weight: bold; color: #40C4FF; margin-bottom: 20px; }
                  .question { font-size: 35px; margin-bottom: 30px; line-height: 1.6; }
                  .answer { font-size: 45px; color: #69F0AE; font-weight: bold; padding: 20px; border: 3px dashed #69F0AE; border-radius: 15px; background-color: rgba(105,240,174,0.1); }
                </style>
                <script>
                  setInterval(async () => {
                    try {
                      let res = await fetch('/api/current');
                      let data = await res.json();
                      document.getElementById('letter').innerText = data.letter;
                      document.getElementById('question').innerText = data.question;
                      document.getElementById('answer').innerText = data.answer;
                    } catch (e) {}
                  }, 1000);
                </script>
              </head>
              <body>
                <div class="card">
                  <h1>شاشة المضيف (سرية) 🤫</h1>
                  <div class="letter" id="letter">-</div>
                  <div class="question" id="question">في انتظار اختيار الحرف...</div>
                  <div class="answer" id="answer">-</div>
                </div>
              </body>
              </html>
            ''')
            ..close();
        }
      }
    } catch (e) {}
  }

  static void updateData(String letter, String question, String answer) {
    currentLetter = letter;
    currentQuestion = question;
    currentAnswer = answer;
  }
}

// =================== نظام الذاكرة للحفظ ===================
class DataManager {
  static final File _file = File('question_bank.json');
  static final File _historyFile = File('games_history.json');

  static Future<void> loadAll() async {
    await loadBank();
    await loadHistory();
  }

  static Future<void> loadBank() async {
    try {
      if (await _file.exists()) {
        String contents = await _file.readAsString();
        Map<String, dynamic> decoded = jsonDecode(contents);
        GlobalData.questionBank.clear();
        decoded.forEach((key, value) {
          GlobalData.questionBank[key] = [];
          for (var item in value) {
            GlobalData.questionBank[key]!.add({'q': item['q'].toString(), 'a': item['a'].toString()});
          }
        });
      }
      _shuffleAllQuestions();
    } catch (e) {}
  }

  static Future<void> saveBank() async {
    try {
      await _file.writeAsString(jsonEncode(GlobalData.questionBank));
    } catch (e) {}
  }

  static Future<void> loadHistory() async {
    try {
      if (await _historyFile.exists()) {
        String contents = await _historyFile.readAsString();
        List<dynamic> decoded = jsonDecode(contents);
        GlobalData.gamesHistory = decoded.map((e) {
          Map<String, dynamic> map = Map<String, dynamic>.from(e);
          map['board'] = List<int>.from(map['board']);
          map['letters'] = List<String>.from(map['letters']);
          return map;
        }).toList();
      }
    } catch (e) {}
  }

  static Future<void> saveHistory() async {
    try {
      await _historyFile.writeAsString(jsonEncode(GlobalData.gamesHistory));
    } catch (e) {}
  }

  static void _shuffleAllQuestions() {
    GlobalData.questionBank.forEach((key, list) => list.shuffle(Random()));
    GlobalData.letterQuestionIndex.clear();
  }

  static void resetAndShuffleBank() => _shuffleAllQuestions();
}

class GlobalData {
  static Map<String, List<Map<String, String>>> questionBank = {};
  static Map<String, int> letterQuestionIndex = {}; 
  static List<Map<String, dynamic>> gamesHistory = []; 
  static final List<String> allArabicLetters = [
    'أ','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص',
    'ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','هـ','و','ي'
  ];
}

// =================== أداة رسم العلامة المائية ===================
class HexagonPatternPainter extends CustomPainter {
  final Color color;
  final double opacity;
  HexagonPatternPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    double radius = 50;
    double width = radius * 1.732;
    double height = radius * 2;

    for (double y = 0; y < size.height + height; y += height * 0.75) {
      bool isOdd = (y / (height * 0.75)).round() % 2 != 0;
      for (double x = 0; x < size.width + width; x += width) {
        double cx = x + (isOdd ? width / 2 : 0);
        double cy = y;
        _drawHexagon(canvas, Offset(cx, cy), radius, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (pi / 3) * i - (pi / 6);
      double px = center.dx + radius * cos(angle);
      double py = center.dy + radius * sin(angle);
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; 
  }
}

// =================== بداية التطبيق ===================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: 'لعبة الحروف', 
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  HostServer.start();
  await DataManager.loadAll();

  runApp(const HoroufGameApp());
}

class HoroufGameApp extends StatelessWidget {
  const HoroufGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'لعبة الحروف',
      theme: ThemeData(
        brightness: Brightness.dark, 
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF673AB7), 
        colorScheme: const ColorScheme.dark(
          primary: Colors.orangeAccent,
          surface: Color(0xFF512DA8),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// =================== القائمة الرئيسية ===================
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _showStartSettings(BuildContext context) {
    TextEditingController hostController = TextEditingController(text: "عزيز");
    TextEditingController t1Controller = TextEditingController(text: "البرتقالي");
    TextEditingController t2Controller = TextEditingController(text: "الأخضر");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24, width: 2)),
          title: Text('⚙️ إعدادات الجولة الجديدة', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: hostController, decoration: const InputDecoration(labelText: 'اسم المضيف', labelStyle: TextStyle(color: Colors.white70))),
                const SizedBox(height: 10),
                TextField(controller: t1Controller, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'اسم الفريق 1 (أفقي ↔)', labelStyle: TextStyle(color: Colors.orangeAccent))),
                const SizedBox(height: 10),
                TextField(controller: t2Controller, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'اسم الفريق 2 (عمودي ↕)', labelStyle: TextStyle(color: Colors.greenAccent))),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: Text('انطلق للعب!', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () async {
                await FirebaseManager.createRoom(t1Controller.text, t2Controller.text);

                String newId = DateTime.now().millisecondsSinceEpoch.toString();
                Map<String, dynamic> newGame = {
                  'id': newId,
                  'date': "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')} | ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')}",
                  'host': hostController.text.isNotEmpty ? hostController.text : "عزيز",
                  'team1': t1Controller.text.isNotEmpty ? t1Controller.text : "البرتقالي",
                  'team2': t2Controller.text.isNotEmpty ? t2Controller.text : "الأخضر",
                  'board': List.filled(25, 0),
                  'letters': (List.of(GlobalData.allArabicLetters)..shuffle(Random())).take(25).toList(),
                  'winner': 0,
                  'color1': Colors.orange.value, 
                  'color2': Colors.green.value,
                };
                GlobalData.gamesHistory.add(newGame);
                DataManager.saveHistory();

                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => GameBoardScreen(
                    hostName: newGame['host'], team1Name: newGame['team1'], team2Name: newGame['team2'], gameData: newGame
                )));
              },
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54)))
          ],
        );
      }
    );
  }

  void _showGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF4A148C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('دليل المضيف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            const Icon(Icons.lightbulb, color: Colors.amber, size: 30),
          ],
        ),
        content: Directionality( 
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1️⃣ الشاشة السرية:', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('انسخ رابط المضيف والصقه في متصفحك. هذه الشاشة لك وحدك لتقرأ الإجابات.\n', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                Text('2️⃣ التعديل والتخصيص:', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('اضغط على أيقونة الإعدادات العلوية أثناء اللعب لتغيير ألوان الفرق.\n', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                Text('3️⃣ تصحيح الأخطاء:', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('أخطأت في إعطاء النقطة؟ اضغط على الخلية لتعديلها أو مسحها.', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), onPressed: () => Navigator.pop(ctx), child: Text('فهمت، شكراً!', style: GoogleFonts.cairo(color: Colors.white)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF673AB7), 
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: HexagonPatternPainter(color: Colors.white, opacity: 0.08),
            ),
          ),
          Positioned(
            top: 20, right: 20,
            child: IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white, size: 40), tooltip: 'ملء الشاشة', onPressed: () async {
                bool isFull = await windowManager.isFullScreen();
                windowManager.setFullScreen(!isFull);
            }),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(50),
              decoration: BoxDecoration(
                color: const Color(0xFF512DA8).withOpacity(0.9), 
                borderRadius: BorderRadius.circular(30), 
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.05,
                    child: Text('لعبة الحروف', style: GoogleFonts.lalezar(fontSize: 85, color: Colors.white, shadows: [const Shadow(color: Color(0xFF311B92), blurRadius: 0, offset: Offset(4, 5))])),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('شاشة المضيف:  http://localhost:8080', style: GoogleFonts.cairo(fontSize: 20, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 20),
                        IconButton(icon: const Icon(Icons.copy, color: Colors.white), tooltip: 'نسخ رابط الشاشة السرية', onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'http://localhost:8080'));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ رابط شاشة المضيف!', style: GoogleFonts.cairo(fontSize: 16)), backgroundColor: Colors.green));
                        })
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: 350, height: 70,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 8),
                      icon: const Icon(Icons.play_circle_fill, size: 35, color: Colors.white),
                      label: Text('ابدأ اللعبة', style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => _showStartSettings(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E57C2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.storage, size: 28, color: Colors.white),
                      label: Text('بنك الأسئلة', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen())),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.history, size: 28, color: Colors.white),
                      label: Text('السجل والأقيام', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4527A0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.help_outline, size: 28, color: Colors.amberAccent),
                      label: Text('دليل المضيف', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => _showGuideDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== شاشة السجل ===================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> history = GlobalData.gamesHistory.reversed.toList(); 
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C), 
        elevation: 0, 
        title: Text('سجل الجولات السابقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), 
        centerTitle: true
      ),
      body: history.isEmpty 
        ? Center(child: Text('لا توجد جولات محفوظة حالياً', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 24)))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: history.length,
            itemBuilder: (context, index) {
              var game = history[index];
              int winner = game['winner'] ?? 0;
              String status = winner == 1 ? '🏆 فاز ${game['team1']}' : (winner == 2 ? '🏆 فاز ${game['team2']}' : '⏳ جولة قيد اللعب / غير مكتملة');
              Color statusColor = winner == 1 ? Colors.orangeAccent : (winner == 2 ? Colors.greenAccent : Colors.grey);

              return Card(
                color: const Color(0xFF512DA8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white10)), 
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  title: Text('${game['team1']} 🆚 ${game['team2']}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('المضيف: ${game['host']} | التاريخ: ${game['date']}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(status, style: GoogleFonts.cairo(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: Text('استكمال', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await FirebaseManager.createRoom(game['team1'], game['team2']);
                          
                          Navigator.push(context, MaterialPageRoute(builder: (context) => GameBoardScreen(
                              hostName: game['host'], team1Name: game['team1'], team2Name: game['team2'], gameData: game
                          )));
                        },
                      ),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 30),
                        tooltip: 'حذف الجولة',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF4A148C),
                              title: Text('حذف الجولة؟', style: GoogleFonts.cairo(color: Colors.white)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => GlobalData.gamesHistory.removeWhere((g) => g['id'] == game['id']));
                                    DataManager.saveHistory();
                                    Navigator.pop(ctx);
                                  },
                                  child: Text('نعم، احذف', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
                                )
                              ]
                            )
                          );
                        }
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

// =================== بنك الأسئلة ===================
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});
  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  Map<String, List<Map<String, String>>> backupBank = {};

  void _showQuestionDialog({String? letter, int? index, String? initialQ, String? initialA}) {
    String selectedLetter = letter ?? 'أ';
    TextEditingController qController = TextEditingController(text: initialQ ?? '');
    TextEditingController aController = TextEditingController(text: initialA ?? '');
    bool isEditing = index != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF4A148C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
              title: Text(isEditing ? 'تعديل السؤال' : 'إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLetter,
                    dropdownColor: const Color(0xFF512DA8),
                    style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    items: GlobalData.allArabicLetters.map((String value) => DropdownMenuItem<String>(value: value, child: Text("حرف ( $value )"))).toList(),
                    onChanged: isEditing ? null : (newValue) => setDialogState(() => selectedLetter = newValue!),
                  ),
                  TextField(controller: qController, style: GoogleFonts.cairo(color: Colors.white), decoration: const InputDecoration(labelText: 'السؤال', labelStyle: TextStyle(color: Colors.white70))),
                  TextField(controller: aController, style: GoogleFonts.cairo(color: Colors.greenAccent), decoration: const InputDecoration(labelText: 'الإجابة', labelStyle: TextStyle(color: Colors.greenAccent))),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                  onPressed: () async {
                    if (qController.text.isNotEmpty && aController.text.isNotEmpty) {
                      setState(() {
                        if (!GlobalData.questionBank.containsKey(selectedLetter)) GlobalData.questionBank[selectedLetter] = [];
                        if (isEditing) {
                          GlobalData.questionBank[selectedLetter]![index] = {'q': qController.text, 'a': aController.text};
                        } else {
                          GlobalData.questionBank[selectedLetter]!.add({'q': qController.text, 'a': aController.text});
                        }
                      });
                      await DataManager.saveBank();
                      Navigator.pop(context);
                    }
                  },
                  child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _deleteQuestion(String letter, int index) {
    setState(() => GlobalData.questionBank[letter]!.removeAt(index));
    DataManager.saveBank();
  }

  void _clearAllQuestions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF4A148C),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
            SizedBox(width: 10),
            Text('تحذير خطير!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل أنت متأكد أنك تريد حذف جميع الأسئلة من التطبيق؟', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              backupBank.clear();
              GlobalData.questionBank.forEach((k, v) => backupBank[k] = List.from(v.map((item) => Map<String, String>.from(item))));
              setState(() => GlobalData.questionBank.clear());
              await DataManager.saveBank();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم مسح جميع الأسئلة بنجاح!', style: GoogleFonts.cairo(fontSize: 16)), backgroundColor: const Color(0xFF512DA8), duration: const Duration(seconds: 7), action: SnackBarAction(label: 'تراجع ↩️', textColor: Colors.orangeAccent, onPressed: () async { setState(() => GlobalData.questionBank = Map.from(backupBank)); await DataManager.saveBank(); })));
            },
            child: Text('نعم، احذف الكل', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  void _importFromJsonFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        Map<String, dynamic> decoded = jsonDecode(contents);
        setState(() {
          decoded.forEach((key, value) {
            if (!GlobalData.questionBank.containsKey(key)) GlobalData.questionBank[key] = [];
            for (var item in value) GlobalData.questionBank[key]!.add({'q': item['q'].toString(), 'a': item['a'].toString()});
          });
        });
        await DataManager.saveBank();
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم استيراد الملف الجاهز بنجاح!', style: GoogleFonts.cairo()), backgroundColor: Colors.green)); }
      }
    } catch (e) {}
  }

  void _showImportDialog() {
    TextEditingController jsonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
          title: Text('استيراد الأسئلة', style: GoogleFonts.cairo(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: double.maxFinite, child: TextField(controller: jsonController, maxLines: 7, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'الصق كود JSON هنا...', border: OutlineInputBorder()))),
              const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('--- أو ---', style: TextStyle(color: Colors.white54))),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E57C2), padding: const EdgeInsets.symmetric(vertical: 15)), icon: const Icon(Icons.folder_open, color: Colors.white), label: Text('استيراد من ملف JSON جاهز', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)), onPressed: _importFromJsonFile)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                if (jsonController.text.isEmpty) return;
                try {
                  Map<String, dynamic> decoded = jsonDecode(jsonController.text);
                  setState(() {
                    decoded.forEach((key, value) {
                      if (!GlobalData.questionBank.containsKey(key)) GlobalData.questionBank[key] = [];
                      for (var item in value) GlobalData.questionBank[key]!.add({'q': item['q'].toString(), 'a': item['a'].toString()});
                    });
                  });
                  await DataManager.saveBank();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الاستيراد بنجاح!', style: GoogleFonts.cairo())));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في صيغة الـ JSON المنسوخة!', style: GoogleFonts.cairo()), backgroundColor: Colors.red));
                }
              },
              child: Text('حفظ النص المنسوخ', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        elevation: 0,
        title: Text('بنك الأسئلة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_on, color: Colors.greenAccent, size: 28), 
            tooltip: 'خلط وإعادة تعيين الأسئلة', 
            onPressed: () {
              DataManager.resetAndShuffleBank();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم خلط الأسئلة! ستبدأ الآن بأسئلة جديدة للجميع.', style: GoogleFonts.cairo(fontSize: 16)), backgroundColor: Colors.green));
            }
          ),
          IconButton(icon: const Icon(Icons.data_object, color: Colors.blueAccent, size: 28), tooltip: 'استيراد', onPressed: _showImportDialog),
          IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28), tooltip: 'حذف الكل', onPressed: _clearAllQuestions),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.orangeAccent, icon: const Icon(Icons.add, color: Colors.white), label: Text('إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), onPressed: () => _showQuestionDialog()),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: GlobalData.allArabicLetters.length,
        itemBuilder: (context, index) {
          String letter = GlobalData.allArabicLetters[index];
          List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
          return Card(
            color: const Color(0xFF512DA8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('حرف ( $letter )', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              subtitle: Text('عدد الأسئلة: ${questions.length}', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16)),
              children: questions.asMap().entries.map((entry) {
                int qIndex = entry.key; var q = entry.value;
                return ListTile(
                  title: Text(q['q']!, style: GoogleFonts.cairo(color: Colors.white, fontSize: 20)),
                  subtitle: Text('الإجابة: ${q['a']}', style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 18)),
                  leading: const Icon(Icons.help_outline, color: Colors.orangeAccent),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _showQuestionDialog(letter: letter, index: qIndex, initialQ: q['q'], initialA: q['a'])),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteQuestion(letter, qIndex)),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// =================== لوحة اللعب ===================
class GameBoardScreen extends StatefulWidget {
  final String hostName;
  final String team1Name;
  final String team2Name;
  final Map<String, dynamic> gameData; 
  
  const GameBoardScreen({super.key, required this.hostName, required this.team1Name, required this.team2Name, required this.gameData});
  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class Point {
  final int r, c;
  Point(this.r, this.c);
  @override bool operator ==(Object other) => other is Point && other.r == r && other.c == c;
  @override int get hashCode => r.hashCode ^ c.hashCode;
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final int rows = 5;
  final int cols = 5;
  late List<List<int>> board;
  late List<String> currentLetters;
  
  late Color colorTeam1;
  late Color colorTeam2;

  // متغير للتحكم بإظهار/إخفاء كود الغرفة في الشريط العلوي (وضع الستريمر)
  bool isRoomCodeHidden = false;

  @override
  void initState() {
    super.initState();
    List<int> flatBoard = widget.gameData['board'];
    board = List.generate(rows, (r) => List.generate(cols, (c) => flatBoard[r * cols + c]));
    currentLetters = widget.gameData['letters'];
    
    colorTeam1 = widget.gameData['color1'] != null ? Color(widget.gameData['color1']) : Colors.orange;
    colorTeam2 = widget.gameData['color2'] != null ? Color(widget.gameData['color2']) : Colors.green;
  }

  void _resetGame() {
    setState(() {
      board = List.generate(rows, (_) => List.filled(cols, 0));
      List<String> shuffled = List.of(GlobalData.allArabicLetters)..shuffle(Random());
      currentLetters = shuffled.take(25).toList();
      widget.gameData['board'] = List.filled(25, 0);
      widget.gameData['letters'] = currentLetters;
      widget.gameData['winner'] = 0;
      DataManager.saveHistory();
    });
    HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-");
  }

  void _showGameSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إعدادات الألوان', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لون ${widget.team1Name}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [Colors.orange, Colors.red, Colors.pink, Colors.purple].map((c) => GestureDetector(
                  onTap: () { setState(() { colorTeam1 = c; widget.gameData['color1'] = c.value; DataManager.saveHistory(); Navigator.pop(ctx); }); },
                  child: CircleAvatar(backgroundColor: c, radius: 20),
                )).toList(),
              ),
              const Divider(color: Colors.white24, height: 30),
              Text('لون ${widget.team2Name}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [Colors.green, Colors.blue, Colors.cyan, Colors.teal].map((c) => GestureDetector(
                  onTap: () { setState(() { colorTeam2 = c; widget.gameData['color2'] = c.value; DataManager.saveHistory(); Navigator.pop(ctx); }); },
                  child: CircleAvatar(backgroundColor: c, radius: 20),
                )).toList(),
              ),
            ],
          ),
        );
      }
    );
  }

  void _handleHexagonTap(int r, int c) {
    if (board[r][c] == 0) {
      _showSafeQuestionDialog(r, c);
    } else {
      _showEditHexagonDialog(r, c);
    }
  }

  void _showEditHexagonDialog(int r, int c) {
    String letter = currentLetters[r * cols + c];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF311B92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
        title: Text('تعديل خلية الحرف ( $letter )', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorTeam1),
            onPressed: () { Navigator.pop(ctx); _makeMove(r, c, 1); },
            child: Text('لـ ${widget.team1Name}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { 
              Navigator.pop(ctx); 
              setState(() {
                board[r][c] = 0;
                List<int> flatBoard = [];
                for (var row in board) { flatBoard.addAll(row); }
                widget.gameData['board'] = flatBoard;
                widget.gameData['winner'] = 0;
                DataManager.saveHistory(); 
              }); 
            },
            child: Text('مسح الخلية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorTeam2),
            onPressed: () { Navigator.pop(ctx); _makeMove(r, c, 2); },
            child: Text('لـ ${widget.team2Name}', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  // =================== نافذة السؤال الذكية مع الـ 5 ثواني ونظام الأسماء ===================
  void _showSafeQuestionDialog(int r, int c) {
    int index = r * cols + c;
    String letter = currentLetters[index];
    
    List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
    if (questions.isEmpty) questions = [{'q': 'لم تقم بإضافة أسئلة لحرف ( $letter )!', 'a': 'لا يوجد'}];

    int currentQIndex = GlobalData.letterQuestionIndex[letter] ?? 0;
    if (currentQIndex >= questions.length) currentQIndex = 0; 
    bool isAnswerRevealed = false;

    int? activeBuzzerTeam;
    String activeBuzzerName = "";
    int answerTime = 5;
    int penalty1 = 0;
    int penalty2 = 0;
    Timer? secTimer;
    Timer? pollingTimer;

    HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            void cleanup() {
              pollingTimer?.cancel();
              secTimer?.cancel();
              FirebaseManager.updateRoom(state: "waiting", buzzerTeam: "", buzzerName: "", lock1: false, lock2: false);
            }

            void triggerWrongAnswer() {
              int failedTeam = activeBuzzerTeam!;
              activeBuzzerTeam = null;
              activeBuzzerName = "";
              
              if (failedTeam == 1) penalty1 = 10;
              if (failedTeam == 2) penalty2 = 10;
              
              // التكتيك الذكي: لو الفريقين تجاوبوا خطأ، تتكنسل كل العقوبات فوراً
              if (penalty1 > 0 && penalty2 > 0) {
                  penalty1 = 0;
                  penalty2 = 0;
              }
              
              FirebaseManager.updateRoom(state: "question", buzzerTeam: "", buzzerName: "", lock1: penalty1 > 0, lock2: penalty2 > 0);
            }

            if (secTimer == null) {
              FirebaseManager.updateRoom(state: "question", buzzerTeam: "", buzzerName: "", lock1: false, lock2: false);
              
              secTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                bool needsUpdate = false;
                setDialogState(() {
                  if (activeBuzzerTeam != null) {
                    if (answerTime > 0) answerTime--;
                    else triggerWrongAnswer();
                  }

                  if (penalty1 > 0) {
                    penalty1--;
                    if (penalty1 == 0) needsUpdate = true;
                  }
                  if (penalty2 > 0) {
                    penalty2--;
                    if (penalty2 == 0) needsUpdate = true;
                  }
                });
                if (needsUpdate) {
                  FirebaseManager.updateRoom(state: "question", buzzerTeam: "", buzzerName: "", lock1: penalty1 > 0, lock2: penalty2 > 0);
                }
              });

              pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
                if (activeBuzzerTeam != null) return;
                var data = await FirebaseManager.fetchRoom();
                if (data != null && data["buzzerTeam"] != "") {
                  String bTeam = data["buzzerTeam"];
                  if ((bTeam == "team1" && penalty1 == 0) || (bTeam == "team2" && penalty2 == 0)) {
                      setDialogState(() {
                          activeBuzzerTeam = bTeam == "team1" ? 1 : 2;
                          activeBuzzerName = data["buzzerName"] ?? "لاعب";
                          answerTime = 5;
                      });
                  }
                }
              });
            }

            Color borderColor = activeBuzzerTeam == 1 ? colorTeam1 : (activeBuzzerTeam == 2 ? colorTeam2 : Colors.white24);
            String teamName = activeBuzzerTeam == 1 ? widget.team1Name : widget.team2Name;

            return AlertDialog(
              backgroundColor: const Color(0xFF311B92),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: borderColor, width: activeBuzzerTeam != null ? 6 : 2)),
              contentPadding: const EdgeInsets.all(30),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activeBuzzerTeam != null)
                      Column(
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              '($activeBuzzerName) من فريق $teamName يجاوب! 🏃‍♂️', 
                              textAlign: TextAlign.center, 
                              style: GoogleFonts.cairo(fontSize: 32, color: borderColor, fontWeight: FontWeight.bold)
                            ),
                          ),
                          const SizedBox(height: 20),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(width: 80, height: 80, child: CircularProgressIndicator(value: answerTime / 5, color: borderColor, strokeWidth: 8)),
                              Text('$answerTime', style: GoogleFonts.cairo(fontSize: 40, color: borderColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A148C)),
                            child: Text(letter, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 15),
                          if (penalty1 > 0 || penalty2 > 0)
                             Column(
                               children: [
                                 if (penalty1 > 0) Directionality(textDirection: TextDirection.rtl, child: Text('عقوبة ${widget.team1Name}: $penalty1 ثواني 🚫', style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                                 if (penalty2 > 0) Directionality(textDirection: TextDirection.rtl, child: Text('عقوبة ${widget.team2Name}: $penalty2 ثواني 🚫', style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                               ],
                             )
                          else
                             Directionality(
                               textDirection: TextDirection.rtl, 
                               child: Text('🔔 بانتظار ضغطة الجرس...', style: GoogleFonts.cairo(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold))
                             ),
                        ],
                      ),
                      
                    const SizedBox(height: 20),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(questions[currentQIndex]['q']!, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.5))
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(color: isAnswerRevealed ? Colors.black26 : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(isAnswerRevealed ? 'الإجابة: ${questions[currentQIndex]['a']}' : '--- الإجابة مخفية ---', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: isAnswerRevealed ? Colors.amberAccent : Colors.white38, fontSize: 26, fontWeight: FontWeight.bold))
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    if (activeBuzzerTeam == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: Text('تغيير السؤال', style: GoogleFonts.cairo(color: Colors.white, fontSize: 20)),
                            onPressed: () {
                              setDialogState(() {
                                currentQIndex = (currentQIndex + 1) % questions.length;
                                GlobalData.letterQuestionIndex[letter] = currentQIndex; 
                                isAnswerRevealed = false;
                                penalty1 = 0; penalty2 = 0;
                                HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);
                                FirebaseManager.updateRoom(state: "question", buzzerTeam: "", buzzerName: "", lock1: false, lock2: false);
                              });
                            },
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            icon: Icon(isAnswerRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                            label: Text(isAnswerRevealed ? 'إخفاء' : 'إظهار', style: GoogleFonts.cairo(color: Colors.white, fontSize: 20)),
                            onPressed: () => setDialogState(() => isAnswerRevealed = !isAnswerRevealed),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: activeBuzzerTeam != null 
              ? [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    icon: const Icon(Icons.check_circle, color: Colors.white, size: 30),
                    label: Text('إجابة صحيحة', style: GoogleFonts.cairo(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () { 
                      cleanup(); 
                      GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length; 
                      Navigator.pop(ctx); 
                      _makeMove(r, c, activeBuzzerTeam!); 
                      HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); 
                    },
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                    label: Text('إجابة خاطئة', style: GoogleFonts.cairo(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () { 
                      setDialogState(() { triggerWrongAnswer(); });
                    },
                  ),
                ]
              : [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorTeam1, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    onPressed: () { cleanup(); GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length; Navigator.pop(ctx); _makeMove(r, c, 1); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                    child: Text('فوز ${widget.team1Name}', style: GoogleFonts.cairo(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 45), onPressed: () { cleanup(); Navigator.pop(ctx); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); }),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorTeam2, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    onPressed: () { cleanup(); GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length; Navigator.pop(ctx); _makeMove(r, c, 2); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                    child: Text('فوز ${widget.team2Name}', style: GoogleFonts.cairo(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
            );
          }
        );
      }
    );
  }

  void _makeMove(int r, int c, int player) {
    setState(() => board[r][c] = player);
    List<int> flatBoard = [];
    for (var row in board) { flatBoard.addAll(row); }
    widget.gameData['board'] = flatBoard;
    DataManager.saveHistory(); 

    if (_checkWin(player)) {
      widget.gameData['winner'] = player;
      DataManager.saveHistory();
      
      String winnerName = player == 1 ? widget.team1Name : widget.team2Name;
      Color teamColor = player == 1 ? colorTeam1 : colorTeam2;
      Future.delayed(const Duration(milliseconds: 300), () => _showWinDialog(winnerName, teamColor));
    }
  }

  bool _checkWin(int player) {
    List<Point> starts = [];
    if (player == 1) { for (int r = 0; r < rows; r++) if (board[r][0] == 1) starts.add(Point(r, 0)); }
    else { for (int c = 0; c < cols; c++) if (board[0][c] == 2) starts.add(Point(0, c)); }
    Set<Point> visited = {};
    for (var start in starts) { if (_dfs(start, player, visited)) return true; }
    return false;
  }

  bool _dfs(Point p, int player, Set<Point> visited) {
    if (player == 1 && p.c == cols - 1) return true;
    if (player == 2 && p.r == rows - 1) return true;
    visited.add(p);
    bool isOdd = p.r % 2 != 0;
    List<List<int>> dirs = isOdd ? [[-1, 0], [-1, 1], [0, -1], [0, 1], [1, 0], [1, 1]] : [[-1, -1], [-1, 0], [0, -1], [0, 1], [1, -1], [1, 0]];
    for (var d in dirs) {
      int nr = p.r + d[0], nc = p.c + d[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        Point nextPoint = Point(nr, nc);
        if (board[nr][nc] == player && !visited.contains(nextPoint)) { if (_dfs(nextPoint, player, visited)) return true; }
      }
    }
    return false;
  }

  void _showWinDialog(String winnerName, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF311B92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color, width: 4)),
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text('🏆 مبروك!', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: color, fontSize: 50, fontWeight: FontWeight.bold)),
            Positioned(left: 0, top: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 40), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
        content: Text('الفائز هو: $winnerName', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontSize: 35)),
      )
    );
  }

  Widget buildHostTitle() {
    return Transform.rotate(
      angle: -0.05, 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('حروف', style: GoogleFonts.lalezar(fontSize: 100, color: const Color(0xFFFFD700), height: 0.8, shadows: [const Shadow(color: Colors.black87, offset: Offset(3, 4), blurRadius: 0)])),
          Text(widget.hostName, style: GoogleFonts.lalezar(fontSize: 85, color: const Color(0xFFFF3D00), height: 0.8, shadows: [const Shadow(color: Colors.black87, offset: Offset(3, 4), blurRadius: 0)])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), 
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // الشريط العلوي مع ترتيب الرابط في الزاوية اليمنى القصوى
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: const Color(0x9912121A), 
                  child: Row(
                    children: [
                      // القسم الأيسر: زر العودة والفريق الأول
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 30), onPressed: () => Navigator.pop(context)),
                          const SizedBox(width: 5),
                          Text(widget.team1Name, style: GoogleFonts.cairo(color: colorTeam1, fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // القسم الأيمن (تم نقل الرابط والأدوات للزاوية اليمنى)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.team2Name, style: GoogleFonts.cairo(color: colorTeam2, fontSize: 26, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          IconButton(icon: const Icon(Icons.settings, color: Colors.white, size: 30), tooltip: 'تغيير ألوان الفرق', onPressed: _showGameSettings),
                          IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 30), onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF4A148C),
                                title: Text('إعادة الجولة', style: GoogleFonts.cairo(color: Colors.white)),
                                content: Text('هل تريد تصفير اللوحة؟', style: GoogleFonts.cairo(color: Colors.white)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
                                  ElevatedButton(onPressed: () { Navigator.pop(ctx); _resetGame(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: Text('تصفير', style: GoogleFonts.cairo(color: Colors.white))),
                                ]
                              )
                            );
                          }),
                          Container(width: 2, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 10)),
                          
                          // الرابط وكود الغرفة وزر الإخفاء (وضع الستريمر) 👁️
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Text('horufgame.netlify.app', style: GoogleFonts.cairo(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(const ClipboardData(text: 'https://horufgame.netlify.app'));
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ رابط اللاعبين!', style: GoogleFonts.cairo()), backgroundColor: Colors.green));
                                    },
                                    child: const Icon(Icons.copy, size: 18, color: Colors.white70),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  Text('كود الغرفة:', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14)),
                                  const SizedBox(width: 5),
                                  SelectableText(isRoomCodeHidden ? '••••' : FirebaseManager.roomCode, style: GoogleFonts.cairo(color: Colors.greenAccent, fontSize: 18, letterSpacing: isRoomCodeHidden ? 5 : 3, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 5),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        isRoomCodeHidden = !isRoomCodeHidden;
                                      });
                                    },
                                    child: Icon(isRoomCodeHidden ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.white70),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double maxR_byHeight = (constraints.maxHeight * 0.76) / 8.0; 
                      double maxR_byWidth = (constraints.maxWidth * 0.96) / 9.526;
                      double radius = min(maxR_byHeight, maxR_byWidth);
                      
                      if (radius < 90.0) radius = 105.0; 
                      radius = radius.clamp(60.0, 145.0);

                      double width = radius * 1.732;
                      double height = radius * 2;
                      double totalWidth = cols * width + (width / 2);
                      double totalHeight = (rows * height * 0.75) + (height * 0.25);

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: FourTrianglesPainter(colorTeam1, colorTeam2)),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: HexagonPatternPainter(color: Colors.white, opacity: 0.15),
                            ),
                          ),
                          Align(
                            alignment: const Alignment(0.0, 0.15), 
                            child: SizedBox(
                              width: totalWidth,
                              height: totalHeight,
                              child: Stack(
                                children: List.generate(rows * cols, (index) {
                                  int r = index ~/ cols;
                                  int c = index % cols;
                                  double x = c * width + (r % 2 != 0 ? width / 2 : 0);
                                  double y = r * height * 0.75;
                                  return Positioned(
                                    left: x, top: y,
                                    child: GestureDetector(
                                      onTap: () => _handleHexagonTap(r, c),
                                      child: HexagonWidget(
                                        letter: currentLetters[index], 
                                        state: board[r][c], 
                                        width: width, 
                                        height: height,
                                        radius: radius, 
                                        c1: colorTeam1,
                                        c2: colorTeam2,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 5, 
              left: 0, 
              right: 0,
              child: Center(
                child: IgnorePointer(
                  child: buildHostTitle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FourTrianglesPainter extends CustomPainter {
  final Color c1; 
  final Color c2; 
  FourTrianglesPainter(this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    
    final paint1 = Paint()..color = c1;
    final paint2 = Paint()..color = c2;
    
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(center.dx, center.dy)..close(), paint1);
    canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paint1);
    
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(center.dx, center.dy)..close(), paint2);
    canvas.drawPath(Path()..moveTo(0, h)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paint2);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HexagonWidget extends StatelessWidget {
  final String letter;
  final int state;
  final double width;
  final double height;
  final double radius;
  final Color c1;
  final Color c2;
  
  const HexagonWidget({super.key, required this.letter, required this.state, required this.width, required this.height, required this.radius, required this.c1, required this.c2});
  
  @override
  Widget build(BuildContext context) {
    Color fillColor = state == 1 ? c1 : (state == 2 ? c2 : Colors.white);
    Color textColor = state == 0 ? const Color(0xFF311B92) : Colors.white; 
    
    return CustomPaint(
      size: Size(width, height),
      painter: HexagonPainter(fillColor),
      child: Container(
        width: width, height: height, alignment: Alignment.center, 
        child: Text(letter, style: GoogleFonts.cairo(fontSize: radius * 0.70, color: textColor, fontWeight: FontWeight.w900, height: 1.1))
      ),
    );
  }
}

class HexagonPainter extends CustomPainter {
  final Color fillColor;
  HexagonPainter(this.fillColor);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(size.width * 0.5, 0)..lineTo(size.width, size.height * 0.25)..lineTo(size.width, size.height * 0.75)..lineTo(size.width * 0.5, size.height)..lineTo(0, size.height * 0.75)..lineTo(0, size.height * 0.25)..close();
    
    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    
    canvas.drawPath(path, Paint()..color = const Color(0xFF512DA8)..strokeWidth = 7.0..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
