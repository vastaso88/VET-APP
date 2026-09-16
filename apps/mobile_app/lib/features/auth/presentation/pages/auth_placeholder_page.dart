import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../widgets/auth_widgets.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthPlaceholderPage extends StatelessWidget {
  const AuthPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreenScaffold(
      title: 'Entra nel tuo spazio pet.',
      subtitle: 'Accedi al tuo account oppure creane uno nuovo in pochi secondi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
              ),
              child: const Text('Accedi'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
              ),
              child: const Text('Crea un account'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'I tuoi dati restano privati e li usiamo solo per gestire il profilo del tuo pet.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
