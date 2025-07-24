import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = !_isDarkMode;
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  void setTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = isDark;
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
}

// Custom Theme Switch Widget
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => themeProvider.setTheme(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: !themeProvider.isDarkMode 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 16,
                        color: !themeProvider.isDarkMode 
                            ? Colors.white 
                            : Colors.orange, // Orange sun for light theme
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Light',
                        style: TextStyle(
                          color: !themeProvider.isDarkMode 
                              ? Colors.white 
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => themeProvider.setTheme(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.nightlight_rounded,
                        size: 16,
                        color: themeProvider.isDarkMode 
                            ? Colors.white 
                            : Colors.grey[600], // White moon for dark theme
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Dark',
                        style: TextStyle(
                          color: themeProvider.isDarkMode 
                              ? Colors.white 
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}