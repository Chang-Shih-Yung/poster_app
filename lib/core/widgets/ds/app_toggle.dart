import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Thin wrapper over CupertinoSwitch with our tokens baked in.
/// Centralises the "active colour + track colour" decision so every
/// switch in the app shares one look.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppTheme.text,
      inactiveTrackColor: AppTheme.surfaceRaised,
      thumbColor: AppTheme.bg,
    );
  }
}
