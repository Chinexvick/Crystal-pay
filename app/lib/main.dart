import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/security/app_lock.dart';
import 'services/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: CrystalPayApp()));
}

class CrystalPayApp extends ConsumerWidget {
  const CrystalPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Crystal Pay',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => UiScale(child: AppLockGate(child: child!)),
    );
  }
}

/// Draws the whole app at [kUiScale] of its old size. Layout runs on a larger
/// virtual screen, so every button, icon, font and gap shrinks together.
const double kUiScale = 0.76;

class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const s = kUiScale;
    final size = Size(mq.size.width / s, mq.size.height / s);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scale: s,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: mq.copyWith(
                size: size,
                padding: mq.padding / s,
                viewPadding: mq.viewPadding / s,
                viewInsets: mq.viewInsets / s,
                textScaler: mq.textScaler.clamp(minScaleFactor: .9, maxScaleFactor: 1.15),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
