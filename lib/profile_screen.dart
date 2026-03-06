import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _dataExists = false;

  final _nameController        = TextEditingController();
  final _ageController         = TextEditingController();
  final _sleepController       = TextEditingController();
  final _socialMediaController = TextEditingController();
  final _emergencyController   = TextEditingController();
  final _emergencyNameController = TextEditingController();

  String _selectedRole = 'Student';
  final List<String> _roles = ['Student', 'Working', 'Others'];

  // Risk level tracked from Firebase
  String _riskLevel = 'normal'; // normal / warning / serious
  bool _alertSent = false;

  final DatabaseReference _database =
      FirebaseDatabase.instance.ref('users/user_001');

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800), vsync: this)..forward();
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _loadUserData();
    _checkRiskLevel();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _sleepController.dispose();
    _socialMediaController.dispose();
    _emergencyController.dispose();
    _emergencyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final snap = await _database.get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _nameController.text        = data['name']             ?? '';
          _ageController.text         = data['age']?.toString()  ?? '';
          _selectedRole               = data['role']             ?? 'Student';
          _sleepController.text       = data['avgSleepHours']?.toString()    ?? '';
          _socialMediaController.text = data['socialMediaHours']?.toString() ?? '';
          _emergencyController.text   = data['emergencyContact']    ?? '';
          _emergencyNameController.text = data['emergencyName']     ?? '';
          _alertSent                  = data['alertSent']           ?? false;
          _dataExists = true;
          _isLoading  = false;
        });
      } else {
        setState(() { _isEditing = true; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _isEditing = true; _isLoading = false; });
    }
  }

  Future<void> _checkRiskLevel() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/user_001/tracking')
          .orderByKey()
          .limitToLast(3)
          .get();
      if (!snap.exists) return;

      final data = Map<String, dynamic>.from(snap.value as Map);
      int badDays = 0;

      for (final entry in data.entries) {
        final day = Map<String, dynamic>.from(entry.value as Map);
        final sleep  = (day['sleep']      as num?)?.toDouble() ?? 7.0;
        final screen = (day['screentime'] as num?)?.toDouble() ?? 4.0;
        final mood   = day['mood'] as String? ?? '';

        bool isBad = false;
        if (sleep < 5)    isBad = true;
        if (screen > 8)   isBad = true;
        if (mood == '😔 Low' || mood == '😰 Anxious' || mood == '😤 Stressed') isBad = true;
        if (isBad) badDays++;
      }

      setState(() {
        if (badDays >= 3)      _riskLevel = 'serious';
        else if (badDays >= 2) _riskLevel = 'warning';
        else                   _riskLevel = 'normal';
      });

      // Auto-trigger emergency alert if serious
      if (_riskLevel == 'serious' && !_alertSent) {
        _triggerEmergencyAlert();
      }
    } catch (e) {}
  }

  Future<void> _triggerEmergencyAlert({bool manual = false}) async {
    final contact = _emergencyController.text.trim();
    final name    = _emergencyNameController.text.trim();
    final userName = _nameController.text.trim();

    if (contact.isEmpty) {
      _showSnackBar('Please add an emergency contact first! 🚨', isError: true);
      return;
    }

    // Save alert to Firebase
    await _database.update({
      'alertSent': true,
      'alertTimestamp': DateTime.now().toIso8601String(),
      'alertReason': manual ? 'Manual trigger' : 'Auto: 3+ consecutive bad days',
    });

    setState(() { _alertSent = true; });

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.emergency, color: Color(0xFFFF6B6B), size: 24),
          SizedBox(width: 8),
          Text('Emergency Alert', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('An alert has been recorded for:', style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(0xFFFF6B6B).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFFF6B6B).withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('👤 ${name.isEmpty ? 'Emergency Contact' : name}', style: TextStyle(color: Colors.white, fontSize: 13)),
              Text('📞 $contact', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
            ]),
          ),
          SizedBox(height: 12),
          Text(
            manual
              ? '${userName.isEmpty ? 'The user' : userName} manually requested support. Please reach out to them.'
              : '${userName.isEmpty ? 'The user' : userName} has shown signs of distress for multiple days. Please check in with them.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFF00D4AA))),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserData() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name! 💚', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _database.update({
        'name':             _nameController.text.trim(),
        'age':              int.tryParse(_ageController.text) ?? 0,
        'role':             _selectedRole,
        'avgSleepHours':    double.tryParse(_sleepController.text) ?? 0.0,
        'socialMediaHours': double.tryParse(_socialMediaController.text) ?? 0.0,
        'emergencyContact': _emergencyController.text.trim(),
        'emergencyName':    _emergencyNameController.text.trim(),
        'updatedAt':        DateTime.now().toIso8601String(),
      });
      setState(() { _isSaving = false; _isEditing = false; _dataExists = true; });
      _showSnackBar('Profile updated successfully! 💚');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Error saving! Try again ❌', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: isError ? Color(0xFFFF6B6B) : Color(0xFF00D4AA),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF060D1F),
      body: Stack(children: [
        // Background orbs
        Positioned(top: -60, right: -60, child: Container(
          width: 250, height: 250,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0xFF00D4AA).withOpacity(0.12), Colors.transparent])),
        )),
        Positioned(bottom: 100, left: -80, child: Container(
          width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0xFF0066FF).withOpacity(0.10), Colors.transparent])),
        )),

        SafeArea(child: _isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: Color(0xFF00D4AA)),
              SizedBox(height: 16),
              Text('Loading your profile...', style: TextStyle(color: Colors.white54, fontSize: 14)),
            ]))
          : AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) => Opacity(
                opacity: _slideAnimation.value,
                child: Transform.translate(offset: Offset(0, 30 * (1 - _slideAnimation.value)), child: child),
              ),
              child: Column(children: [
                _buildHeader(),
                Expanded(child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [
                    _buildProfileAvatar(),
                    SizedBox(height: 16),

                    // Risk level banner
                    if (_riskLevel != 'normal') _buildRiskBanner(),
                    if (_riskLevel != 'normal') SizedBox(height: 16),

                    _buildSection(
                      title: '👤 Personal Info',
                      subtitle: 'Your basic details',
                      children: [
                        _buildTextField(controller: _nameController,        label: 'Full Name',   hint: 'Enter your name',  icon: Icons.person_outline),
                        SizedBox(height: 14),
                        _buildTextField(controller: _ageController,         label: 'Age',         hint: 'Enter your age',   icon: Icons.cake_outlined, keyboardType: TextInputType.number),
                        SizedBox(height: 14),
                        _buildRoleSelector(),
                      ],
                    ),
                    SizedBox(height: 16),

                    _buildSection(
                      title: '📊 Behaviour Data',
                      subtitle: 'Helps us understand your patterns',
                      children: [
                        _buildTextField(controller: _sleepController,       label: 'Average Sleep Hours',       hint: 'e.g. 7.5', icon: Icons.bedtime_outlined,      keyboardType: TextInputType.numberWithOptions(decimal: true)),
                        SizedBox(height: 14),
                        _buildTextField(controller: _socialMediaController, label: 'Daily Social Media Hours',  hint: 'e.g. 3.0', icon: Icons.phone_android_outlined, keyboardType: TextInputType.numberWithOptions(decimal: true)),
                      ],
                    ),
                    SizedBox(height: 16),

                    _buildSection(
                      title: '🚨 Emergency Contact',
                      subtitle: 'We notify them if your wellbeing needs attention',
                      children: [
                        _buildTextField(controller: _emergencyNameController, label: 'Contact Name', hint: 'e.g. Mom, Best friend', icon: Icons.person_pin_outlined),
                        SizedBox(height: 14),
                        _buildTextField(controller: _emergencyController,     label: 'Phone Number',  hint: 'Enter phone number',    icon: Icons.emergency_outlined, keyboardType: TextInputType.phone),
                        SizedBox(height: 14),
                        // Manual SOS button
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: Color(0xFF0D1F35),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Send Alert?', style: TextStyle(color: Colors.white)),
                                content: Text('This will notify your emergency contact that you need support right now.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white54))),
                                  TextButton(
                                    onPressed: () { Navigator.pop(context); _triggerEmergencyAlert(manual: true); },
                                    child: Text('Send Alert', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF6B6B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Color(0xFFFF6B6B).withOpacity(0.4)),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.sos, color: Color(0xFFFF6B6B), size: 20),
                              SizedBox(width: 8),
                              Text('I Need Help Now', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    if (_isEditing) _buildSaveButton(),
                    SizedBox(height: 20),
                  ]),
                )),
              ]),
            ),
        ),
      ]),
    );
  }

  Widget _buildRiskBanner() {
    final isSerious = _riskLevel == 'serious';
    final color = isSerious ? Color(0xFFFF6B6B) : Color(0xFFFFB347);
    final icon  = isSerious ? '🚨' : '⚠️';
    final title = isSerious ? 'Serious Signs Detected' : 'Early Warning Signs';
    final msg   = isSerious
        ? 'Your behaviour patterns suggest you may need support. ALI has notified your emergency contact.'
        : 'Your sleep or mood patterns have been below normal. Please take care of yourself 💚';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: TextStyle(fontSize: 24)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(msg, style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          if (isSerious && _alertSent) ...[
            SizedBox(height: 6),
            Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF00D4AA), size: 14),
              SizedBox(width: 4),
              Text('Emergency contact notified ✅', style: TextStyle(color: Color(0xFF00D4AA), fontSize: 11)),
            ]),
          ],
        ])),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07)))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(_dataExists ? 'Saved on Firebase 🔥' : 'Fill your details 💚',
              style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12)),
        ])),
        GestureDetector(
          onTap: () => setState(() {
            _isEditing = !_isEditing;
            if (!_isEditing) _loadUserData();
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: _isEditing
                  ? LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                  : LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: (_isEditing ? Color(0xFFFF6B6B) : Color(0xFF00D4AA)).withOpacity(0.4), blurRadius: 10)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isEditing ? Icons.close : Icons.edit_outlined, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(_isEditing ? 'Cancel' : 'Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildProfileAvatar() {
    final name    = _nameController.text;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
          boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.4), blurRadius: 20, spreadRadius: 3)],
        ),
        child: Center(child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
      ),
      SizedBox(height: 12),
      if (name.isNotEmpty) ...[
        Text(name, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Color(0xFF00D4AA).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Color(0xFF00D4AA).withOpacity(0.3))),
          child: Text(_selectedRole, style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12)),
        ),
      ] else
        Text('Complete your profile 💚', style: TextStyle(color: Colors.white54, fontSize: 14)),
    ]);
  }

  Widget _buildSection({required String title, required String subtitle, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,    style: TextStyle(color: Colors.white,   fontSize: 15, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11)),
        SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: _isEditing ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _isEditing ? Color(0xFF00D4AA).withOpacity(0.4) : Colors.white12),
        ),
        child: TextField(
          controller: controller,
          enabled: _isEditing,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(icon, color: _isEditing ? Color(0xFF00D4AA) : Colors.white38, size: 18),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ),
    ]);
  }

  Widget _buildRoleSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Role', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      SizedBox(height: 8),
      Row(
        children: _roles.map((role) {
          final isSelected = _selectedRole == role;
          final roleIcon = role == 'Student' ? '🎓' : role == 'Working' ? '💼' : '✨';
          return Expanded(child: GestureDetector(
            onTap: _isEditing ? () => setState(() => _selectedRole = role) : null,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: role != _roles.last ? 8 : 0),
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF00D4AA).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Color(0xFF00D4AA) : Colors.white12, width: isSelected ? 1.5 : 1),
              ),
              child: Column(children: [
                Text(roleIcon, style: TextStyle(fontSize: 20)),
                SizedBox(height: 4),
                Text(role, style: TextStyle(color: isSelected ? Color(0xFF00D4AA) : Colors.white54, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
          ));
        }).toList(),
      ),
    ]);
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveUserData,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF00D4AA), Color(0xFF0066FF)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Color(0xFF00D4AA).withOpacity(0.4), blurRadius: 20, spreadRadius: 2, offset: Offset(0, 4))],
        ),
        child: Center(child: _isSaving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text('Saving...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Save Profile 🔥', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
        ),
      ),
    );
  }
}