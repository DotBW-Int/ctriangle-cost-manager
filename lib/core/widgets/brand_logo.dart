import 'package:flutter/material.dart';

class CTriangleLogo extends StatefulWidget {
  final double fontSize;
  final bool showFullName;

  const CTriangleLogo({
    super.key,
    this.fontSize = 24,
    this.showFullName = true,
  });

  @override
  State<CTriangleLogo> createState() => _CTriangleLogoState();
}

class _CTriangleLogoState extends State<CTriangleLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Text
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "C" - Always blue in both themes
            Text(
              'C',
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900, // Extra bold
                color: const Color(0xFF3B82F6), // Always blue
              ),
            ),
            // "T" - Light in dark theme, dark in light theme
            Text(
              widget.showFullName ? 'Triangle' : 'T',
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900, // Extra bold
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Animated Underline
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: widget.showFullName ? widget.fontSize * 4.5 : widget.fontSize * 1.2,
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
              ),
              child: Stack(
                children: [
                  // Background line - using C's blue color with opacity
                  Container(
                    width: double.infinity,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.2), // Blue with opacity
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  // Animated line - bright blue like C
                  Positioned(
                    left: _animation.value * (widget.showFullName ? widget.fontSize * 4.5 : widget.fontSize * 1.2) - 20,
                    child: Container(
                      width: 20,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            const Color(0xFF3B82F6), // Same blue as C
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class CTriangleIcon extends StatelessWidget {
  final double size;
  
  const CTriangleIcon({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E40AF),
            Color(0xFF3B82F6),
            Color(0xFF60A5FA),
          ],
        ),
      ),
      child: Center(
        child: Text(
          'CT',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w900, // Extra bold
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}