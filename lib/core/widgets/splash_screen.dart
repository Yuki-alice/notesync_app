import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onExit;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.onExit,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  bool _exiting = false;

  void startExit() {
    if (_exiting) return;
    setState(() => _exiting = true);
    Future.delayed(widget.duration, widget.onExit);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final iconSize = size.width < 600 ? 100.0 : 140.0;

    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        opacity: _exiting ? 0.0 : 1.0,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFD8E0D0),
                Color(0xFFC5D1BC),
              ],
            ),
          ),
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              scale: _exiting ? 0.8 : 1.0,
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E1),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icons/komorebi_icon_1024.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.auto_awesome_rounded,
                      size: 50,
                      color: Color(0xFF6B8F5E),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
