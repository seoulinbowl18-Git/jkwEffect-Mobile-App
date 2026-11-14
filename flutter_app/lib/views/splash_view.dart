import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/brand_logo.dart';

/// Layar tunggu saat sesi dimuat. Warnanya sama dengan native splash (Premium Red #C8102E)
/// supaya peralihan dari splash bawaan Android/iOS ke aplikasi tidak berkedip putih.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: FittedBox(fit: BoxFit.scaleDown, child: BrandLogo(size: 56, showName: true, onDark: true)),
            ),
            const SizedBox(height: AppSpace.xl),
            SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: onBrand)),
          ],
        ),
      ),
    );
  }
}
