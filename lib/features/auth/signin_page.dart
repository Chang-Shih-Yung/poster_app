import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // TODO(v11): remove when Google logo is replaced

import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

/// Signin page — v11 extreme minimal.
///
/// Brand name + one line + Google button. That's it.
class SigninPage extends ConsumerWidget {
  const SigninPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 40),
        child: Column(
          children: [
            const Spacer(flex: 3),

            // Brand.
            Text(
              'POSTER.',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // One-liner.
            Text(
              '探索電影海報的世界',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMute,
              ),
            ),

            const Spacer(flex: 4),

            // Google sign-in CTA.
            _WhitePill(
              label: '使用 Google 登入',
              icon: PhosphorIconsRegular.googleLogo,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(authRepositoryProvider).signInWithGoogle();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  const _WhitePill({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.black),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
