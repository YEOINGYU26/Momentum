import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart' as app_auth;

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('메뉴',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _ProfileCard(user: user),
              const SizedBox(height: 24),
              const Text('설정',
                  style: TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const _MenuItem(icon: Icons.notifications_outlined, label: '알림 설정',    sub: '가격 알림 · 전략 알림'),
              const SizedBox(height: 8),
              const _MenuItem(icon: Icons.key_outlined,           label: 'KIS API 설정', sub: '계좌번호 · 인증키'),
              const SizedBox(height: 8),
              const _MenuItem(icon: Icons.dark_mode_outlined,     label: '테마',          sub: '다크 모드'),
              const SizedBox(height: 8),
              const _MenuItem(icon: Icons.receipt_long_outlined,  label: '주문 내역',     sub: '전체 거래 이력 조회'),
              const SizedBox(height: 8),
              const _MenuItem(icon: Icons.info_outline,           label: '앱 정보',       sub: '버전 1.0.0'),
              const SizedBox(height: 24),
              _LogoutButton(onTap: () => context.read<app_auth.AuthProvider>().signOut()),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final User? user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name        = user?.displayName ?? '사용자';
    final email       = user?.email ?? '';
    final photoUrl    = user?.photoURL;
    final initials    = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          if (photoUrl != null)
            ClipOval(child: Image.network(photoUrl, width: 52, height: 52, fit: BoxFit.cover))
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: AppColors.green, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(color: AppColors.gray, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _MenuItem({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gray, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray, size: 20),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('로그아웃',
              style: TextStyle(
                  color: AppColors.red, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
