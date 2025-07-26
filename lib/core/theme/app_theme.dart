import 'package:flutter/material.dart';

class AppTheme {
  // CTriangle brand colors and gradient
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color lightBlue = Color(0xFF60a5fa);
  static const Color darkBlue = Color(0xFF1e40af);
  
  // CTriangle gradient (also expose as primaryGradient for compatibility)
  static const LinearGradient ctriangleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1e40af), // darkBlue
      Color(0xFF3b82f6), // primaryBlue
      Color(0xFF60a5fa), // lightBlue
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Income gradient (green variant)
  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF166534), // dark green
      Color(0xFF16a34a), // green
      Color(0xFF4ade80), // light green
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Expense gradient (red variant)
  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF991b1b), // dark red
      Color(0xFFdc2626), // red
      Color(0xFFf87171), // light red
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Alias for compatibility
  static const LinearGradient primaryGradient = ctriangleGradient;

  // Helper method to create gradient button style
  static ButtonStyle gradientButtonStyle({
    Color? overlayColor,
    EdgeInsetsGeometry? padding,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // Helper method to create gradient container
  static Widget gradientButton({
    required Widget child,
    required VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: ctriangleGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }

  // Helper for gradient icon button
  static Widget gradientIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 24,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: ctriangleGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: size,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white, // Consistent white background
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white, // Same as scaffold
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white, // Prevent color tinting
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    const Color darkGrayBackground = Color(0xFF2D2D2D); // Dark gray background
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        surface: darkGrayBackground,
      ),
      scaffoldBackgroundColor: darkGrayBackground, // Dark gray background
      appBarTheme: const AppBarTheme(
        backgroundColor: darkGrayBackground, // Same as scaffold
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: darkGrayBackground, // Prevent color tinting
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF3D3D3D), // Slightly lighter gray for cards
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
    );
  }

  // Helper method to create dynamic gradient container based on transaction type
  static Widget dynamicGradientButton({
    required Widget child,
    required VoidCallback? onPressed,
    required String transactionType, // 'income', 'expense', or 'default'
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    LinearGradient gradient;
    Color shadowColor;
    
    switch (transactionType) {
      case 'income':
        gradient = incomeGradient;
        shadowColor = const Color(0xFF16a34a);
        break;
      case 'expense':
        gradient = expenseGradient;
        shadowColor = const Color(0xFFdc2626);
        break;
      default:
        gradient = ctriangleGradient;
        shadowColor = primaryBlue;
        break;
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Custom Gradient Button Widget
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 48,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Center(
              child: Text(
                text,
                style: textStyle ?? const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}