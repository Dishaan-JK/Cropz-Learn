# Theme Tokens

## Current token summary

- Current light canvas: `#F0F3F8`; surface: `#F7F8FB`; elevated: `#FFFFFF`; border: `#DDE3EE`; primary seed: `#4F7DFF`; AI accent: `#7357FF`; interface font: Inter.
- Current dark canvas: `#0F1117`; surface: `#171A21`; elevated: `#20242D`; border: `#303744`; primary seed: `#8EA7FF`; AI accent: `#A89BFF`; secondary text: `#BAC2D0`.
- Current shared radii: 12px inputs/cards; card elevation 0; input horizontal/vertical padding 16/12.
- The approved redesign handoff in `.project/plans/WEB_UI_REDESIGN.md` proposes warm paper `#F4F1E8`, warm white `#FFFCF5`, deep ink `#292D28`, sage `#71836A`, terracotta `#B8795E`, with coordinated warm low-glare dark surfaces. These are approved design direction values, not implemented tokens.
- Responsive shell breakpoints in `lib/ui/app.dart`: approximately 760px and 1180px.
- No Tailwind, CSS stylesheet, or web-only theme provider is used; Flutter `ThemeData` is the theme source.

## Current theme source

### `lib/ui/lumi_theme.dart`

```dart
import 'package:flutter/material.dart';

abstract final class LumiTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(isDark ? 0xFF8EA7FF : 0xFF4F7DFF),
      brightness: brightness,
    );
    final surface = Color(isDark ? 0xFF171A21 : 0xFFF7F8FB);
    final elevated = Color(isDark ? 0xFF20242D : 0xFFFFFFFF);
    final border = Color(isDark ? 0xFF303744 : 0xFFDDE3EE);
    final secondaryText = Color(isDark ? 0xFFBAC2D0 : 0xFF5D6675);
    final aiAccent = Color(isDark ? 0xFFA89BFF : 0xFF7357FF);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Color(isDark ? 0xFF0F1117 : 0xFFF0F3F8),
      fontFamily: 'Inter',
      textTheme: Typography.material2021().black.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: elevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        hintStyle: TextStyle(color: secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      extensions: [
        LumiTokens(border: border, surface: surface, aiAccent: aiAccent)
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
```

## Existing visual handoff

See `.project/plans/WEB_UI_REDESIGN.md` for screen-by-screen visual requirements and `.project/TECH_SPEC.md` for UI/data/backend boundaries.
