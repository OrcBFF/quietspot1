import 'package:flutter/material.dart';
import 'package:quietspot/managers/user_manager.dart';
import 'package:quietspot/screens/account_details_screen.dart';

import 'package:quietspot/screens/contributions_screen.dart';
import 'package:quietspot/screens/welcome_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final user = UserManager.instance;
    final username = user.name ?? 'Guest';
    
    return Scaffold(
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettingsRow(
              title: 'Your account',
              subtitle: username,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountDetailsScreen()),
                ).then((_) => setState(() {})); // Refresh in case name changed (future proofing) or deleted
              },
            ),
            const Divider(),
            _SettingsRow(
              title: 'Contributions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContributionsScreen()),
                );
              },
            ),
            const Divider(),
            _SettingsRow(
              title: 'Device Permissions',
              onTap: () async {
                await openAppSettings();
              },
            ),
            const Divider(),
            _SettingsRow(
              title: 'Instructions',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('How to use QuietSpot'),
                    content: const SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finding Quiet Spots:\n'
                            '• Explore the map to see pins indicating noise levels.\n'
                            '• Green pins are quiet, yellow are moderate, and red are noisy.\n\n'
                            'Adding Measurements:\n'
                            '• Tap the "+" button to start a noise measurement.\n'
                            '• Hold your device still for a few seconds.\n'
                            '• Once complete, verify the details and submit to help others find quiet places!\n\n'
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(),
            Align(
              alignment: Alignment.bottomLeft,
              child: TextButton.icon(
                onPressed: () {
                  UserManager.instance.logout();
                  // Navigate to Welcome Screen and clear stack
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('LOG OUT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.chevron_right),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}


