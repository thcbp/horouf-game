import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
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
                  body { font-family: 'Segoe UI', Tahoma, sans-serif; background-color: #0F0F1A; color: white; text-align: center; padding: 50px; }
                  .card { background-color: #1A1A2E; padding: 40px; border-radius: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.7); display: inline-block; min-width: 60%; border: 1px solid #2D2D44; }
                  h1 { color: #FFA500; font-size: 40px; }
                  .letter { font-size: 100px; font-weight: bold; color: #4DA8DA; margin-bottom: 20px; text-shadow: 0 0 20px rgba(77,168,218,0.5); }
                  .question { font-size: 35px; margin-bottom: 30px; line-height: 1.6; }
                  .answer { font-size: 45px; color: #00FF7F; font-weight: bold; padding: 20px; border: 3px dashed #00FF7F; border-radius: 15px; background-color: rgba(0,255,127,0.1); }
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
                  <p style="color: #888;">هذه الشاشة لك فقط، تأكد من عدم مشاركتها بالبث!</p>
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
      theme: ThemeData(
        brightness: Brightness.dark, 
        fontFamily: 'Hacen', // تم دمج الخط هنا
        scaffoldBackgroundColor: const Color(0xFF0F0F1A), // لون خلفية أعمق وأكثر عصرية
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF1A1A2E),
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
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
          title: const Text('⚙️ إعدادات الجولة الجديدة', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: hostController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم المضيف')),
                TextField(controller: t1Controller, style: const TextStyle(color: Color(0xFFFF9800)), decoration: const InputDecoration(labelText: 'اسم الفريق 1 (أفقي ↔)')),
                TextField(controller: t2Controller, style: const TextStyle(color: Color(0xFF4CAF50)), decoration: const InputDecoration(labelText: 'اسم الفريق 2 (عمودي ↕)')),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('انطلق للوحة اللعب!', style: TextStyle(color: Colors.white, fontSize: 18)),
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
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('دليل المضيف (كيف تلعب؟)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Text('انسخ رابط المضيف من القائمة الرئيسية والصقه في متصفحك. هذه الشاشة مخصصة لك وحدك لتقرأ منها الإجابات بسرعة.\n', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('2️⃣ مشاركة الشاشة (Share Screen):', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('في برنامج الديسكورد، اختر خيار مشاركة "نافذة التطبيق فقط" واختر اللعبة. أو وسّع الشاشة عبر HDMI لضمان عدم ظهور شاشتك السرية.\n', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('3️⃣ تعديل الأخطاء باللوحة:', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('إذا أعطيت نقطة لفريق بالخطأ، فقط اضغط على الخلية الملونة مرة أخرى وستظهر لك خيارات تحويلها للفريق الآخر أو مسحها بالكامل.\n', style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text('4️⃣ نظام السجل:', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('اللعبة تحفظ تقدمك تلقائياً! يمكنك العودة لأي جولة من زر "السجل" واختيار (استكمال).', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx), child: const Text('فهمت، شكراً!', style: TextStyle(color: Colors.white)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: BackgroundPainter(),
        child: Stack(
          children: [
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
                  color: const Color(0xFF1A1A2E).withOpacity(0.9), 
                  borderRadius: BorderRadius.circular(30), 
                  border: Border.all(color: Colors.white10, width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('لعبة الحـروف', style: TextStyle(fontSize: 70, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2, shadows: [Shadow(color: Colors.blueAccent, blurRadius: 20)])),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('رابط المضيف:  http://localhost:8080', style: TextStyle(fontSize: 20, color: Colors.greenAccent)),
                          const SizedBox(width: 20),
                          IconButton(icon: const Icon(Icons.copy, color: Colors.white), tooltip: 'نسخ الرابط', onPressed: () {
                              Clipboard.setData(const ClipboardData(text: 'http://localhost:8080'));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الرابط! الصقه في متصفحك.', style: TextStyle(fontSize: 16, fontFamily: 'Hacen'))));
                          })
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: 320, height: 65,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 10),
                        icon: const Icon(Icons.play_circle_fill, size: 30, color: Colors.white),
                        label: const Text('ابدأ اللعبة', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => _showStartSettings(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 320, height: 65,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        icon: const Icon(Icons.storage, size: 28, color: Colors.white70),
                        label: const Text('بنك الأسئلة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen())),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 320, height: 65,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F3D56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        icon: const Icon(Icons.history, size: 28, color: Colors.white),
                        label: const Text('السجل والأقيام', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 320, height: 65,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF232336), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        icon: const Icon(Icons.help_outline, size: 28, color: Colors.orangeAccent),
                        label: const Text('دليل المضيف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => _showGuideDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== شاشة السجل (History) ===================
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
      appBar: AppBar(backgroundColor: const Color(0xFF1A1A2E), elevation: 0, title: const Text('سجل الجولات السابقة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), centerTitle: true),
      body: history.isEmpty 
        ? const Center(child: Text('لا توجد جولات محفوظة حالياً', style: TextStyle(color: Colors.white54, fontSize: 24)))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: history.length,
            itemBuilder: (context, index) {
              var game = history[index];
              int winner = game['winner'] ?? 0;
              String status = winner == 1 ? '🏆 فاز ${game['team1']}' : (winner == 2 ? '🏆 فاز ${game['team2']}' : '⏳ جولة قيد اللعب / غير مكتملة');
              Color statusColor = winner == 1 ? const Color(0xFFFF9800) : (winner == 2 ? const Color(0xFF4CAF50) : Colors.grey);

              return Card(
                color: const Color(0xFF252538),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  title: Text('${game['team1']} 🆚 ${game['team2']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('المضيف: ${game['host']} | التاريخ: ${game['date']}', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('استكمال', style: TextStyle(color: Colors.white, fontSize: 16)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => GameBoardScreen(
                              hostName: game['host'], team1Name: game['team1'], team2Name: game['team2'], gameData: game
                          )));
                        },
                      ),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
                        tooltip: 'حذف الجولة',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2C),
                              title: const Text('حذف الجولة؟', style: TextStyle(color: Colors.white)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontSize: 16))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => GlobalData.gamesHistory.removeWhere((g) => g['id'] == game['id']));
                                    DataManager.saveHistory();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('نعم، احذف', style: TextStyle(color: Colors.white, fontSize: 16)),
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
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
              title: Text(isEditing ? 'تعديل السؤال' : 'إضافة سؤال', style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLetter,
                    dropdownColor: const Color(0xFF2D2D44),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Hacen'),
                    items: GlobalData.allArabicLetters.map((String value) => DropdownMenuItem<String>(value: value, child: Text("حرف ( $value )"))).toList(),
                    onChanged: isEditing ? null : (newValue) => setDialogState(() => selectedLetter = newValue!),
                  ),
                  TextField(controller: qController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'السؤال')),
                  TextField(controller: aController, style: const TextStyle(color: Colors.greenAccent), decoration: const InputDecoration(labelText: 'الإجابة')),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
                  child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
            SizedBox(width: 10),
            Text('تحذير خطير!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('هل أنت متأكد أنك تريد حذف جميع الأسئلة من التطبيق؟', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              backupBank.clear();
              GlobalData.questionBank.forEach((k, v) => backupBank[k] = List.from(v.map((item) => Map<String, String>.from(item))));
              setState(() => GlobalData.questionBank.clear());
              await DataManager.saveBank();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('تم مسح جميع الأسئلة بنجاح!', style: TextStyle(fontSize: 16, fontFamily: 'Hacen')), backgroundColor: const Color(0xFF2D2D44), duration: const Duration(seconds: 7), action: SnackBarAction(label: 'تراجع ↩️', textColor: Colors.orangeAccent, onPressed: () async { setState(() => GlobalData.questionBank = Map.from(backupBank)); await DataManager.saveBank(); })));
            },
            child: const Text('نعم، احذف الكل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد الملف الجاهز بنجاح!', style: TextStyle(fontFamily: 'Hacen')), backgroundColor: Colors.green)); }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في قراءة الملف! تأكد من أنه ملف JSON سليم.', style: TextStyle(fontFamily: 'Hacen')), backgroundColor: Colors.red));
    }
  }

  void _showImportDialog() {
    TextEditingController jsonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
          title: const Text('استيراد الأسئلة', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: double.maxFinite, child: TextField(controller: jsonController, maxLines: 7, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'الصق كود JSON هنا...', border: OutlineInputBorder()))),
              const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Text('--- أو ---', style: TextStyle(color: Colors.white54))),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3E3E5C), padding: const EdgeInsets.symmetric(vertical: 15)), icon: const Icon(Icons.folder_open, color: Colors.white), label: const Text('استيراد من ملف JSON جاهز', style: TextStyle(color: Colors.white, fontSize: 18)), onPressed: _importFromJsonFile)),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد بنجاح!', style: TextStyle(fontFamily: 'Hacen'))));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في صيغة الـ JSON المنسوخة!', style: TextStyle(fontFamily: 'Hacen')), backgroundColor: Colors.red));
                }
              },
              child: const Text('حفظ النص المنسوخ', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('بنك الأسئلة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_on, color: Colors.greenAccent, size: 28), 
            tooltip: 'خلط وإعادة تعيين الأسئلة (للعب مع مجموعة جديدة)', 
            onPressed: () {
              DataManager.resetAndShuffleBank();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم خلط الأسئلة! ستبدأ الآن بأسئلة جديدة للجميع.', style: TextStyle(fontSize: 16, fontFamily: 'Hacen')), backgroundColor: Colors.green));
            }
          ),
          IconButton(icon: const Icon(Icons.data_object, color: Colors.blueAccent, size: 28), tooltip: 'استيراد', onPressed: _showImportDialog),
          IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28), tooltip: 'حذف الكل', onPressed: _clearAllQuestions),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Colors.orangeAccent, icon: const Icon(Icons.add, color: Colors.white), label: const Text('إضافة سؤال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), onPressed: () => _showQuestionDialog()),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: GlobalData.allArabicLetters.length,
        itemBuilder: (context, index) {
          String letter = GlobalData.allArabicLetters[index];
          List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
          return Card(
            color: const Color(0xFF252538),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('حرف ( $letter )', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              subtitle: Text('عدد الأسئلة: ${questions.length}', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              children: questions.asMap().entries.map((entry) {
                int qIndex = entry.key; var q = entry.value;
                return ListTile(
                  title: Text(q['q']!, style: const TextStyle(color: Colors.white, fontSize: 20)),
                  subtitle: Text('الإجابة: ${q['a']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18)),
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
  @override
  bool operator ==(Object other) => other is Point && other.r == r && other.c == c;
  @override
  int get hashCode => r.hashCode ^ c.hashCode;
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final int rows = 5;
  final int cols = 5;
  late List<List<int>> board;
  late List<String> currentLetters;

  @override
  void initState() {
    super.initState();
    List<int> flatBoard = widget.gameData['board'];
    board = List.generate(rows, (r) => List.generate(cols, (c) => flatBoard[r * cols + c]));
    currentLetters = widget.gameData['letters'];
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

  void _confirmResetGame() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
        title: const Row(children: [Icon(Icons.refresh, color: Colors.redAccent, size: 30), SizedBox(width: 10), Text('تأكيد إعادة الجولة', style: TextStyle(color: Colors.white))]),
        content: const Text('هل أنت متأكد أنك تريد تصفير اللوحة وبدء جولة جديدة كلياً؟', style: TextStyle(color: Colors.white70, fontSize: 20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontSize: 18))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: const Text('نعم، ابدأ من جديد', style: TextStyle(color: Colors.white, fontSize: 18)))
        ],
      )
    );
  }

  void _showAnimatedDialog(Widget dialogContent) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85), // تعتيم أقوى للخلفية
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => dialogContent,
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(scale: Curves.easeOutBack.transform(anim1.value), child: Opacity(opacity: anim1.value, child: child));
      },
    );
  }

  void _handleHexagonTap(int r, int c) {
    if (board[r][c] == 0) {
      _showQuestionDialog(r, c);
    } else {
      _showEditHexagonDialog(r, c);
    }
  }

  void _showEditHexagonDialog(int r, int c) {
    int index = r * cols + c;
    String letter = currentLetters[index];

    _showAnimatedDialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
        title: Text('تعديل خلية الحرف ( $letter )', style: const TextStyle(color: Colors.white, fontSize: 26), textAlign: TextAlign.center),
        content: const Text('لقد أعطيت النقطة لفريق بالخطأ؟\nاختر ماذا تريد أن تفعل بهذه الخلية الآن:', style: TextStyle(color: Colors.white70, fontSize: 20), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _makeMove(r, c, 1); },
            child: Text('تحويل لـ ${widget.team1Name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                board[r][c] = 0; 
                List<int> flatBoard = [];
                for (var row in board) { flatBoard.addAll(row); }
                widget.gameData['board'] = flatBoard;
                widget.gameData['winner'] = 0; 
                DataManager.saveHistory();
              });
            },
            child: const Text('مسح الخلية', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _makeMove(r, c, 2); },
            child: Text('تحويل لـ ${widget.team2Name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      )
    );
  }

  void _showQuestionDialog(int r, int c) {
    int index = r * cols + c;
    String letter = currentLetters[index];
    
    List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
    if (questions.isEmpty) questions = [{'q': 'لم تقم بإضافة أسئلة لحرف ( $letter ) في بنك الأسئلة!', 'a': 'لا يوجد'}];

    int currentQIndex = GlobalData.letterQuestionIndex[letter] ?? 0;
    if (currentQIndex >= questions.length) currentQIndex = 0; 

    bool isAnswerRevealed = false;
    HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);

    void saveNextQuestionIndex() => GlobalData.letterQuestionIndex[letter] = (currentQIndex + 1) % questions.length;

    _showAnimatedDialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.blueAccent, width: 2)),
            contentPadding: const EdgeInsets.all(30),
            // جعل النافذة أعرض وأفخم
            content: SizedBox(
              width: 600, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الأيقونة الدائرية للحرف
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: const Color(0xFF252540),
                      boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Text(letter, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                  Text(questions[currentQIndex]['q']!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.5)),
                  const SizedBox(height: 30),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(color: isAnswerRevealed ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(15), border: Border.all(color: isAnswerRevealed ? Colors.blueAccent : Colors.transparent, width: 2)),
                    child: Text(isAnswerRevealed ? 'الإجابة: ${questions[currentQIndex]['a']}' : '--- الإجابة مخفية ---', textAlign: TextAlign.center, style: TextStyle(color: isAnswerRevealed ? Colors.lightBlueAccent : Colors.white38, fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
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
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3E3E5C), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        icon: Icon(isAnswerRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 28),
                        label: Text(isAnswerRevealed ? 'إخفاء الإجابة' : 'إظهار الإجابة', style: const TextStyle(color: Colors.white, fontSize: 20)),
                        onPressed: () => setDialogState(() => isAnswerRevealed = !isAnswerRevealed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(bottom: 20),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () { saveNextQuestionIndex(); Navigator.pop(context); _makeMove(r, c, 1); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                child: Text('فوز ${widget.team1Name}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 15),
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 35), onPressed: () { Navigator.pop(context); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); }),
              ),
              const SizedBox(width: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () { saveNextQuestionIndex(); Navigator.pop(context); _makeMove(r, c, 2); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                child: Text('فوز ${widget.team2Name}', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      )
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
      Color teamColor = player == 1 ? const Color(0xFFE67E22) : const Color(0xFF4CAF50);
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
    _showAnimatedDialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color, width: 3)),
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text('🏆 مبروك!', textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 50, fontWeight: FontWeight.bold, shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)])),
            Positioned(
              left: 0, top: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 40),
                tooltip: 'تراجع عن رسالة الفوز',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        content: Text('الفائز هو: $winnerName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 35)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () { Navigator.pop(context); _resetGame(); },
              child: const Text('جولة جديدة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // تم تكبير حجم الخلايا هنا بشكل ملحوظ
    double radius = 62.0; 
    double width = radius * 1.732;
    double height = radius * 2;
    double totalWidth = cols * width + (width / 2);
    double totalHeight = (rows * height * 0.75) + (height * 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              color: const Color(0xFF1A1A2E), // شريط علوي أعمق
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 30), onPressed: () => Navigator.pop(context)),
                          const Icon(Icons.swap_horiz, color: Color(0xFFE67E22), size: 35),
                          const SizedBox(width: 10),
                          Flexible(child: Text(widget.team1Name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE67E22), fontSize: 26, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(child: Text('لعبة الحروف مع ${widget.hostName}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(widget.team2Name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 26, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 10),
                          const Icon(Icons.swap_vert, color: Color(0xFF4CAF50), size: 35),
                          const SizedBox(width: 20),
                          IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 35), onPressed: _confirmResetGame),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: BackgroundPainter(),
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
                            child: HexagonWidget(letter: currentLetters[index], state: board[r][c], width: width, height: height),
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

// تصميم الخلفية أصبح أنعم وأكثر عصرية ولا يغطي على اللوحة
class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    
    // ألوان خلفية هادئة (شبه شفافة) تعطي انطباع عميق
    final paintOrange = Paint()..color = const Color(0xFFCC5500).withOpacity(0.15);
    final paintGreen = Paint()..color = const Color(0xFF004D40).withOpacity(0.15);
    
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(center.dx, center.dy)..close(), paintGreen);
    canvas.drawPath(Path()..moveTo(0, h)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paintGreen);
    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(center.dx, center.dy)..close(), paintOrange);
    canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(center.dx, center.dy)..close(), paintOrange);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// تصميم الخلية السداسية
class HexagonWidget extends StatelessWidget {
  final String letter;
  final int state;
  final double width;
  final double height;
  const HexagonWidget({super.key, required this.letter, required this.state, required this.width, required this.height});
  
  @override
  Widget build(BuildContext context) {
    // ألوان نيون عصرية ومريحة للعين داخل الخلايا
    Color fillColor = state == 1 ? const Color(0xFFE67E22) : (state == 2 ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0));
    Color textColor = state == 0 ? const Color(0xFF1A1A2E) : Colors.white;
    
    return CustomPaint(
      size: Size(width, height),
      painter: HexagonPainter(fillColor),
      child: Container(
        width: width, height: height, alignment: Alignment.center, 
        // تكبير الخط داخل الخلية ليناسب الحجم الجديد
        child: Text(letter, style: TextStyle(fontSize: state == 0 ? 48 : 52, color: textColor, fontWeight: FontWeight.bold))
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
    
    // تعبئة الخلية باللون
    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    
    // رسم إطار فضي خفيف وناعم بدل الأسود القاسي
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 3.0..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
