import 'package:flutter/material.dart';
import 'workspace_dialog.dart';

const warmAccent = Color(0xffdfa653);

ThemeData workspaceTheme(bool dark) {
  final scheme = ColorScheme.fromSeed(
          seedColor: warmAccent,
          brightness: dark ? Brightness.dark : Brightness.light)
      .copyWith(
    primary: dark ? warmAccent : const Color(0xff9b5e14),
    onPrimary: dark ? const Color(0xff2a1d0d) : Colors.white,
    surface: dark ? const Color(0xff262523) : const Color(0xfff6f3ed),
    onSurface: dark ? const Color(0xffece8e2) : const Color(0xff393127),
    surfaceContainerHighest:
        dark ? const Color(0xff32302d) : const Color(0xffe9e2d7),
    outline: dark ? const Color(0xff665f54) : const Color(0xffa89a87),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Microsoft YaHei UI',
    fontFamilyFallback: const ['Microsoft YaHei', 'Segoe UI', 'sans-serif'],
    scaffoldBackgroundColor:
        dark ? const Color(0xff191817) : const Color(0xffe4ded5),
    textTheme: Typography.material2021().black.apply(
        fontFamily: 'Microsoft YaHei UI',
        fontFamilyFallback: const ['Microsoft YaHei', 'Segoe UI', 'sans-serif'],
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface),
    dialogTheme: const DialogThemeData(
        titleTextStyle: dialogTitleStyle, contentTextStyle: dialogBodyStyle),
    tooltipTheme:
        const TooltipThemeData(waitDuration: Duration(milliseconds: 450)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff1f1e1c) : const Color(0xffece8e2),
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface,
            textStyle: dialogBodyStyle,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)))),
  );
}
