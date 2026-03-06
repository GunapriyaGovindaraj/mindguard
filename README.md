# 🧠 MindGuard — AI-Powered Mental Health Early Warning System

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41.4-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
  <img src="https://img.shields.io/badge/Gemini_AI-2.0_Flash-4285F4?style=for-the-badge&logo=google&logoColor=white"/>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white"/>
  <img src="https://img.shields.io/badge/Hackathon-Project-FF6B6B?style=for-the-badge"/>
</p>

<p align="center">
  <b>MindGuard silently learns your digital behaviour over 7 days, detects early signs of stress or mental health decline, and alerts you — before it becomes serious.</b>
</p>

---

## 📱 What is MindGuard?

Most mental health apps wait for you to report how you feel. **MindGuard doesn't wait.**

It passively tracks your daily digital behaviour — screen time, sleep patterns, phone unlock frequency, and app usage — builds a **personal baseline** over 7 days, and then automatically detects when your patterns deviate. When something seems off, it gently notifies you, offers support through **ALI** (our AI companion), and can alert a trusted emergency contact if needed.

> Think of it as a silent guardian that knows your normal — and notices when you're not.

---

## ✨ Key Features

### 🌱 7-Day Baseline Learning
- App runs silently in the background for 7 days
- Learns YOUR normal: sleep hours, screen time, unlock frequency, social media usage
- No two users have the same baseline — it's completely personalized

### 📊 Smart Dashboard
- **3 states**: No profile → Collecting baseline → Full comparison mode
- Real-time wellness score (0–100) calculated vs your personal baseline
- Comparison cards showing Today vs Your Average with % change
- Color-coded alerts: green (normal), yellow (mild), orange (moderate), red (critical)
- Screen time & sleep trend graphs with baseline reference line
- App usage breakdown

### 🤖 ALI — AI Mental Health Companion
- Powered by **Google Gemini 2.0 Flash**
- Talks like a caring human friend, not a robot
- Uses **CBT (Cognitive Behavioural Therapy)** techniques
- Always gives 3 conversation suggestions to keep the chat flowing naturally
- Full free-text input — type anything, ALI responds like a real person
- Remembers the full conversation context
- Gently suggests professional help when needed

### 👤 Smart Profile
- Saves user data to **Firebase Realtime Database**
- Tracks emergency contact for auto-alerts
- Auto-detects risk level from last 3 days of data
- Manual "I Need Help Now" SOS button
- Displays personalised risk banners when patterns are concerning

### 🚨 Early Warning System
- Wellness score drops when patterns deviate from baseline
- Automatic emergency contact notification if 3+ consecutive bad days detected
- Gentle, comforting language — never alarming or clinical
- "Serious Signs Detected" banner with auto-alert confirmation

---

## 🏗️ Project Structure

