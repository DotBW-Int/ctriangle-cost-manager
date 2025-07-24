# 💰 CTriangle Cost Manager

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)

A comprehensive **offline-first** financial management app built with Flutter, featuring virtual banking, AI-powered insights, and beautiful analytics.

## ✨ Features

### 💳 Core Financial Management
- **Expense & Income Tracking** with categories and receipt photos
- **Virtual Banking System** for savings goals and financial planning
- **Recurring Transactions** management (bills, rent, subscriptions)
- **Budget Management** with smart notifications
- **Transaction Reversal** capability

### 📊 Advanced Analytics
- **Interactive Charts** (pie, line, bar charts) with `fl_chart`
- **AI-Powered Insights** and spending recommendations
- **Financial Trends** analysis and forecasting
- **Category-wise** spending breakdown

### 🎨 Beautiful UI/UX
- **CTriangle Branding** with signature blue gradient (`#1e40af → #3b82f6 → #60a5fa`)
- **Dark & Light Themes** with seamless toggle
- **Mobile-first Design** optimized for engagement
- **Smooth Animations** and micro-interactions

### 🔒 Privacy & Offline
- **100% Offline** - works without internet connection
- **Local SQLite Database** - your data stays on your device
- **No Account Required** - instant setup and usage
- **Future: Encrypted Cloud Sync** with Google Drive (optional)

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **📱 iOS** | ✅ Working | Both physical devices and simulator |
| **🤖 Android** | ✅ Working | API 36 (Android 16) optimized |
| **🌐 Web** | ✅ Working | Full PWA support with offline database |
| **💻 macOS** | 🔄 Planned | Native macOS app coming soon |

## 🚀 Quick Start

### Prerequisites
- Flutter 3.24.3 or higher
- Dart SDK 3.5.0 or higher
- iOS 12.0+ / Android API 21+

### Installation

```bash
# Clone the repository
git clone https://github.com/DOTBW-Int/ctriangle-cost-manager.git
cd ctriangle-cost-manager

# Install dependencies
flutter pub get

# Run on your preferred platform
flutter run                    # Default device
flutter run -d chrome         # Web browser
flutter run -d ios           # iOS Simulator
flutter run -d android       # Android Emulator
```

### Build for Production

```bash
# iOS Release
flutter build ios --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web
flutter build web --release
```

## 🏗️ Architecture

### 📁 Project Structure
```
lib/
├── main.dart                 # App entry point
├── core/                     # Core functionality
│   ├── database/            # SQLite database layer
│   ├── models/              # Data models
│   ├── providers/           # State management (Provider)
│   └── theme/               # CTriangle theme configuration
├── screens/                 # UI screens
│   ├── dashboard/           # Main dashboard
│   ├── transactions/        # Transaction management
│   ├── analytics/           # Charts and insights
│   ├── virtual_banks/       # Virtual banking
│   └── settings/            # App settings
└── widgets/                 # Reusable UI components
```

### 🔧 Tech Stack
- **Framework**: Flutter 3.24.3
- **Language**: Dart 3.5.0
- **State Management**: Provider
- **Database**: SQLite (sqflite)
- **Charts**: fl_chart
- **Navigation**: GoRouter
- **Icons**: Material Design Icons

### 🎨 Design System
```dart
// CTriangle Brand Colors
const primaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1E40AF), // Blue-700
    Color(0xFF3B82F6), // Blue-500
    Color(0xFF60A5FA), // Blue-400
  ],
);
```

## 📊 Database Schema

### Core Tables
- **transactions** - All income/expense records
- **virtual_banks** - Savings goals and virtual accounts
- **budgets** - Budget management and tracking
- **categories** - Custom expense/income categories
- **recurring_transactions** - Automated recurring entries

## 🎯 Roadmap

### Current Version (v1.0.0)
- ✅ Core expense/income tracking
- ✅ Virtual banking system
- ✅ Beautiful analytics dashboard
- ✅ Cross-platform support (iOS, Android, Web)
- ✅ Dark/Light theme support

### Upcoming Features (v1.1.0)
- 🔄 AI-powered spending insights
- 🔄 Advanced budget management
- 🔄 Receipt OCR scanning
- 🔄 Export/Import functionality
- 🔄 Backup & restore

### Future Releases
- 📅 Encrypted cloud synchronization
- 📅 Multi-currency support
- 📅 Investment tracking
- 📅 Financial goal planning
- 📅 macOS & Windows desktop apps

## 🤝 Contributing

We welcome contributions! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test across platforms
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💫 About CTriangle

**CTriangle** is committed to building beautiful, privacy-focused financial tools that help users take control of their finances without compromising their data security.

### Key Principles
- **Privacy First** - Your data belongs to you
- **Offline Capability** - Works anywhere, anytime
- **Beautiful Design** - Finance apps don't have to be boring
- **Cross-Platform** - One codebase, all platforms

---

<div align="center">

**Built with ❤️ using Flutter**

[Report Bug](https://github.com/Dotbw/ctriangle-cost-manager/issues) • [Request Feature](https://github.com/Dotbw/ctriangle-cost-manager/issues) • [Documentation](https://github.com/Dotbw/ctriangle-cost-manager/wiki)

</div>
