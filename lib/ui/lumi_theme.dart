import 'package:flutter/material.dart';

enum LumiAccent {
  sage('Sage green', Color(0xFF667A5E), Color(0xFFA8BD9D)),
  blue('Blue', Color(0xFF496FA3), Color(0xFFA4C3EC)),
  lightOrange('Light orange', Color(0xFFA85E26), Color(0xFFF0B989)),
  maroon('Maroon', Color(0xFF8F4054), Color(0xFFE0A2B1));

  const LumiAccent(this.label, this.lightColor, this.darkColor);
  final String label;
  final Color lightColor;
  final Color darkColor;
  Color forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;
}

abstract final class LumiTheme {
  static ThemeData light({LumiAccent accent = LumiAccent.sage}) =>
      _build(Brightness.light, accent);
  static ThemeData dark({LumiAccent accent = LumiAccent.sage}) =>
      _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, LumiAccent accent) {
    final dark = brightness == Brightness.dark;
    final primary = accent.forBrightness(brightness);
    final canvas = Color(dark ? 0xFF191C19 : 0xFFF4F1E8);
    final navigation = Color(dark ? 0xFF20241F : 0xFFECE8DD);
    final surface = Color(dark ? 0xFF272C26 : 0xFFFFFCF5);
    final ink = Color(dark ? 0xFFE8E5DA : 0xFF292D28);
    final secondaryText = Color(dark ? 0xFFB8BBAF : 0xFF555B50);
    final border = Color(dark ? 0xFF3B4239 : 0xFFD8D2C5);
    final scheme =
        ColorScheme.fromSeed(seedColor: primary, brightness: brightness)
            .copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xFF1D231D) : Colors.white,
      secondary: primary,
      onSecondary: dark ? const Color(0xFF1D231D) : Colors.white,
      tertiary: primary,
      onTertiary: dark ? const Color(0xFF1D231D) : Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: secondaryText,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: navigation,
      surfaceContainer: surface,
      primaryContainer: Color.alphaBlend(
        primary.withValues(alpha: dark ? .24 : .14),
        surface,
      ),
      onPrimaryContainer: ink,
      secondaryContainer: Color.alphaBlend(
        primary.withValues(alpha: dark ? .24 : .14),
        surface,
      ),
      onSecondaryContainer: ink,
      errorContainer: Color(dark ? 0xFF482D27 : 0xFFF1DAD2),
      onErrorContainer: Color(dark ? 0xFFF0C6B9 : 0xFF49271D),
      outline: border,
      outlineVariant: border,
    );
    final base = Typography.material2021().black;
    final textTheme = base
        .apply(
          fontFamily: 'DM Sans',
          bodyColor: ink,
          displayColor: ink,
        )
        .copyWith(
          headlineLarge: base.headlineLarge
              ?.copyWith(fontFamily: 'Lora', color: ink, height: 1.18),
          headlineMedium: base.headlineMedium
              ?.copyWith(fontFamily: 'Lora', color: ink, height: 1.2),
          headlineSmall: base.headlineSmall
              ?.copyWith(fontFamily: 'Lora', color: ink, height: 1.25),
          titleLarge: base.titleLarge?.copyWith(fontFamily: 'Lora', color: ink),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'DM Sans',
      textTheme: textTheme,
      dividerColor: border,
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(44, 44),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(44, 44),
      )),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: border),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: ink, fontFamily: 'DM Sans'),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      listTileTheme: ListTileThemeData(
        iconColor: secondaryText,
        textColor: ink,
        selectedColor: primary,
        selectedTileColor: primary.withValues(alpha: dark ? .18 : .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            dark ? const Color(0xFF30362F) : const Color(0xFF33392F),
        contentTextStyle: const TextStyle(color: Color(0xFFFFFCF5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: [
        LumiTokens(border: border, surface: navigation, aiAccent: primary)
      ],
    );
  }
}

@immutable
class LumiTokens extends ThemeExtension<LumiTokens> {
  const LumiTokens(
      {required this.border, required this.surface, required this.aiAccent});
  final Color border;
  final Color surface;
  final Color aiAccent;

  @override
  LumiTokens copyWith({Color? border, Color? surface, Color? aiAccent}) =>
      LumiTokens(
        border: border ?? this.border,
        surface: surface ?? this.surface,
        aiAccent: aiAccent ?? this.aiAccent,
      );

  @override
  LumiTokens lerp(ThemeExtension<LumiTokens>? other, double t) {
    if (other is! LumiTokens) return this;
    return LumiTokens(
      border: Color.lerp(border, other.border, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      aiAccent: Color.lerp(aiAccent, other.aiAccent, t)!,
    );
  }
}