```
mindguard/
├── lib/
│   ├── main.dart                    # Splash screen + app entry point
│   ├── dashboard_screen.dart        # Smart main dashboard (3 states)
│   ├── ali_chat_screen.dart         # ALI AI chatbot (Gemini powered)
│   ├── profile_screen.dart          # User profile + Firebase + SOS
│   ├── models/
│   │   └── daily_data_model.dart    # Data models (DailyData, BaselineData, AnalysisResult)
│   ├── services/
│   │   ├── data_service.dart        # SharedPreferences data manager
│   │   ├── usage_stats_service.dart # Real Android tracking + simulated fallback
│   │   └── analysis_engine.dart     # Baseline comparison + wellness scoring
│   └── screens/
│       └── insights_screen.dart     # 14-day comparison insights
├── android/
│   └── app/src/main/kotlin/
│       └── MainActivity.kt          # Android UsageStats native channel
└── pubspec.yaml
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.41.4 (Dart) |
| AI Chatbot | Google Gemini 2.0 Flash API |
| Database | Firebase Realtime Database |
| Local Storage | SharedPreferences |
| Usage Tracking | Android UsageStatsManager (native channel) |
| Fonts | Google Fonts (Poppins) |
| State Management | Flutter StatefulWidget + setState |
| HTTP | Dart `http` package |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.41.4+
- Android Studio with Android SDK
- A physical Android device or emulator (API 21+)
- Firebase project (free tier)
- Google Gemini API key (free at [aistudio.google.com](https://aistudio.google.com))

### 1. Clone the Repository
```bash
git clone https://github.com/YOUR_USERNAME/mindguard.git
cd mindguard
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Set Up Firebase
1. Go to [Firebase Console](https://console.firebase.google.com) → Create project
2. Add Android app with package name `com.example.mindguard`
3. Download `google-services.json` → place in `android/app/`
4. Enable **Realtime Database** in Firebase Console → Start in test mode

### 4. Add Your Gemini API Key
Open `lib/ali_chat_screen.dart` and replace:
```dart
final String _apiKey = 'YOUR_GEMINI_API_KEY';
```
Get your free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

### 5. Grant Usage Stats Permission (for real tracking)
On your Android device:
> Settings → Apps → Special App Access → Usage Access → MindGuard → Allow

### 6. Run the App
```bash
flutter run
```

---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.1.0
  http: ^1.1.0
  provider: ^6.1.1
  shared_preferences: ^2.2.2
  firebase_core: ^2.24.2
  firebase_database: ^10.4.0
  permission_handler: ^11.3.0
```

---

## 🔐 Permissions Required

| Permission | Reason |
|-----------|--------|
| `INTERNET` | Firebase + Gemini API calls |
| `PACKAGE_USAGE_STATS` | Real screen time tracking |

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions"/>
```

---

## 🧪 How the Wellness Score Works

```
Score starts at 100

Screen time > 30% above baseline  →  -10 points
Screen time > 60% above baseline  →  -20 points

Sleep     > 20% below baseline    →  -10 points
Sleep     > 35% below baseline    →  -20 points

Social media > 50% above baseline →  -15 points
Unlock count > 50% above baseline →  -10 points

Score 85–100  →  🌿 Feeling Balanced    (green)
Score 65–84   →  💛 Mild Changes        (yellow)
Score 45–64   →  🌙 Needs Attention     (orange)
Score 0–44    →  🫂 Please Take Care    (red)
```

---

## 📸 Screenshots

> *Dashboard · ALI Chat · Profile · Insights*

| Dashboard (Ready) | ALI Chatbot | Profile | Collecting |
|:-:|:-:|:-:|:-:|
| ![dashboard](screenshots/dashboard.png) | ![ali](screenshots/ali.png) | ![profile](screenshots/profile.png) | ![collecting](screenshots/collecting.png) |

---

## 🗺️ Roadmap

- [x] Smart dashboard with 3 states
- [x] 7-day baseline learning
- [x] ALI AI chatbot (Gemini powered)
- [x] Firebase profile + emergency alerts
- [x] Real Android usage stats tracking
- [ ] Onboarding screen
- [ ] Push notifications & smart warnings
- [ ] Smartwatch heart rate integration
- [ ] Mood history analytics
- [ ] Voice input for ALI
- [ ] iOS support

---

## 👩‍💻 Built By

**Gunapriya** — Built for hackathon with ❤️

> MindGuard was created with the belief that mental health support should be proactive, not reactive. Everyone deserves a silent guardian that notices before things get serious.

---

## ⚠️ Disclaimer

MindGuard is **not a medical device** and is not intended to diagnose, treat, or replace professional mental health care. If you or someone you know is in crisis, please contact a licensed mental health professional or a crisis helpline immediately.

**India:** iCall — 9152987821 | Vandrevala Foundation — 1860-2662-345

---

## 📄 License

```
MIT License — feel free to use, modify, and build on this project.
```

---

<p align="center">Made with 💚 for mental health awareness</p>
