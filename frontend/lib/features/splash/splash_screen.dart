import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(AppConfig.onboardingDoneKey) ?? false;
    if (!mounted) {
      return;
    }
    context.go(done ? '/' : '/onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11465B),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Image.network(
              'https://www.figma.com/api/mcp/asset/d036c95b-0901-428b-8d1e-2b5906743b5f',
              width: 280,
              height: 280,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
            ),
          ),
        ),
      ),
    );
  }

  // Fallback if image fails to load
  Widget _buildFallbackLogo() {
    return Container(
      width: 280,
      height: 280,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1A1A2E),
      ),
      child: const Center(
        child: Text(
          'KD',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Color(0xFFBB2BD9),
          ),
        ),
      ),
    );
  }
}
