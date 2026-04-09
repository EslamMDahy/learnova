import 'package:flutter/material.dart';
import '../widgets/forget_password_left_panel.dart';
import '../widgets/forget_password_form.dart';

class ForgetPasswordPage extends StatelessWidget {
  const ForgetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return const Row(
              children: [
                Expanded(flex: 5, child: ForgetPasswordLeftPanel()),
                Expanded(flex: 5, child: ForgetPasswordForm()),
              ],
            );
          }

          return const ForgetPasswordForm(isMobile: true);
        },
      ),
    );
  }
}
