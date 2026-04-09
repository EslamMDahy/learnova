import 'package:flutter/material.dart';
import '../widgets/left_panel.dart';
import '../widgets/login_form.dart';



class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return const Row(
              children: [
                Expanded(flex: 5, child: LeftPanel()),
                Expanded(flex: 5, child: LoginForm()),
              ],
            );
          }

          return const LoginForm(isMobile: true);
        },
      ),
    );
  }
}
