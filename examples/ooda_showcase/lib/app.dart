import 'package:flutter/material.dart';

import 'screens/dialogs_screen.dart';
import 'screens/forms_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/navigation_screen.dart';
import 'theme.dart';

/// App variant for styling.
enum AppVariant { minimal, polished }

/// Main app widget.
class OodaShowcaseApp extends StatelessWidget {
  const OodaShowcaseApp({
    super.key,
    this.variant = AppVariant.minimal,
  });

  final AppVariant variant;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OODA Showcase',
      debugShowCheckedModeBanner: false,
      theme: variant == AppVariant.polished
          ? OodaTheme.light
          : ThemeData.light(useMaterial3: true),
      darkTheme: variant == AppVariant.polished
          ? OodaTheme.dark
          : ThemeData.dark(useMaterial3: true),
      initialRoute: '/',
      onGenerateRoute: (settings) => _generateRoute(settings, variant),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings, AppVariant variant) {
    final routes = <String, WidgetBuilder>{
      '/': (context) => HomeScreen(variant: variant),
      '/login': (context) => LoginScreen(variant: variant),
      '/items': (context) => ListScreen(variant: variant),
      '/dialogs': (context) => DialogsScreen(variant: variant),
      '/forms': (context) => FormsScreen(variant: variant),
      '/navigation': (context) => NavigationScreen(variant: variant),
    };

    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: settings,
      );
    }
    return null;
  }
}
