import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'controllers/location_controller.dart';
import 'controllers/schedule_controller.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system bars, so the full-screen power scenes run edge
  // to edge instead of stopping at an opaque navigation bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Get.put(LocationController());
  Get.put(ScheduleController());
  runApp(const EscomApp());
}

class EscomApp extends StatelessWidget {
  const EscomApp({super.key});

  /// The Material theme ShadApp derives, with the app bar flattened: no
  /// Material 3 tint when content scrolls under it (it turned the bar a
  /// different colour from the page), and system bars that follow the page
  /// instead of staying opaque black.
  ThemeData _materialTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ShadTheme.of(context).colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        titleTextStyle: TextStyle(
          color: colors.foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
      ),
    );
  }

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
    // Dialogs float with a margin (see showAppDialog), so they keep their
    // rounded corners on phones instead of shadcn_ui's square default. The
    // gaps are opened up from the default 8, which packs the title, text
    // and stacked buttons too tightly at phone width.
    const dialogTheme = ShadDialogTheme(
      removeBorderRadiusWhenTiny: false,
      gap: 16,
      actionsGap: 12,
    );
    return ShadApp.custom(
      themeMode: ThemeMode.system,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadBlueColorScheme.light(),
        buttonSizesTheme: buttonSizes,
        primaryDialogTheme: dialogTheme,
        alertDialogTheme: dialogTheme,
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        // The stock blue scheme's dark surfaces are a saturated navy
        // (#020817). Swapped for neutral greys on Material's recommended
        // #121212 dark base, with lighter greys for raised surfaces - only
        // the surfaces change, the blue accent stays.
        colorScheme: const ShadBlueColorScheme.dark(
          background: Color(0xFF121212),
          foreground: Color(0xFFF5F5F5),
          card: Color(0xFF1C1C1C),
          cardForeground: Color(0xFFF5F5F5),
          popover: Color(0xFF1C1C1C),
          popoverForeground: Color(0xFFF5F5F5),
          primaryForeground: Color(0xFFFFFFFF),
          secondary: Color(0xFF2A2A2A),
          secondaryForeground: Color(0xFFF5F5F5),
          muted: Color(0xFF2A2A2A),
          mutedForeground: Color(0xFFA3A3A3),
          accent: Color(0xFF2A2A2A),
          accentForeground: Color(0xFFF5F5F5),
          border: Color(0xFF2E2E2E),
          input: Color(0xFF2E2E2E),
        ),
        buttonSizesTheme: buttonSizes,
        primaryDialogTheme: dialogTheme,
        alertDialogTheme: dialogTheme,
      ),
      appBuilder: (context) {
        return GetMaterialApp(
          title: 'Loadshedding Schedule',
          debugShowCheckedModeBanner: false,
          theme: _materialTheme(context),
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
