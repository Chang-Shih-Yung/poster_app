import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart'; // TODO(v11): remove when Google logo is replaced

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ds/ds.dart';
import '../../data/repositories/auth_repository.dart';

/// Signin page — v11 extreme minimal.
///
/// Brand name + one line + Google button. That's it.
///
/// Supports a `?switch=1` query param: when present, auto-launches
/// Google OAuth with `prompt=select_account` the moment the page
/// mounts. Users tapping 切換帳號 on the profile page land here and
/// are handed straight to Google's account chooser without an
/// extra click on the 使用 Google 登入 button.
class SigninPage extends ConsumerStatefulWidget {
  const SigninPage({super.key});

  @override
  ConsumerState<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends ConsumerState<SigninPage> {
  bool _autoLaunched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Query-param read lives here (not initState) because
    // GoRouterState depends on inherited widgets which aren't ready
    // until first dependency change.
    if (_autoLaunched) return;
    final q = GoRouterState.of(context).uri.queryParameters;
    if (q['switch'] == '1') {
      _autoLaunched = true;
      // Fire-and-forget on next frame — Supabase OAuth is a full-page
      // redirect on web, so we just need to kick it off.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(authRepositoryProvider)
            .signInWithGoogle(forceAccountPicker: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(
                    fontFamily: 'InterDisplay',
                    fontFamilyFallback: const ['NotoSansTC'],
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 14),
                const AppText.body('探索電影海報的世界',
                    tone: AppTextTone.muted),
                const Spacer(flex: 4),
                // v19: AppButton.primary replaces the inlined _WhitePill.
                // Manual taps always show Google's picker — users land
                // here via 切換帳號 or after a session expiry, and
                // silently re-signing the cached account is the wrong
                // default in both cases.
                AppButton.primary(
                  label: '使用 Google 登入',
                  icon: PhosphorIconsRegular.googleLogo,
                  size: AppButtonSize.large,
                  fullWidth: true,
                  onPressed: () => ref
                      .read(authRepositoryProvider)
                      .signInWithGoogle(forceAccountPicker: true),
                ),
                const SizedBox(height: 12),
                const AppText.small('繼續即同意條款', tone: AppTextTone.faint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

