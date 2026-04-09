import 'package:flutter/material.dart';
import 'package:learnova/features/auth/presentation/widgets/set_new_password_form.dart';
import 'package:learnova/features/auth/presentation/widgets/set_new_password_left_panel.dart';

class SetNewPasswordPage extends StatelessWidget {
  final String? token;
  const SetNewPasswordPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                const Expanded(flex: 5, child: SetNewPasswordLeftPanel()),
                Expanded(
                  flex: 5,
                  child: SetNewPasswordForm(token: token),
                ),
              ],
            );
          }

          return SetNewPasswordForm(token: token, isMobile: true);
        },
      ),
    );
  }
}
