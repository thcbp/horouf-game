import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';

void main() {
  runApp(const HoroufGameApp());
}

// =================== البيانات المركزية (بنك الأسئلة) ===================
// جعلنا البنك متاحاً لجميع الشاشات لكي يسهل تعديله وقراءته
class GlobalData {
  static Map<String, List<Map<String, String>>> questionBank = {
    'أ': [{'q': 'حيوان مفترس يلقب بملك الغابة؟', 'a': 'أسد'}, {'q': 'دولة عربية عاصمتها عمّان؟', 'a': 'أردن'}],
    'ب': [{'q': 'عاصمة فرنسا؟', 'a': 'باريس'}, {'q': 'طائر لا يطير يعيش في الجليد؟', 'a': 'بطريق'}],
    'ت': [{'q': 'فاكهة حمراء يحبها الكثيرون؟', 'a': 'تفاح'}, {'q': 'حيوان زاحف برمائي ضخم؟', 'a': 'تمساح'}],
  };

  static final List<String> allArabicLetters = [
    'أ','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص',
    'ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','هـ','و','ي'
  ];
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
      home: const MainMenuScreen(), // البداية من القائمة الرئيسية
    );
  }
}

// =================== الشاشة الأولى: القائمة الرئيسية ===================
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
                TextField(
                  controller: hostController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(labelText: 'اسم مقدم اللعبة (الهوست)', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: t1Controller,
                  style: const TextStyle(color: Colors.orange, fontSize: 18),
                  decoration: const InputDecoration(labelText: 'اسم الفريق 1 (أفقي ↔)', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: t2Controller,
                  style: const TextStyle(color: Colors.green, fontSize: 18),
                  decoration: const InputDecoration(labelText: 'اسم الفريق 2 (عمودي ↕)', labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('انطلق للوحة اللعب!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(context); // إغلاق النافذة
                // الانتقال إلى شاشة اللعب وتمرير الأسماء
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            )
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
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF12121A).withOpacity(0.85), // خلفية زجاجية شفافة
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // الشعار (العنوان)
                const Text('حـــروف', style: TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5)),
                const SizedBox(height: 10),
                const Text('النسخة الاحترافية', style: TextStyle(fontSize: 20, color: Colors.orangeAccent)),
                const SizedBox(height: 50),
                
                // زر البداية
                SizedBox(
                  width: 300,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                    ),
                    icon: const Icon(Icons.play_circle_fill, size: 30, color: Colors.white),
                    label: const Text('ابدأ اللعبة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () => _showStartSettings(context),
                  ),
                ),
                const SizedBox(height: 20),
                
                // زر بنك الأسئلة
                SizedBox(
                  width: 300,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.storage, size: 28, color: Colors.white70),
                    label: const Text('بنك الأسئلة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionBankScreen()));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =================== الشاشة الثانية: بنك الأسئلة ===================
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  
  // إضافة سؤال يدوي
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
              title: const Text('إضافة سؤال جديد', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedLetter,
                    dropdownColor: const Color(0xFF2D2D44),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.bold),
                    items: GlobalData.allArabicLetters.map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text("حرف ( $value )"));
                    }).toList(),
                    onChanged: (newValue) => setDialogState(() => selectedLetter = newValue!),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: qController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'السؤال')),
                  TextField(controller: aController, style: const TextStyle(color: Colors.greenAccent), decoration: const InputDecoration(labelText: 'الإجابة')),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (qController.text.isNotEmpty && aController.text.isNotEmpty) {
                      setState(() {
                        if (!GlobalData.questionBank.containsKey(selectedLetter)) {
                          GlobalData.questionBank[selectedLetter] = [];
                        }
                        GlobalData.questionBank[selectedLetter]!.add({'q': qController.text, 'a': aController.text});
                      });
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

  // الاستيراد الذكي (JSON Paste)
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
              decoration: const InputDecoration(
                hintText: 'الصق كود JSON هنا...\nمثال:\n{"أ": [{"q":"سؤال", "a":"جواب"}]}',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
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
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استيراد الأسئلة بنجاح!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في صيغة الـ JSON! تأكد من التنسيق.'), backgroundColor: Colors.red));
                }
              },
              child: const Text('استيراد الآن', style: TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(
            tooltip: 'استيراد الأسئلة (JSON)',
            icon: const Icon(Icons.data_object, color: Colors.blueAccent),
            onPressed: _showImportDialog,
          ),
        ],
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

// =================== الشاشة الثالثة: لوحة اللعب (نفس التطوير السابق) ===================
class GameBoardScreen extends StatefulWidget {
  final String hostName;
  final String team1Name;
  final String team2Name;

  const GameBoardScreen({
    super.key, 
    required this.hostName, 
    required this.team1Name, 
    required this.team2Name
  });

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
    
    // سحب الأسئلة من البيانات المركزية
    List<Map<String, String>> questions = GlobalData.questionBank[letter] ?? [
      {'q': 'لم تقم بإضافة أسئلة لحرف ( $letter ) في بنك الأسئلة!', 'a': '---'}
    ];

    int currentQIndex = 0;
    bool isAnswerRevealed = false;

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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isAnswerRevealed ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isAnswerRevealed ? Colors.blueAccent : Colors.transparent),
                  ),
                  child: Text(
                    isAnswerRevealed ? 'الإجابة: ${questions[currentQIndex]['a']}' : '--- الإجابة مخفية ---',
                    style: TextStyle(color: isAnswerRevealed ? Colors.blueAccent : Colors.white38, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text('تغيير السؤال', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        setDialogState(() {
                          currentQIndex = (currentQIndex + 1) % questions.length;
                          isAnswerRevealed = false;
                        });
                      },
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      icon: Icon(isAnswerRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                      label: Text(isAnswerRevealed ? 'إخفاء الإجابة' : 'إظهار الإجابة', style: const TextStyle(color: Colors.white)),
                      onPressed: () {
                        setDialogState(() { isAnswerRevealed = !isAnswerRevealed; });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                onPressed: () { Navigator.pop(context); _makeMove(r, c, 1); },
                child: Text('فوز ${widget.team1Name}', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                onPressed: () { Navigator.pop(context); _makeMove(r, c, 2); },
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
            // الهيدر
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
                            onPressed: () => Navigator.pop(context), // العودة للقائمة الرئيسية
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
            
            // منطقة اللعب
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

// =================== أدوات الرسم (الخلفية والخلايا) ===================
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
