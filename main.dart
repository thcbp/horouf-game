import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

// =================== الخادم السري للمضيف ===================
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
  
  // ألوان الفرق الافتراضية
  static Color team1Color = const Color(0xFFE67E22);
  static Color team2Color = const Color(0xFF4CAF50);
  
  // لوحة الألوان المتاحة للتخصيص
  static final List<Color> colorPalette = [
    const Color(0xFFE67E22), const Color(0xFF4CAF50), const Color(0xFF2196F3),
    const Color(0xFFE91E63), const Color(0xFF9C27B0), const Color(0xFFFFC107),
    const Color(0xFF00BCD4), const Color(0xFFF44336)
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
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white)),
        scaffoldBackgroundColor: const Color(0xFF0B0C10), 
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Color(0xFF1F2833),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// =================== القائمة الرئيسية ===================
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  void _showStartSettings(BuildContext context) {
    TextEditingController hostController = TextEditingController(text: "عزيز");
    TextEditingController t1Controller = TextEditingController(text: "البرتقالي");
    TextEditingController t2Controller = TextEditingController(text: "الأخضر");
    
    Color tempTeam1 = GlobalData.team1Color;
    Color tempTeam2 = GlobalData.team2Color;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F2833).withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
              title: Text('إعدادات الجولة الجديدة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: hostController, style: GoogleFonts.cairo(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم المضيف', prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: tempTeam1.withOpacity(0.5))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: t1Controller, style: GoogleFonts.cairo(color: tempTeam1, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'اسم الفريق 1 (أفقي ↔)', border: InputBorder.none)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: GlobalData.colorPalette.map((color) => GestureDetector(
                              onTap: () => setStateDialog(() => tempTeam1 = color),
                              child: CircleAvatar(backgroundColor: color, radius: 15, child: tempTeam1 == color ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: Border.all(color: tempTeam2.withOpacity(0.5))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: t2Controller, style: GoogleFonts.cairo(color: tempTeam2, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'اسم الفريق 2 (عمودي ↕)', border: InputBorder.none)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: GlobalData.colorPalette.map((color) => GestureDetector(
                              onTap: () => setStateDialog(() => tempTeam2 = color),
                              child: CircleAvatar(backgroundColor: color, radius: 15, child: tempTeam2 == color ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: Text('انطلق للوحة اللعب!', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    GlobalData.team1Color = tempTeam1;
                    GlobalData.team2Color = tempTeam2;
                    
                    String newId = DateTime.now().millisecondsSinceEpoch.toString();
                    Map<String, dynamic> newGame = {
                      'id': newId,
                      'date': "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')} | ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')}",
                      'host': hostController.text.isNotEmpty ? hostController.text : "عزيز",
                      'team1': t1Controller.text.isNotEmpty ? t1Controller.text : "الفريق الأول",
                      'team2': t2Controller.text.isNotEmpty ? t2Controller.text : "الفريق الثاني",
                      'color1': tempTeam1.value,
                      'color2': tempTeam2.value,
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
                TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54)))
              ],
            );
          }
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('دليل المضيف (كيف تلعب؟)', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
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
                Text('انسخ رابط المضيف من القائمة الرئيسية والصقه في متصفحك. هذه الشاشة مخصصة لك وحدك لتقرأ منها الإجابات بسرعة.\n', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                Text('2️⃣ مشاركة الشاشة (Share Screen):', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('في الديسكورد، اختر مشاركة "نافذة التطبيق فقط" واختر اللعبة. أو وسّع الشاشة عبر HDMI لضمان عدم ظهور شاشتك السرية.\n', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                Text('3️⃣ تعديل الأخطاء باللوحة:', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('إذا أعطيت نقطة لفريق بالخطأ، فقط اضغط على الخلية الملونة مرة أخرى وستظهر لك خيارات تحويلها للفريق الآخر أو مسحها.\n', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
                Text('4️⃣ نظام السجل:', style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('اللعبة تحفظ تقدمك تلقائياً! يمكنك العودة لأي جولة من زر "السجل" واختيار (استكمال).', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(ctx), child: Text('فهمت، شكراً!', style: GoogleFonts.cairo(color: Colors.white)))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: WatermarkBackgroundPainter(),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(50),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2833).withOpacity(0.6), 
                      borderRadius: BorderRadius.circular(30), 
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('لعبة الحـروف', style: GoogleFonts.cairo(fontSize: 70, fontWeight: FontWeight.w900, color: Colors.white, shadows: [const Shadow(color: Colors.blueAccent, blurRadius: 20)])),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('رابط المضيف:  http://localhost:8080', style: GoogleFonts.cairo(fontSize: 20, color: const Color(0xFF45A29E), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 20),
                              IconButton(icon: const Icon(Icons.copy, color: Colors.white), tooltip: 'نسخ الرابط', onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: 'http://localhost:8080'));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ الرابط! الصقه في متصفحك.', style: GoogleFonts.cairo(fontSize: 16))));
                              })
                            ],
                          ),
                        ),
                        const SizedBox(height: 50),
                        _buildMenuButton(Icons.play_circle_fill, 'ابدأ اللعبة', Colors.blueAccent, () => _showStartSettings(context)),
                        const SizedBox(height: 20),
                        _buildMenuButton(Icons.storage, 'بنك الأسئلة', const Color(0xFF2D2D44), () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen()))),
                        const SizedBox(height: 20),
                        _buildMenuButton(Icons.history, 'السجل والأقيام', const Color(0xFF3F3D56), () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()))),
                        const SizedBox(height: 20),
                        _buildMenuButton(Icons.help_outline, 'دليل المضيف', const Color(0xFF232336), () => _showGuideDialog(context), iconColor: Colors.orangeAccent),
                      ],
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

  Widget _buildMenuButton(IconData icon, String text, Color color, VoidCallback onTap, {Color iconColor = Colors.white70}) {
    return SizedBox(
      width: 320, height: 65,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
        icon: Icon(icon, size: 28, color: iconColor),
        label: Text(text, style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: onTap,
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
      appBar: AppBar(backgroundColor: const Color(0xFF1A1A2E), elevation: 0, title: Text('سجل الجولات السابقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)), centerTitle: true),
      body: history.isEmpty 
        ? Center(child: Text('لا توجد جولات محفوظة حالياً', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 24)))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: history.length,
            itemBuilder: (context, index) {
              var game = history[index];
              int winner = game['winner'] ?? 0;
              Color c1 = game['color1'] != null ? Color(game['color1']) : GlobalData.team1Color;
              Color c2 = game['color2'] != null ? Color(game['color2']) : GlobalData.team2Color;
              String status = winner == 1 ? '🏆 فاز ${game['team1']}' : (winner == 2 ? '🏆 فاز ${game['team2']}' : '⏳ جولة قيد اللعب / غير مكتملة');
              Color statusColor = winner == 1 ? c1 : (winner == 2 ? c2 : Colors.grey);

              return Card(
                color: const Color(0xFF252538),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white10)),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  title: Text('${game['team1']} 🆚 ${game['team2']}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('المضيف: ${game['host']} | التاريخ: ${game['date']}', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(status, style: GoogleFonts.cairo(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: Text('استكمال', style: GoogleFonts.cairo(color: Colors.white, fontSize: 16)),
                        onPressed: () {
                          GlobalData.team1Color = c1;
                          GlobalData.team2Color = c2;
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
                              title: Text('حذف الجولة؟', style: GoogleFonts.cairo(color: Colors.white)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(fontSize: 16))),
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
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.white12)),
              title: Text(isEditing ? 'تعديل السؤال' : 'إضافة سؤال', style: GoogleFonts.cairo(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLetter,
                    dropdownColor: const Color(0xFF2D2D44),
                    style: GoogleFonts.cairo(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    items: GlobalData.allArabicLetters.map((String value) => DropdownMenuItem<String>(value: value, child: Text("حرف ( $value )"))).toList(),
                    onChanged: isEditing ? null : (newValue) => setDialogState(() => selectedLetter = newValue!),
                  ),
                  TextField(controller: qController, style: GoogleFonts.cairo(color: Colors.white), decoration: const InputDecoration(labelText: 'السؤال')),
                  TextField(controller: aController, style: GoogleFonts.cairo(color: Colors.greenAccent), decoration: const InputDecoration(labelText: 'الإجابة')),
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
        backgroundColor: const Color(0xFF1E1E2C),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
            const SizedBox(width: 10),
            Text('تحذير خطير!', style: GoogleFonts.cairo(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم مسح جميع الأسئلة بنجاح!', style: GoogleFonts.cairo(fontSize: 16)), backgroundColor: const Color(0xFF2D2D44), duration: const Duration(seconds: 7), action: SnackBarAction(label: 'تراجع ↩️', textColor: Colors.orangeAccent, onPressed: () async { setState(() => GlobalData.questionBank = Map.from(backupBank)); await DataManager.saveBank(); })));
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في قراءة الملف! تأكد من أنه ملف JSON سليم.', style: GoogleFonts.cairo()), backgroundColor: Colors.red));
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
          title: Text('استيراد الأسئلة', style: GoogleFonts.cairo(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: double.maxFinite, child: TextField(controller: jsonController, maxLines: 7, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'الصق كود JSON هنا...', border: OutlineInputBorder()))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text('--- أو ---', style: GoogleFonts.cairo(color: Colors.white54))),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3E3E5C), padding: const EdgeInsets.symmetric(vertical: 15)), icon: const Icon(Icons.folder_open, color: Colors.white), label: Text('استيراد من ملف JSON جاهز', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)), onPressed: _importFromJsonFile)),
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
        backgroundColor: const Color(0xFF1A1A2E),
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
            color: const Color(0xFF252538),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('حرف ( $letter )', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
        title: Row(children: [const Icon(Icons.refresh, color: Colors.redAccent, size: 30), const SizedBox(width: 10), Text('تأكيد إعادة الجولة', style: GoogleFonts.cairo(color: Colors.white))]),
        content: Text('هل أنت متأكد أنك تريد تصفير اللوحة وبدء جولة جديدة كلياً؟', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54, fontSize: 18))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () { Navigator.pop(ctx); _resetGame(); }, child: Text('نعم، ابدأ من جديد', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)))
        ],
      )
    );
  }

  void _showGlassDialog(Widget dialogContent) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ScaleTransition(
            scale: Curves.easeOutBack.transform(anim1.value) as Animation<double>,
            child: Opacity(opacity: anim1.value, child: dialogContent),
          ),
        );
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

    _showGlassDialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
        title: Text('تعديل خلية الحرف ( $letter )', style: GoogleFonts.cairo(color: Colors.white, fontSize: 26), textAlign: TextAlign.center),
        content: Text('لقد أعطيت النقطة لفريق بالخطأ؟\nاختر ماذا تريد أن تفعل بهذه الخلية الآن:', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 20), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlobalData.team1Color, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _makeMove(r, c, 1); },
            child: Text('تحويل لـ ${widget.team1Name}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
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
            child: Text('مسح الخلية', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlobalData.team2Color, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _makeMove(r, c, 2); },
            child: Text('تحويل لـ ${widget.team2Name}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 18)),
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

    _showGlassDialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2833).withOpacity(0.85),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: const Color(0xFF0B0C10),
                      boxShadow: [BoxShadow(color: const Color(0xFF45A29E).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Center(child: Text(letter, style: GoogleFonts.cairo(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(height: 30),
                  Text(questions[currentQIndex]['q']!, textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.5)),
                  const SizedBox(height: 30),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(color: isAnswerRevealed ? const Color(0xFF45A29E).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(15), border: Border.all(color: isAnswerRevealed ? const Color(0xFF45A29E) : Colors.white12)),
                    child: Text(isAnswerRevealed ? 'الإجابة: ${questions[currentQIndex]['a']}' : '--- الإجابة مخفية ---', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: isAnswerRevealed ? Colors.white : Colors.white38, fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: GlobalData.team1Color, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () { saveNextQuestionIndex(); Navigator.pop(context); _makeMove(r, c, 1); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                        child: Text(widget.team1Name, style: GoogleFonts.cairo(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(icon: const Icon(Icons.visibility, color: Colors.white70, size: 35), onPressed: () => setDialogState(() => isAnswerRevealed = !isAnswerRevealed)),
                      IconButton(icon: const Icon(Icons.refresh, color: Colors.white70, size: 35), onPressed: () {
                          setDialogState(() {
                            currentQIndex = (currentQIndex + 1) % questions.length;
                            GlobalData.letterQuestionIndex[letter] = currentQIndex; 
                            isAnswerRevealed = false;
                            HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);
                          });
                        }),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: GlobalData.team2Color, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () { saveNextQuestionIndex(); Navigator.pop(context); _makeMove(r, c, 2); HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-"); },
                        child: Text(widget.team2Name, style: GoogleFonts.cairo(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      Color teamColor = player == 1 ? GlobalData.team1Color : GlobalData.team2Color;
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
    _showGlassDialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color, width: 3)),
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text('🏆 مبروك!', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: color, fontSize: 50, fontWeight: FontWeight.bold, shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 10)])),
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
        content: Text('الفائز هو: $winnerName', textAlign: TextAlign.center, style: GoogleFonts.cairo(color: Colors.white, fontSize: 35)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () { Navigator.pop(context); _resetGame(); },
              child: Text('جولة جديدة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    double radius = 62.0; 
    double width = radius * 1.732;
    double height = radius * 2;
    double totalWidth = cols * width + (width / 2);
    double totalHeight = (rows * height * 0.75) + (height * 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: SafeArea(
        child: Column(
          children: [
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(color: const Color(0xFF1F2833).withOpacity(0.5), border: const Border(bottom: BorderSide(color: Colors.white12))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [IconButton(icon: const Icon(Icons.home, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)), const SizedBox(width: 15), Text(widget.team1Name, style: GoogleFonts.cairo(color: GlobalData.team1Color, fontSize: 26, fontWeight: FontWeight.bold))]),
                      Text('المضيف: ${widget.hostName}', style: GoogleFonts.cairo(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                      Row(children: [Text(widget.team2Name, style: GoogleFonts.cairo(color: GlobalData.team2Color, fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(width: 15), IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 30), onPressed: _confirmResetGame)]),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: WatermarkBackgroundPainter(),
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
                          child: InteractiveHexagon(
                            letter: currentLetters[index], 
                            state: board[r][c], 
                            width: width, 
                            height: height,
                            onTap: () => _handleHexagonTap(r, c),
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

// تصميم الخلفية المائية العميقة
class WatermarkBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    double radius = 80;
    double w = radius * 1.732;
    double h = radius * 2;
    for (double y = -h; y < size.height + h; y += h * 0.75) {
      bool isOdd = (y / (h * 0.75)).round() % 2 != 0;
      for (double x = -w; x < size.width + w; x += w) {
        double curX = x + (isOdd ? w / 2 : 0);
        Path path = Path()..moveTo(curX + w * 0.5, y)..lineTo(curX + w, y + h * 0.25)..lineTo(curX + w, y + h * 0.75)..lineTo(curX + w * 0.5, y + h)..lineTo(curX, y + h * 0.75)..lineTo(curX, y + h * 0.25)..close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// الخلية التفاعلية مع تأثيرات المرور والألوان المخصصة والمثلثات الداخلية
class InteractiveHexagon extends StatefulWidget {
  final String letter;
  final int state;
  final double width;
  final double height;
  final VoidCallback onTap;

  const InteractiveHexagon({super.key, required this.letter, required this.state, required this.width, required this.height, required this.onTap});

  @override
  State<InteractiveHexagon> createState() => _InteractiveHexagonState();
}

class _InteractiveHexagonState extends State<InteractiveHexagon> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
          transformAlignment: Alignment.center,
          child: CustomPaint(
            size: Size(widget.width, widget.height),
            painter: ModernHexagonPainter(widget.state, isHovered),
            child: SizedBox(
              width: widget.width, height: widget.height,
              child: Center(
                child: Text(widget.letter, style: GoogleFonts.cairo(fontSize: 48, color: widget.state == 0 ? Colors.white70 : Colors.white, fontWeight: FontWeight.w900, shadows: isHovered ? [const Shadow(color: Colors.black54, blurRadius: 10)] : [])),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// رسم الخلية بنمط هندسي ثلاثي الأبعاد مقسم למثلثات
class ModernHexagonPainter extends CustomPainter {
  final int state;
  final bool isHovered;
  ModernHexagonPainter(this.state, this.isHovered);

  @override
  void paint(Canvas canvas, Size size) {
    Color baseColor = state == 1 ? GlobalData.team1Color : (state == 2 ? GlobalData.team2Color : const Color(0xFF1F2833));
    
    Offset center = Offset(size.width / 2, size.height / 2);
    List<Offset> points = [
      Offset(size.width * 0.5, 0), Offset(size.width, size.height * 0.25),
      Offset(size.width, size.height * 0.75), Offset(size.width * 0.5, size.height),
      Offset(0, size.height * 0.75), Offset(0, size.height * 0.25)
    ];

    for (int i = 0; i < 6; i++) {
      Path triangle = Path()..moveTo(center.dx, center.dy)..lineTo(points[i].dx, points[i].dy)..lineTo(points[(i + 1) % 6].dx, points[(i + 1) % 6].dy)..close();
      double shade = (i % 2 == 0) ? 0.1 : -0.1; 
      Color tColor = state == 0 ? baseColor : HSLColor.fromColor(baseColor).withLightness((HSLColor.fromColor(baseColor).lightness + shade).clamp(0.0, 1.0)).toColor();
      canvas.drawPath(triangle, Paint()..color = tColor..style = PaintingStyle.fill);
    }

    Path borderPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < 6; i++) borderPath.lineTo(points[i].dx, points[i].dy);
    borderPath.close();

    canvas.drawPath(borderPath, Paint()..color = isHovered ? Colors.white : Colors.white24..strokeWidth = isHovered ? 4.0 : 2.0..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
