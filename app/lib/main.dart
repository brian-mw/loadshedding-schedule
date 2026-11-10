import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'controllers/location_controller.dart';
import 'controllers/schedule_controller.dart';
import 'screens/home_screen.dart';

void main() {
  Get.put(LocationController());
  Get.put(ScheduleController());
  runApp(const EscomApp());
}

class EscomApp extends StatelessWidget {
  const EscomApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GetMaterialApp (for GetX navigation/page transitions) wrapped per
    // shadcn_ui's Material-interop pattern, so Shad theming and components
    // still work throughout.
    // shadcn_ui's default control sizes follow its web origins (e.g. a
    // 40dp-tall regular button) and read as undersized next to standard
    // Android/Material touch targets (~48dp) - bumped up app-wide here
    // instead of overriding every individual button/input.
    const buttonSizes = ShadButtonSizesTheme(
      regular: ShadButtonSizeTheme(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      sm: ShadButtonSizeTheme(
        height: 42,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      lg: ShadButtonSizeTheme(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
      icon: ShadButtonSizeTheme(
        height: 48,
        width: 48,
        padding: EdgeInsets.zero,
      ),
    );
    return ShadApp.custom(
      themeMode: ThemeMode.system,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadBlueColorScheme.light(),
        buttonSizesTheme: buttonSizes,
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadBlueColorScheme.dark(),
        buttonSizesTheme: buttonSizes,
      ),
      appBuilder: (context) {
        return GetMaterialApp(
          title: 'ESCOM Loadshedding',
          debugShowCheckedModeBanner: false,
          theme: Theme.of(context),
          defaultTransition: Transition.cupertino,
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => ShadAppBuilder(child: child!),
          home: const HomeScreen(),
        );
      },
    );
  }
}
