import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
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
                <title>لوحة تحكم الهوست</title>
                <style>
                  body { font-family: Tahoma, sans-serif; background-color: #12121A; color: white; text-align: center; padding: 50px; }
                  .card { background-color: #1E1E2C; padding: 40px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); display: inline-block; min-width: 60%; }
                  h1 { color: #FFA500; font-size: 40px; }
                  .letter { font-size: 100px; font-weight: bold; color: #4DA8DA; margin-bottom: 20px; }
                  .question { font-size: 35px; margin-bottom: 30px; line-height: 1.5; }
                  .answer { font-size: 45px; color: #00FF7F; font-weight: bold; padding: 20px; border: 3px dashed #00FF7F; border-radius: 15px; }
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
                  <h1>شاشة الهوست (سرية) 🤫</h1>
                  <p style="color: #888;">هذه الشاشة لك فقط، لا تبثها بالديسكورد!</p>
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
      } else {
        await saveBank(); // إنشاء الملف لأول مرة
      }
    } catch (e) {
      print("Error loading bank: $e");
    }
  }

  static Future<void> saveBank() async {
    try {
      String jsonString = jsonEncode(GlobalData.questionBank);
      await _file.writeAsString(jsonString);
    } catch (e) {
      print("Error saving bank: $e");
    }
  }
}

class GlobalData {
  static Map<String, List<Map<String, String>>> questionBank = {
    'أ': [{'q': 'حيوان مفترس يلقب بملك الغابة؟', 'a': 'أسد'}],
  };
  static final List<String> allArabicLetters = [
    'أ','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص',
    'ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','هـ','و','ي'
  ];
}

// =================== بداية التطبيق ===================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تشغيل ملء الشاشة للويندوز
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: 'حروف',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // تشغيل السيرفر السري وتحميل الذاكرة
  HostServer.start();
  await DataManager.loadBank();

  runApp(const HoroufGameApp());
}

class HoroufGameApp extends StatelessWidget {
  const HoroufGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حروف',
      theme: ThemeData(
        brightness: Brightness.dark, 
        fontFamily: 'Tahoma',
        scaffoldBackgroundColor: const Color(0xFF12121A),
      ),
      home: const MainMenuScreen(),
    );
  }
}

