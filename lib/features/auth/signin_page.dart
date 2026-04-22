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
      
      // v13: ambient radial gradient (Cool Ink with a hint of warm
      // blue light at top-left + dusky blue at bottom-right). The
      // background does the visual lifting; copy stays minimal.
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Radial wash that lifts the top-left corner off pure
                // ink. `ink2` is the kit's raised-surface shade; the
                // outer stop uses `AppTheme.bg` so a future theme flip
                // (day mode on signin) inherits the right base.
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.7),
                  radius: 1.1,
                  colors: [AppTheme.ink2, AppTheme.bg],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),
          // Soft secondary glow bottom-right — uses the cool accent
          // from the kit (`--accent-2 #5B8BFF`) at 18% alpha, matching
          // the kit's `--accent-bg` recipe.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, 0.9),
                    radius: 0.9,
                    colors: [
                      AppTheme.accentBg,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset + 40),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Brand — wide letter-spacing per v13 spec.
                Text(
                  'POSTER.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    // Day mode inverts the scaffold to white — the brand
                    // must flip to near-black to stay readable.
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '探索電影海報的世界',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMute,
                  ),
                ),
                const Spacer(flex: 4),
                _WhitePill(
                  label: '使用 Google 登入',
                  icon: PhosphorIconsRegular.googleLogo,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(authRepositoryProvider).signInWithGoogle();
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  '繼續即同意條款',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textFaint,
                    letterSpacing: 0.5,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inverted pill button — fill is the ink colour of the current mode
/// (white in night, near-black in day) with the label/icon inverted
/// to match (`AppTheme.bg`). Named "white" for historical reasons
/// (night-only origin); the fill is theme-adaptive.
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
    // `fg` is always the contrast of `AppTheme.text`. Matches the kit's
    // `.btn--solid { background: var(--text); color: var(--ink); }`.
    final fg = AppTheme.bg;
    return Material(
      color: AppTheme.text,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
