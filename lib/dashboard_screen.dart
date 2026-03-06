import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'ali_chat_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _floatAnimation;

  String selectedMood = '';
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> moods = [
    {'emoji': '😊', 'label': 'Calm', 'color': Color(0xFF00D4AA)},
    {'emoji': '😐', 'label': 'Okay', 'color': Color(0xFF4A9EFF)},
    {'emoji': '😔', 'label': 'Low', 'color': Color(0xFF8B6FF0)},
    {'emoji': '😰', 'label': 'Anxious', 'color': Color(0xFFFF6B6B)},
    {'emoji': '😤', 'label': 'Stressed', 'color': Color(0xFFFFB347)},
  ];

  final List<Map<String, dynamic>> appUsage = [
    {'app': 'Instagram', 'hours': 2.5, 'color': Color(0xFFE1306C), 'icon': Icons.photo_camera},
    {'app': 'YouTube', 'hours': 1.8, 'color': Color(0xFFFF0000), 'icon': Icons.play_circle},
    {'app': 'WhatsApp', 'hours': 1.2, 'color': Color(0xFF25D366), 'icon': Icons.message},
    {'app': 'Chrome', 'hours': 0.9, 'color': Color(0xFF4285F4), 'icon': Icons.language},
    {'app': 'Others', 'hours': 0.8, 'color': Color(0xFF888888), 'icon': Icons.apps},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: Duration(seconds: 2), vsync: this)..repeat(reverse: true);
    _slideController = AnimationController(duration: Duration(milliseconds: 1200), vsync: this)..forward();
    _floatController = AnimationController(duration: Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF060D1F),
      body: Stack(
        children: [
          _buildBackgroundOrbs(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _slideAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - _slideAnimation.value)),
                    child: child,
                  ),
                );
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildWellnessScore()),
                  SliverToBoxAdapter(child: _buildMoodDetector()),
                  SliverToBoxAdapter(child: _buildStatsRow()),
                  SliverToBoxAdapter(child: _buildScreenTimeGraph()),
                  SliverToBoxAdapter(child: _buildAppUsage()),
                  SliverToBoxAdapter(child: _buildGentleWarning()),
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          _buildFloatingALIButton(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Positioned(
              top: -80, right: -80,
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0xFF00D4AA).withOpacity(0.15), Colors.transparent]),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 200, left: -100,
          child: Container(
            width: 250, height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xFF0066FF).withOpacity(0.1), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00D4AA), Color(0xFF0066FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00D4AA).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, Gunapriya 👋', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                Text('Your mind matters today 💚', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12)),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                child: Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
              ),
              Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(0xFFFF6B6B), shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessScore() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D2137), Color(0xFF0A1628)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.1), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90, height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(scale: _pulseAnimation.value, child: CustomPaint(size: Size(90, 90), painter: ScoreCirclePainter(0.85))),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('85', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                          Text('/100', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wellness Score', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      SizedBox(height: 4),
                      Text('Feeling Balanced 🌿', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3))),
                        child: Text('↑ 5% better than yesterday', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoodDetector() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('🎨 How are you feeling?', 'Tap to track your mood'),
          SizedBox(height: 12),
          Row(
            children: moods.map((mood) {
              final isSelected = selectedMood == mood['label'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedMood = mood['label']),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? (mood['color'] as Color).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? mood['color'] : Colors.white12, width: isSelected ? 1.5 : 1),
                      boxShadow: isSelected ? [BoxShadow(color: (mood['color'] as Color).withOpacity(0.3), blurRadius: 12, spreadRadius: 1)] : [],
                    ),
                    child: Column(
                      children: [
                        Text(mood['emoji'], style: TextStyle(fontSize: 22)),
                        SizedBox(height: 4),
                        Text(mood['label'], style: TextStyle(color: isSelected ? mood['color'] : Colors.white54, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          _statCard(icon: Icons.bedtime, iconColor: Color(0xFF8B6FF0), label: 'Sleep', value: '7.5 hrs', sub: 'Good rest 😴', color: Color(0xFF8B6FF0)),
          SizedBox(width: 12),
          _statCard(icon: Icons.phone_android, iconColor: Color(0xFF4A9EFF), label: 'Screen Time', value: '4.2 hrs', sub: 'Moderate 📱', color: Color(0xFF4A9EFF)),
          SizedBox(width: 12),
          _statCard(icon: Icons.lock_open, iconColor: Color(0xFFFFB347), label: 'Unlocks', value: '47', sub: 'High usage ⚠️', color: Color(0xFFFFB347)),
        ],
      ),
    );
  }

  Widget _statCard({required IconData icon, required Color iconColor, required String label, required String value, required String sub, required Color color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.25))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: iconColor, size: 16)),
            SizedBox(height: 8),
            Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.white54, fontSize: 10)),
            SizedBox(height: 4),
            Text(sub, style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeGraph() {
    final List<Map<String, dynamic>> weekData = [
      {'day': 'Mon', 'hours': 3.2}, {'day': 'Tue', 'hours': 4.5},
      {'day': 'Wed', 'hours': 2.8}, {'day': 'Thu', 'hours': 5.1},
      {'day': 'Fri', 'hours': 4.2}, {'day': 'Sat', 'hours': 6.3},
      {'day': 'Sun', 'hours': 3.9},
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('📊 Screen Time This Week', 'Daily usage pattern'),
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekData.map((data) {
                final heightPercent = (data['hours'] as double) / 7.0;
                final isToday = data['day'] == 'Fri';
                final barColor = (data['hours'] as double) > 5 ? Color(0xFFFF6B6B) : (data['hours'] as double) > 3.5 ? Color(0xFFFFB347) : Color(0xFF00D4AA);
                return Expanded(
                  child: Column(
                    children: [
                      Text('${data['hours']}h', style: TextStyle(color: barColor, fontSize: 9, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Container(
                        height: (100 * heightPercent).toDouble(),
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [barColor, barColor.withOpacity(0.4)]),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isToday ? [BoxShadow(color: barColor.withOpacity(0.4), blurRadius: 8)] : [],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(data['day'], style: TextStyle(color: isToday ? Colors.white : Colors.white38, fontSize: 10, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _legendDot(Color(0xFF00D4AA), 'Healthy (< 3.5h)'),
                SizedBox(width: 16),
                _legendDot(Color(0xFFFFB347), 'Moderate'),
                SizedBox(width: 16),
                _legendDot(Color(0xFFFF6B6B), 'High (> 5h)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.white38, fontSize: 10))]);
  }

  Widget _buildAppUsage() {
    final totalHours = appUsage.fold(0.0, (sum, app) => sum + (app['hours'] as double));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('📱 App Usage Breakdown', "Today's activity"),
            SizedBox(height: 16),
            ...appUsage.map((app) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(width: 32, height: 32, decoration: BoxDecoration(color: (app['color'] as Color).withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(app['icon'] as IconData, color: app['color'] as Color, size: 16)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(app['app'], style: TextStyle(color: Colors.white, fontSize: 13)),
                            Text('${app['hours']}h', style: TextStyle(color: app['color'] as Color, fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                          SizedBox(height: 4),
                          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (app['hours'] as double) / totalHours, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(app['color'] as Color), minHeight: 6)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGentleWarning() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFFB347).withOpacity(0.15), Color(0xFFFF6B6B).withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFFFFB347).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) => Transform.translate(offset: Offset(0, _floatAnimation.value * 0.3), child: Text('🌙', style: TextStyle(fontSize: 32))),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gentle Reminder 💛', style: TextStyle(color: Color(0xFFFFB347), fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Your sleep hours have been reducing lately. A good rest helps your mind stay strong and clear! 🌿', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingALIButton() {
    return Positioned(
      bottom: 80, right: 20,
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value * 0.5),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ALIChatScreen())),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.5), blurRadius: 20, spreadRadius: 2, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(animation: _pulseAnimation, builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: Icon(Icons.psychology, color: Colors.white, size: 22))),
                    SizedBox(width: 8),
                    Text('Talk to ALI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Color(0xFF0A1628), border: Border(top: BorderSide(color: Colors.white12))),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Color(0xFF00D4AA),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Wellness'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class ScoreCirclePainter extends CustomPainter {
  final double score;
  ScoreCirclePainter(this.score);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 6.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, 2 * math.pi * score, false,
      Paint()
        ..shader = SweepGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)], startAngle: -math.pi / 2, endAngle: -math.pi / 2 + 2 * math.pi * score).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}