// =================== القائمة الرئيسية ===================
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  void _showStartSettings(BuildContext context) {
    String hostName = "عزيز";
    String team1Name = "البرتقالي";
    String team2Name = "الأخضر";

    TextEditingController hostController = TextEditingController(text: hostName);
    TextEditingController t1Controller = TextEditingController(text: team1Name);
    TextEditingController t2Controller = TextEditingController(text: team2Name);

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
                TextField(controller: hostController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'اسم الهوست')),
                TextField(controller: t1Controller, style: const TextStyle(color: Colors.orange), decoration: const InputDecoration(labelText: 'اسم الفريق 1 (أفقي ↔)')),
                TextField(controller: t2Controller, style: const TextStyle(color: Colors.green), decoration: const InputDecoration(labelText: 'اسم الفريق 2 (عمودي ↕)')),
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
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GameBoardScreen(
                    hostName: hostController.text.isNotEmpty ? hostController.text : "عزيز",
                    team1Name: t1Controller.text.isNotEmpty ? t1Controller.text : "البرتقالي",
                    team2Name: t2Controller.text.isNotEmpty ? t2Controller.text : "الأخضر",
                  )),
                );
              },
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54)))
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: BackgroundPainter(),
        child: Stack(
          children: [
            // زر ملء الشاشة
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 40),
                tooltip: 'ملء الشاشة',
                onPressed: () async {
                  bool isFull = await windowManager.isFullScreen();
                  windowManager.setFullScreen(!isFull);
                },
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFF12121A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('حـــروف', style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5)),
                    const SizedBox(height: 10),
                    const Text('شاشة الهوست السرية: http://localhost:8080', style: TextStyle(fontSize: 18, color: Colors.greenAccent)),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: 300, height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        icon: const Icon(Icons.play_circle_fill, size: 30, color: Colors.white),
                        label: const Text('ابدأ اللعبة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => _showStartSettings(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300, height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D2D44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        icon: const Icon(Icons.storage, size: 28, color: Colors.white70),
                        label: const Text('بنك الأسئلة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen())),
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

// =================== بنك الأسئلة ===================
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});
  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  void _showAddQuestionDialog() {
    String selectedLetter = 'أ';
    TextEditingController qController = TextEditingController();
    TextEditingController aController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              title: const Text('إضافة سؤال', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLetter,
                    dropdownColor: const Color(0xFF2D2D44),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    items: GlobalData.allArabicLetters.map((String value) => DropdownMenuItem<String>(value: value, child: Text("حرف ( $value )"))).toList(),
                    onChanged: (newValue) => setDialogState(() => selectedLetter = newValue!),
                  ),
                  TextField(controller: qController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'السؤال')),
                  TextField(controller: aController, style: const TextStyle(color: Colors.greenAccent), decoration: const InputDecoration(labelText: 'الإجابة')),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (qController.text.isNotEmpty && aController.text.isNotEmpty) {
                      setState(() {
                        if (!GlobalData.questionBank.containsKey(selectedLetter)) GlobalData.questionBank[selectedLetter] = [];
                        GlobalData.questionBank[selectedLetter]!.add({'q': qController.text, 'a': aController.text});
                      });
                      await DataManager.saveBank(); // حفظ في الملف
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('حفظ'),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showImportDialog() {
    TextEditingController jsonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('استيراد ذكي (JSON)', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: jsonController,
              maxLines: 10,
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
              decoration: const InputDecoration(hintText: 'الصق كود JSON هنا...', border: OutlineInputBorder()),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                try {
                  Map<String, dynamic> decoded = jsonDecode(jsonController.text);
                  setState(() {
                    decoded.forEach((key, value) {
                      if (!GlobalData.questionBank.containsKey(key)) GlobalData.questionBank[key] = [];
                      for (var item in value) {
                        GlobalData.questionBank[key]!.add({'q': item['q'].toString(), 'a': item['a'].toString()});
                      }
                    });
                  });
                  await DataManager.saveBank(); // حفظ في الملف
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد وحفظ الأسئلة بنجاح!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في صيغة الـ JSON!'), backgroundColor: Colors.red));
                }
              },
              child: const Text('استيراد وحفظ', style: TextStyle(color: Colors.white)),
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
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('بنك الأسئلة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.data_object, color: Colors.blueAccent), onPressed: _showImportDialog)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة سؤال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddQuestionDialog,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: GlobalData.allArabicLetters.length,
        itemBuilder: (context, index) {
          String letter = GlobalData.allArabicLetters[index];
          List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [];
          return Card(
            color: const Color(0xFF252538),
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              title: Text('حرف ( $letter )', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              subtitle: Text('عدد الأسئلة: ${questions.length}', style: const TextStyle(color: Colors.white54)),
              children: questions.map((q) => ListTile(
                title: Text(q['q']!, style: const TextStyle(color: Colors.white, fontSize: 18)),
                subtitle: Text('الإجابة: ${q['a']}', style: const TextStyle(color: Colors.greenAccent)),
                leading: const Icon(Icons.help_outline, color: Colors.orangeAccent),
              )).toList(),
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
  const GameBoardScreen({super.key, required this.hostName, required this.team1Name, required this.team2Name});
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
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      board = List.generate(rows, (_) => List.filled(cols, 0));
      List<String> shuffled = List.of(GlobalData.allArabicLetters)..shuffle(Random());
      currentLetters = shuffled.take(25).toList();
    });
    HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-");
  }

  void _showAnimatedDialog(Widget dialogContent) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => dialogContent,
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(scale: Curves.easeOutBack.transform(anim1.value), child: Opacity(opacity: anim1.value, child: child));
      },
    );
  }

  void _showQuestionDialog(int r, int c) {
    if (board[r][c] != 0) return;
    int index = r * cols + c;
    String letter = currentLetters[index];
    
    List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [
      {'q': 'لم تقم بإضافة أسئلة لحرف ( $letter ) في بنك الأسئلة!', 'a': 'لا يوجد'}
    ];

    int currentQIndex = 0;
    
    // إرسال البيانات فوراً لشاشة الهوست السرية
    HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!);

    _showAnimatedDialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: Colors.white24, width: 2)),
            title: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
              child: Text(letter, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  questions[currentQIndex]['q']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.5),
                ),
                const SizedBox(height: 20),
                // صندوق الإجابة تم تغييره ليكون آمناً للبث
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                  child: const Text('الإجابة موجودة في شاشة الهوست السرية 📱', style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('تغيير السؤال', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    setDialogState(() {
                      currentQIndex = (currentQIndex + 1) % questions.length;
                      HostServer.updateData(letter, questions[currentQIndex]['q']!, questions[currentQIndex]['a']!); // تحديث شاشة الهوست
                    });
                  },
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                onPressed: () { 
                  Navigator.pop(context); 
                  _makeMove(r, c, 1); 
                  HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-");
                },
                child: Text('فوز ${widget.team1Name}', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 30),
                onPressed: () {
                  Navigator.pop(context);
                  HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-");
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                onPressed: () { 
                  Navigator.pop(context); 
                  _makeMove(r, c, 2); 
                  HostServer.updateData("-", "اختر حرفاً لتبدأ اللعبة", "-");
                },
                child: Text('فوز ${widget.team2Name}', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      )
    );
  }

  void _makeMove(int r, int c, int player) {
    setState(() { board[r][c] = player; });
    if (_checkWin(player)) {
      String winnerName = player == 1 ? widget.team1Name : widget.team2Name;
      Color teamColor = player == 1 ? Colors.orange : Colors.green;
      Future.delayed(const Duration(milliseconds: 300), () => _showWinDialog(winnerName, teamColor));
    }
  }

  bool _checkWin(int player) {
    List<Point> starts = [];
    if (player == 1) { 
      for (int r = 0; r < rows; r++) if (board[r][0] == 1) starts.add(Point(r, 0));
    } else { 
      for (int c = 0; c < cols; c++) if (board[0][c] == 2) starts.add(Point(0, c));
    }

    Set<Point> visited = {};
    for (var start in starts) {
      if (_dfs(start, player, visited)) return true;
    }
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
        if (board[nr][nc] == player && !visited.contains(nextPoint)) {
          if (_dfs(nextPoint, player, visited)) return true;
        }
      }
    }
    return false;
  }

  void _showWinDialog(String winnerName, Color color) {
    _showAnimatedDialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text('🏆 مبروك!', textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.bold)),
        content: Text('الفائز هو: $winnerName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () { Navigator.pop(context); _resetGame(); },
              child: const Text('جولة جديدة', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    double radius = 45.0;
    double width = radius * 1.732;
    double height = radius * 2;
    double totalWidth = cols * width + (width / 2);
    double totalHeight = (rows * height * 0.75) + (height * 0.25);

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: const Color(0xFF12121A),
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
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Icon(Icons.swap_horiz, color: Colors.orange, size: 28),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(widget.team1Name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text('حروف مع ${widget.hostName}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(widget.team2Name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.swap_vert, color: Colors.green, size: 28),
                          const SizedBox(width: 15),
                          IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent), onPressed: _resetGame),
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
                          left: x,
                          top: y,
                          child: GestureDetector(
                            onTap: () => _showQuestionDialog(r, c),
                            child: HexagonWidget(
                              letter: currentLetters[index],
                              state: board[r][c],
                              width: width,
                              height: height,
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

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);

    final paintOrange = Paint()..color = Colors.orange.shade700;
    final paintGreen = Paint()..color = Colors.green.shade700;

    final pathTop = Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathTop, paintGreen);

    final pathBottom = Path()..moveTo(0, h)..lineTo(w, h)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathBottom, paintGreen);

    final pathLeft = Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathLeft, paintOrange);

    final pathRight = Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(center.dx, center.dy)..close();
    canvas.drawPath(pathRight, paintOrange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HexagonWidget extends StatelessWidget {
  final String letter;
  final int state;
  final double width;
  final double height;

  const HexagonWidget({super.key, required this.letter, required this.state, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    Color fillColor = Colors.white;
    Color textColor = Colors.black;
    
    if (state == 1) { fillColor = Colors.orange; textColor = Colors.white; }
    else if (state == 2) { fillColor = Colors.green; textColor = Colors.white; }

    return CustomPaint(
      size: Size(width, height),
      painter: HexagonPainter(fillColor),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(fontSize: state == 0 ? 30 : 36, color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class HexagonPainter extends CustomPainter {
  final Color fillColor;
  HexagonPainter(this.fillColor);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.75);
    path.lineTo(0, size.height * 0.25);
    path.close();

    final fillPaint = Paint()..color = fillColor..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()..color = Colors.black..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
