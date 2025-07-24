<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# CTriangle Cost Manager - Flutter Application

## Project Overview
This is a Flutter-based cost management application for Android and iOS with the following key features:
- Local SQLite database (no internet required)
- Virtual banking system for savings goals
- Recurring transactions management
- Advanced analytics with charts
- AI-powered financial insights
- Dark/Light theme support

## UI/UX Guidelines
- **Brand Colors**: 
  - Primary gradient: `linear-gradient(135deg, #1e40af, #3b82f6, #60a5fa)`
  - Brand name: "CTriangle" (short: "CT")
  - "C" should be blue (#3b82f6) in both themes
  - "T" should be light in dark theme, dark in light theme
- **Design**: Mobile-first, engaging, impressive UI
- **Themes**: Dark and light with toggle switch

## Architecture
- **State Management**: Provider or Riverpod
- **Database**: SQLite (sqflite) for local storage
- **Charts**: fl_chart for analytics
- **Navigation**: Go Router
- **Offline-first**: All features work without internet

## Key Features to Implement
1. Expense tracking with categories and receipt photos
2. Income management
3. Virtual bank accounts for savings goals
4. Recurring transactions (rent, insurance, bills)
5. Budget management with notifications
6. Analytics dashboard with pie, line, bar charts
7. AI-powered spending insights and suggestions
8. Transaction reversal capability
9. Future: Encrypted cloud sync with Google Drive