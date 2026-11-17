import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class Apptheme {
  Apptheme._();

  static const String fontFamily = 'WorkSans';

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Appcolors.primary,
      primary: Appcolors.primary,
      onPrimary: Colors.white,
      surface: Appcolors.surface,
      error: Appcolors.sale,
    ),
    scaffoldBackgroundColor: Appcolors.background,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Appcolors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Appcolors.text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Appcolors.text,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: Appcolors.text),
      bodySmall: TextStyle(fontSize: 12, color: Appcolors.secondaryText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Appcolors.field,
      isDense: true,
      hintStyle: const TextStyle(color: Appcolors.hint, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _border(Colors.transparent),
      enabledBorder: _border(Colors.transparent),
      disabledBorder: _border(Colors.transparent),
      focusedBorder: _border(Appcolors.primary),
      errorBorder: _border(Appcolors.sale),
      focusedErrorBorder: _border(Appcolors.sale, 1.2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Appcolors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Appcolors.text,
        side: const BorderSide(color: Appcolors.border),
        minimumSize: const Size(0, 44),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Appcolors.primary
            : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.all(Appcolors.primary),
    ),
    dividerTheme: const DividerThemeData(
      color: Appcolors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    cardTheme: CardThemeData(
      color: Appcolors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
