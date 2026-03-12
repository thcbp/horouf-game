import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart'; // مكتبة الخطوط الذكية
import 'dart:math';
import 'dart:convert';
import 'dart:io';

// =================== سيرفر الهوست السري ===================
class HostServer {
  static String currentLetter = "-";
  static String currentQuestion = "اختر حرفاً لتبدأ اللعبة";
  static String currentAnswer = "في انتظار اختيار الحرف...";

  static Future<void> start() async {
    try {
      var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      print("Host server running on http://localhost:8080");
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
    } catch (e) {
      print("Server failed to start: $e");
    }
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
      // تطبيق خط Cairo على كامل التطبيق
      theme: ThemeData(
        brightness: Brightness.dark, 
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF673AB7), // اللون البنفسجي الأساسي
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
          title: const Text('⚙️ إعدادات الجولة الجديدة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
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
              label: const Text('انطلق للعب!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () {
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
                  'color1': Colors.orange.value, // ألوان افتراضية
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54)))
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
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('دليل المضيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 10),
            Icon(Icons.lightbulb, color: Colors.amber, size: 30),
          ],
        ),
        content: Directionality( 
          textDirection: TextDirection.rtl,
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1️⃣ الشاشة السرية:', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('انسخ رابط المضيف والصقه في متصفحك. هذه الشاشة لك وحدك لتقرأ الإجابات.\n', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('2️⃣ التعديل والتخصيص:', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('اضغط على أيقونة الإعدادات العلوية أثناء اللعب لتغيير ألوان الفرق.\n', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('3️⃣ تصحيح الأخطاء:', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('أخطأت في إعطاء النقطة؟ اضغط على الخلية لتعديلها أو مسحها.', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), onPressed: () => Navigator.pop(ctx), child: const Text('فهمت، شكراً!', style: TextStyle(color: Colors.white)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF673AB7), // خلفية بنفسجية فخمة
      body: Stack(
        children: [
          // رسم الخلايا الباهتة في الخلفية (العلامة المائية)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/hexagon-pattern.png',
                repeat: ImageRepeat.repeat,
              ),
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
                  Text('لعبة الحروف', style: GoogleFonts.cairo(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.white, shadows: [const Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))])),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('رابط المضيف:  http://localhost:8080', style: TextStyle(fontSize: 20, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 20),
                        IconButton(icon: const Icon(Icons.copy, color: Colors.white), tooltip: 'نسخ الرابط', onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'http://localhost:8080'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرابط!', style: TextStyle(fontSize: 16)), backgroundColor: Colors.green));
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
                      label: const Text('ابدأ اللعبة', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => _showStartSettings(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7E57C2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.storage, size: 28, color: Colors.white),
                      label: const Text('بنك الأسئلة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen())),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.history, size: 28, color: Colors.white),
                      label: const Text('السجل والأقيام', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 350, height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4527A0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.help_outline, size: 28, color: Colors.amberAccent),
                      label: const Text('دليل المضيف', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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

// =================== شاشة السجل وبنك الأسئلة (مختصرة للتركيز على اللوحة) ===================
class HistoryScreen extends StatefulWidget { const HistoryScreen({super.key}); @override State<HistoryScreen> createState() => _HistoryScreenState(); }
class _HistoryScreenState extends State<HistoryScreen> {
  @override Widget build(BuildContext context) {
    List<Map<String, dynamic>> history = GlobalData.gamesHistory.reversed.toList(); 
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF4A148C), title: const Text('سجل الجولات', style: TextStyle(fontWeight: FontWeight.bold))),
      body: history.isEmpty ? const Center(child: Text('لا توجد جولات محفوظة', style: TextStyle(fontSize: 24))) : ListView.builder(
        padding: const EdgeInsets.all(20), itemCount: history.length, itemBuilder: (context, index) {
          var game = history[index];
          return Card(
            color: const Color(0xFF512DA8), margin: const EdgeInsets.only(bottom: 15),
            child: ListTile(
              title: Text('${game['team1']} 🆚 ${game['team2']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              subtitle: Text('المضيف: ${game['host']} | التاريخ: ${game['date']}', style: const TextStyle(color: Colors.white70)),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GameBoardScreen(hostName: game['host'], team1Name: game['team1'], team2Name: game['team2'], gameData: game))),
                child: const Text('استكمال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class QuestionBankScreen extends StatefulWidget { const QuestionBankScreen({super.key}); @override State<QuestionBankScreen> createState() => _QuestionBankScreenState(); }
class _QuestionBankScreenState extends State<QuestionBankScreen> {
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C), title: const Text('بنك الأسئلة', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.shuffle_on, color: Colors.greenAccent), onPressed: () { DataManager.resetAndShuffleBank(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الخلط!'))); }),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20), itemCount: GlobalData.allArabicLetters.length, itemBuilder: (context, index) {
          String letter = GlobalData.allArabicLetters[index];
          List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
          return Card(
            color: const Color(0xFF512DA8), margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('حرف ( $letter )', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
              children: questions.map((q) => ListTile(title: Text(q['q']!), subtitle: Text('الجواب: ${q['a']}', style: const TextStyle(color: Colors.greenAccent)))).toList(),
            ),
          );
        },
      ),
    );
  }
}

// =================== لوحة اللعب (السحر كله هنا) ===================
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

  @override
  void initState() {
    super.initState();
    List<int> flatBoard = widget.gameData['board'];
    board = List.generate(rows, (r) => List.generate(cols, (c) => flatBoard[r * cols + c]));
    currentLetters = widget.gameData['letters'];
    
    // استرجاع الألوان أو وضع الافتراضي (برتقالي وأخضر)
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

  // نافذة الإعدادات العلوية لتغيير الألوان
  void _showGameSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A148C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إعدادات الألوان', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لون ${widget.team1Name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [Colors.orange, Colors.red, Colors.pink, Colors.purple].map((c) => GestureDetector(
                  onTap: () { setState(() { colorTeam1 = c; widget.gameData['color1'] = c.value; DataManager.saveHistory(); Navigator.pop(ctx); }); },
                  child: CircleAvatar(backgroundColor: c, radius: 20),
                )).toList(),
              ),
              const Divider(color: Colors.white24, height: 30),
              Text('لون ${widget.team2Name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
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
        title: Text('تعديل خلية الحرف ( $letter )', style: const TextStyle(color: Colors.white, fontSize: 24), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorTeam1),
            onPressed: () { Navigator.pop(ctx); _makeMove(r, c, 1); },
            child: Text('لـ ${widget.team1Name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(ctx); setState(() => board[r][c] = 0); },
            child: const Text('مسح الخلية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorTeam2),
            onPressed: () { Navigator.pop(ctx); _makeMove(r, c, 2); },
            child: Text('لـ ${widget.team2Name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  // تم إصلاح الديالوج ليكون آمن 100% ولا يسبب الشاشة البيضاء
  void _showSafeQuestionDialog(int r, int c) {
    int index = r * cols + c;
    String letter = currentLetters[index];
    
    List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
    if (questions.isEmpty) questions = [{'q': 'لم تقم بإضافة أسئلة لحرف ( $letter )!', 'a': 'لا يوجد'}];

    int currentQIndex = GlobalData.letterQuestionIndex[letter] ?? 0;
    if (currentQIndex >= questions.length) currentQIndex = 0; 
    bool isAnswerRevealed = false;

    HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF311B92),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.white24, width: 2)),
              contentPadding: const EdgeInsets.all(30),
              content: SizedBox(
                width: 600,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A148C)),
                      child: Text(letter, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                    Text(questions[currentQIndex]['q']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.5)),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(color: isAnswerRevealed ? Colors.black26 : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                      child: Text(isAnswerRevealed ? 'الإجابة: ${questions[currentQIndex]['a']}' : '--- الإجابة مخفية ---', textAlign: TextAlign.center, style: TextStyle(color: isAnswerRevealed ? Colors.amberAccent : Colors.white38, fontSize: 26, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('تغيير السؤال', style: TextStyle(color: Colors.white, fontSize: 20)),
                          onPressed: () {
                            setDialogState(() {
                              currentQIndex = (currentQIndex + 1) % questions.length;
                              GlobalData.letterQuestionIndex[letter] = currentQIndex; 
                              isAnswerRevealed = false;
                              HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);
                            });
                          },
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                          icon: Icon(isAnswerRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                          label: Text(isAnswerRevealed ? 'إخفاء' : 'إظهار', style: const TextStyle(color: Colors.white, fontSize: 20)),
                          onPressed: () => setDialogState(() => isAnswerRevealed = !isAnswerRevealed),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorTeam1, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: () { GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length; Navigator.pop(ctx); _makeMove(r, c, 1); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                  child: Text('فوز ${widget.team1Name}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 45), onPressed: () { Navigator.pop(ctx); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); }),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: colorTeam2, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: () { GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length; Navigator.pop(ctx); _makeMove(r, c, 2); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                  child: Text('فوز ${widget.team2Name}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
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
    if (_checkWin(player)) {
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
            Text('🏆 مبروك!', textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 50, fontWeight: FontWeight.bold)),
            Positioned(left: 0, top: 0, child: IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 40), onPressed: () => Navigator.pop(ctx))),
          ],
        ),
        content: Text('الفائز هو: $winnerName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 35)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    double radius = 60.0; 
    double width = radius * 1.732;
    double height = radius * 2;
    double totalWidth = cols * width + (width / 2);
    double totalHeight = (rows * height * 0.75) + (height * 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // خلفية داكنة للوحة لتبرز المثلثات
      body: SafeArea(
        child: Column(
          children: [
            // الترويسة العلوية وأزرار الإعدادات
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              color: const Color(0xFF12121A), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 30), onPressed: () => Navigator.pop(context)),
                        const SizedBox(width: 10),
                        Text(widget.team1Name, style: TextStyle(color: colorTeam1, fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white, size: 40),
                        tooltip: 'تغيير ألوان الفرق',
                        onPressed: _showGameSettings, // زر الإعدادات الجديد
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(widget.team2Name, style: TextStyle(color: colorTeam2, fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 20),
                        IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 35), onPressed: () {
                          setState(() => _resetGame());
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // مساحة اللعب مع المثلثات الأربعة الضخمة
            Expanded(
              child: CustomPaint(
                painter: FourTrianglesPainter(colorTeam1, colorTeam2), // المثلثات الأربعة
                child: Center(
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
                              c1: colorTeam1,
                              c2: colorTeam2,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// رسم المثلثات الأربعة المتقاطعة في الخلفية
class FourTrianglesPainter extends CustomPainter {
  final Color c1; // أفقي
  final Color c2; // عمودي
  FourTrianglesPainter(this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    
    final paint1 = Paint()..color = c1;
    final paint2 = Paint()..color = c2;
    
    // يمين ويسار للفريق الأفقي (c1)
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(center.dx, center.dy)..close(), paint1);
    canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paint1);
    
    // فوق وتحت للفريق العمودي (c2)
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(center.dx, center.dy)..close(), paint2);
    canvas.drawPath(Path()..moveTo(0, h)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paint2);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// رسم الخلية السداسية
class HexagonWidget extends StatelessWidget {
  final String letter;
  final int state;
  final double width;
  final double height;
  final Color c1;
  final Color c2;
  
  const HexagonWidget({super.key, required this.letter, required this.state, required this.width, required this.height, required this.c1, required this.c2});
  
  @override
  Widget build(BuildContext context) {
    Color fillColor = state == 1 ? c1 : (state == 2 ? c2 : Colors.white);
    Color textColor = state == 0 ? Colors.black87 : Colors.white;
    
    return CustomPaint(
      size: Size(width, height),
      painter: HexagonPainter(fillColor),
      child: Container(
        width: width, height: height, alignment: Alignment.center, 
        child: Text(letter, style: TextStyle(fontSize: 42, color: textColor, fontWeight: FontWeight.bold))
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
    // إطار خفيف وناعم
    canvas.drawPath(path, Paint()..color = Colors.black26..strokeWidth = 3.0..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
