import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class TemplateScreen extends StatelessWidget {
  const TemplateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Screen'),
        backgroundColor: EzimTheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Welcome, ${user?.name ?? 'Guest'}'),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('This is a template screen. Add your content here.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
