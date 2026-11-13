import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'views/auth/login_view.dart';
import 'views/auth/onboarding_view.dart';
import 'views/home/home_shell.dart';
import 'views/splash_view.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/async_view.dart';

class OurBuzzerApp extends StatelessWidget {
  const OurBuzzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jkwEffect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Gerbang sesi — meniru `_layout.tsx` versi Expo:
/// login → onboarding (pilih peran) → home sesuai peran.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    final Widget page = switch (auth) {
      AsyncData(value: final user) when user == null => const LoginView(),
      AsyncData(value: final user?) when !user.hasRole => const OnboardingView(),
      AsyncData(value: final user?) => HomeShell(key: ValueKey(user.role), user: user),
      AsyncError(:final error) => Scaffold(
          body: ErrorRetry(
            message: errorText(error),
            onRetry: () => ref.read(authProvider.notifier).retry(),
          ),
        ),
      _ => const SplashView(),
    };

    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: page);
  }
}
