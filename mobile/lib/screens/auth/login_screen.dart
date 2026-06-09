import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../main.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 로그인 성공 시 MainScaffold로 이동
        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScaffold()),
              (_) => false,
            );
          });
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator(color: AppColors.green)),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: Consumer<app_auth.AuthProvider>(
            builder: (context, auth, _) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      _Logo(),
                      const Spacer(flex: 2),
                      if (auth.error != null) _ErrorBanner(message: auth.error!),
                      if (auth.loading)
                        const CircularProgressIndicator(color: AppColors.green)
                      else ...[
                        _GoogleButton(onTap: auth.signInWithGoogle),
                        if (!kIsWeb) ...[
                          const SizedBox(height: 12),
                          _AppleButton(onTap: auth.signInWithApple),
                        ],
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00C853), width: 1.5),
          ),
          child: const Icon(Icons.show_chart, size: 44, color: Color(0xFF00C853)),
        ),
        const SizedBox(height: 20),
        const Text(
          'KIS 자동매매',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '로그인하여 시작하세요',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          width: 20,
          height: 20,
          errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
        ),
        label: const Text('Google로 계속하기', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AppleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.apple, size: 22),
        label: const Text('Apple로 계속하기', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}
