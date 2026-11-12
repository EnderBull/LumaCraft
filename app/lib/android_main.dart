import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'settings/android_map_preview.dart';
import 'ui/android/alpha_page.dart';
import 'ui/app_theme.dart';

void main() => runApp(const LumaCraftAlpha());

class LumaCraftAlpha extends StatefulWidget {
  const LumaCraftAlpha({super.key});

  @override
  State<LumaCraftAlpha> createState() => _LumaCraftAlphaState();
}

class _LumaCraftAlphaState extends State<LumaCraftAlpha> {
  ThemeMode _appearance = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    try {
      final settings = await loadAndroidSettings();
      final stored = settings.androidAppearance;
      settings.dispose();
      if (mounted) {
        setState(() => _appearance = ThemeMode.values.byName(stored));
      }
    } on Object {
      // Defaults to the system appearance if settings are unavailable.
    }
  }

  Future<bool> _setAppearance(ThemeMode appearance) async {
    try {
      final settings = await loadAndroidSettings();
      try {
        settings.androidAppearance = appearance.name;
        await settings.flush();
        if (settings.saveError != null) return false;
        if (mounted) setState(() => _appearance = appearance);
        return true;
      } finally {
        settings.dispose();
      }
    } on Object {
      return false;
    }
  }

  ThemeData _theme(bool dark) {
    final base = workspaceTheme(dark);
    final colors = base.colorScheme;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'LCSourceSans'),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: shape,
          textStyle:
              base.textTheme.labelLarge?.copyWith(fontFamily: 'LCSourceSans'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: colors.surfaceContainerHighest,
          foregroundColor: colors.onSurface,
          side: BorderSide.none,
          shape: shape,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '框印工坊',
        theme: _theme(false),
        darkTheme: _theme(true),
        themeMode: _appearance,
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AlphaPage(appearance: _appearance, setAppearance: _setAppearance),
      );
}
