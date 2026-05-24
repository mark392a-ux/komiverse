import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11465B),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // ── KomiVerse Title ──────────────────────
              const Text(
                'KomiVerse',
                style: TextStyle(
                  fontSize: 56,
                  color: Color(0xFFE7E6EA),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // ── Tagline ──────────────────────────────
              const Text(
                'Watch more, Read more, Explore more\nOnly On KomiVerse',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFFEEFEF),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // ── Platform Icons ───────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PlatformIcon(
                    url:
                        'https://www.figma.com/api/mcp/asset/0d20c803-cc63-4ea5-b4a4-1f13cc6570a3',
                    fallbackText: 'N',
                    color: const Color(0xFF1A1A2E),
                  ),
                  const SizedBox(width: 16),
                  _PlatformIcon(
                    url:
                        'https://www.figma.com/api/mcp/asset/e5d4b353-dd05-43ad-8af7-4387e54db4d1',
                    fallbackText: 'MAL',
                    color: const Color(0xFF2E51A2),
                  ),
                  const SizedBox(width: 16),
                  _PlatformIcon(
                    url:
                        'https://www.figma.com/api/mcp/asset/9798fb71-d38e-466b-8c1b-452b57a4bd61',
                    fallbackText: 'A',
                    color: const Color(0xFF02A9FF),
                  ),
                  const SizedBox(width: 16),
                  _PlatformIcon(
                    url:
                        'https://www.figma.com/api/mcp/asset/bc62d92a-c274-4447-8814-d3d071c271d0',
                    fallbackText: '🪐',
                    color: const Color(0xFFFF6B35),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // ── Get Started Button ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(AppConfig.onboardingDoneKey, true);
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB2BD9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformIcon extends StatelessWidget {
  final String url;
  final String fallbackText;
  final Color color;

  const _PlatformIcon({
    required this.url,
    required this.fallbackText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 51,
        height: 51,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 51,
          height: 51,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              fallbackText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
