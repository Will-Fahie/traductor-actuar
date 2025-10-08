import 'package:flutter/material.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/widgets/app_button.dart';

class LanguageToggle extends StatelessWidget {
  final AppButtonSize size;
  final AppButtonType type;
  
  const LanguageToggle({
    super.key,
    this.size = AppButtonSize.small,
    this.type = AppButtonType.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final languageService = LanguageService();
        return AppButton(
          label: languageService.isSpanish ? 'EN' : 'ES',
          icon: Icons.language_rounded,
          size: size,
          type: type,
          onPressed: () async {
            await languageService.toggleLanguage();
          },
        );
      },
    );
  }
}
