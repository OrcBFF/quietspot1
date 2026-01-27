import 'package:flutter/material.dart';
import 'package:quietspot/managers/user_manager.dart';
import 'package:quietspot/services/api_service.dart';
import 'package:quietspot/screens/login_dialog.dart';

class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key});

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    String? message;
    bool isError = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: isError ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  TextField(
                    controller: oldPassController,
                    decoration: const InputDecoration(labelText: 'Old Password'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: newPassController,
                    decoration: const InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                  ),
                  TextField(
                    controller: confirmPassController,
                    decoration: const InputDecoration(labelText: 'Confirm New Password'),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newPassController.text != confirmPassController.text) {
                    setState(() {
                      message = 'Passwords do not match';
                      isError = true;
                    });
                    return;
                  }
                  if (newPassController.text.length < 4) {
                    setState(() {
                      message = 'Password too short';
                      isError = true;
                    });
                    return;
                  }

                  try {
                    final user = UserManager.instance;
                    if (user.userId == null) return;

                    await ApiService.changePassword(
                      user.userId!,
                      oldPassController.text,
                      newPassController.text,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated successfully')),
                      );
                    }
                  } catch (e) {
                    setState(() {
                      message = e.toString().replaceAll('Exception: ', '');
                      isError = true;
                    });
                  }
                },
                child: const Text('UPDATE'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteProfileDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'Your measurements and spots will NOT be deleted, but they will be anonymized.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PROFILE'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final user = UserManager.instance;
        if (user.userId == null) return;

        await ApiService.deleteAccount(user.userId!);
        
        user.logout();
        
        if (context.mounted) {
           Navigator.of(context).popUntil((route) => route.isFirst);
           // Show login dialog or just stay on welcome screen (which is what popUntil(isFirst) does if WelcomeScreen is root)
           // Actually main_navigation is likely root or logged in root.
           // Ideally we should go to WelcomeScreen.
           // For now let's pop all logic.
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserManager.instance;
    final name = user.name ?? 'Guest';
    final email = user.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Username'),
            subtitle: Text(name),
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(email),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showChangePasswordDialog(context),
            icon: const Icon(Icons.lock_reset),
            label: const Text('CHANGE PASSWORD'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _showDeleteProfileDialog(context),
            icon: const Icon(Icons.delete_forever),
            label: const Text('DELETE PROFILE'),
          ),
        ],
      ),
    );
  }
}
