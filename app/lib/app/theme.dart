import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Crystal Pay design tokens: the purple identity.
/// Sampled from the brand mark (violet → magenta "C") and the approved
/// screen designs (deep purple banners, lavender tiles, mint success).
class C {
  C._();
  // Brand
  static const primary = Color(0xFF5B14DD); // CTAs, links, active states
  static const primaryDark = Color(0xFF3D08A8); // pressed, gradient ends
  static const primaryLight = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFCB3CF0); // logo highlight, sparingly
  static const navy = Color(0xFF1C0B4F); // deepest brand surface
  static const cyan = Color(0xFF22C3EE);
  static const violet = Color(0xFF7C3AED);
  static const gold = Color(0xFFF5A524);
  static const green = Color(0xFF16A34A);
  static const mint = Color(0xFFDDF7E8);

  // Tints
  static const tint = Color(0xFFF1EAFE); // lavender tiles, soft buttons
  static const tint2 = Color(0xFFF8F5FF);
  static const goldTint = Color(0xFFFFF3D9);
  static const violetTint = Color(0xFFEFE8FF);
  static const blueTint = Color(0xFFE8F1FF);
  static const greenTint = Color(0xFFE6F8EE);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successTint = Color(0xFFDCF7E6);
  static const pending = Color(0xFFD97706);
  static const pendingTint = Color(0xFFFEF2D6);
  static const error = Color(0xFFDC2F45);
  static const errorTint = Color(0xFFFDE8EB);
  static const info = primary;
  static const infoTint = tint;

  // Neutrals (purple-tinted greys)
  static const ink = Color(0xFF15102E);
  static const muted = Color(0xFF625D7B);
  static const faint = Color(0xFF9B96B1);
  static const border = Color(0xFFECE8F5);
  static const bg = Color(0xFFF8F6FD);
  static const surface = Colors.white;
  static const scrim = Color(0x99150B33);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F2BF3), Color(0xFF4B10CC)],
  );

  /// Wallet card / dark hero surfaces.
  static const deepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2B0A85), Color(0xFF4511BA), Color(0xFF6326E2)],
  );
  static const skyGradient = brandGradient;
  static const violetGradient = LinearGradient(colors: [Color(0xFF7228F0), Color(0xFF3B05AE)]);

  /// Purple promo banners: deep on the text side, lighter behind the art.
  static const bannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3D0AB2), Color(0xFF5B1ADB), Color(0xFF9466F2)],
    stops: [0, .55, 1],
  );

  /// Light hero banners on the home screen.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7F3FF), Color(0xFFE9DDFF)],
  );
}

class Sp {
  Sp._();
  static const double page = 20;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class R {
  R._();
  static const double input = 14;
  static const double card = 18;
  static const double tile = 18;
  static const double sheet = 28;
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get inputR => BorderRadius.circular(input);
}

/// Soft purple-tinted elevation used across cards.
List<BoxShadow> softShadow([double o = .06]) => [
      BoxShadow(
        color: const Color(0xFF3B1A8C).withValues(alpha: o * .9),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];

class T {
  T._();
  static const family = 'Jakarta';
  static const _f = family;
  static const _tab = [FontFeature.tabularFigures()];

  static const display = TextStyle(
      fontFamily: _f, fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, color: C.ink, letterSpacing: -.7);
  static const h1 = TextStyle(
      fontFamily: _f, fontSize: 24, height: 1.2, fontWeight: FontWeight.w800, color: C.ink, letterSpacing: -.5);
  static const h2 = TextStyle(
      fontFamily: _f, fontSize: 20, height: 1.25, fontWeight: FontWeight.w700, color: C.ink, letterSpacing: -.3);
  static const h3 = TextStyle(
      fontFamily: _f, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, color: C.ink, letterSpacing: -.2);
  static const title = TextStyle(
      fontFamily: _f, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, color: C.ink, letterSpacing: -.1);
  static const body = TextStyle(
      fontFamily: _f, fontSize: 14, height: 1.45, fontWeight: FontWeight.w400, color: C.ink);
  static const bodyM = TextStyle(
      fontFamily: _f, fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: C.ink);
  static const small = TextStyle(
      fontFamily: _f, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: C.muted);
  static const smallM = TextStyle(
      fontFamily: _f, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: C.muted);
  static const caption = TextStyle(
      fontFamily: _f, fontSize: 11, height: 1.3, fontWeight: FontWeight.w600, color: C.faint, letterSpacing: .1);
  static const label = TextStyle(
      fontFamily: _f, fontSize: 13, height: 1.3, fontWeight: FontWeight.w700, color: C.ink);
  static const button = TextStyle(
      fontFamily: _f, fontSize: 15.5, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: .1);
  static const money = TextStyle(
      fontFamily: _f, fontSize: 15, height: 1.2, fontWeight: FontWeight.w800, color: C.ink, fontFeatures: _tab);

  /// Large screen title used on the top-level tabs (Shop, Bills, More).
  static const pageTitle = TextStyle(
      fontFamily: _f, fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, color: C.ink, letterSpacing: -.6);

  static TextStyle moneyOf(double size, {FontWeight w = FontWeight.w800, Color color = C.ink}) => TextStyle(
      fontFamily: _f, fontSize: size, height: 1.15, fontWeight: w, color: color, fontFeatures: _tab, letterSpacing: -.4);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.primary,
    primary: C.primary,
    onPrimary: Colors.white,
    secondary: C.violet,
    error: C.error,
    surface: C.surface,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: T.family,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    splashFactory: InkRipple.splashFactory,
    splashColor: C.primary.withValues(alpha: .08),
    highlightColor: C.primary.withValues(alpha: .04),
    dividerColor: C.border,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.primary,
      selectionColor: C.primary.withValues(alpha: .2),
      selectionHandleColor: C.primary,
    ),
    textTheme: const TextTheme(
      bodyMedium: T.body,
      bodyLarge: T.body,
      titleMedium: T.title,
      labelLarge: T.button,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : const Color(0xFFDCD7E8)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : Colors.transparent),
      side: const BorderSide(color: Color(0xFFC9C3DA), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.primary),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.navy,
      contentTextStyle: T.bodyM.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: T.body.copyWith(color: C.faint),
      border: OutlineInputBorder(borderRadius: R.inputR, borderSide: const BorderSide(color: C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: R.inputR, borderSide: const BorderSide(color: C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: R.inputR, borderSide: const BorderSide(color: C.primary, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: R.inputR, borderSide: const BorderSide(color: C.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: R.inputR, borderSide: const BorderSide(color: C.error, width: 1.6)),
    ),
  );
}
