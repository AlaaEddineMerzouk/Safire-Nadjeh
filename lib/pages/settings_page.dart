import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// You would define AppColors in a separate file,
// but for this example, we'll define them here.
class AppColors {
  static const Color primary = Colors.orange;
  static const Color textSecondary = Colors.grey;
  static const Color inputFill = Color(0xFFF5F5F5); // Light grey
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _schoolName =
      'Your Private École'; // State variable to hold the school name

  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    // We check if the context is still mounted to prevent the error
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final newPasswordController = TextEditingController();
    final currentPasswordController = TextEditingController();
    final user = _auth.currentUser;

    if (user == null) {
      _showSnackBar(context, 'You must be logged in to change your password.',
          isError: true);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        bool isPasswordVisible = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: 'Current Password',
                        prefixIcon:
                            const Icon(Icons.lock, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: 'New Password',
                        prefixIcon:
                            const Icon(Icons.lock, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newPasswordController.text.isEmpty ||
                        currentPasswordController.text.isEmpty) {
                      Navigator.pop(context, 'empty');
                      return;
                    }

                    try {
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);
                      await user.updatePassword(newPasswordController.text);
                      Navigator.pop(context, 'success');
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'wrong-password') {
                        Navigator.pop(context, 'wrong-password');
                      } else {
                        Navigator.pop(context, 'error');
                      }
                    } catch (e) {
                      Navigator.pop(context, 'error');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // After the dialog closes, check the result and show the snackbar
    if (result == 'success') {
      _showSnackBar(context, 'Password changed successfully!');
    } else if (result == 'wrong-password') {
      _showSnackBar(context, 'Incorrect current password. Please try again.',
          isError: true);
    } else if (result == 'empty') {
      _showSnackBar(context, 'All fields are required.', isError: true);
    } else if (result == 'error') {
      _showSnackBar(context, 'An unexpected error occurred.', isError: true);
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final newEmailController = TextEditingController();
    final currentPasswordController = TextEditingController();
    final user = _auth.currentUser;

    if (user == null) {
      _showSnackBar(context, 'You must be logged in to change your email.',
          isError: true);
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        bool isPasswordVisible = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Email'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentPasswordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: 'Current Password',
                        prefixIcon:
                            const Icon(Icons.lock, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: 'New Email',
                        prefixIcon:
                            const Icon(Icons.email, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newEmailController.text.isEmpty ||
                        currentPasswordController.text.isEmpty) {
                      Navigator.pop(context, 'empty');
                      return;
                    }

                    try {
                      AuthCredential credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);
                      await user.updateEmail(newEmailController.text);
                      Navigator.pop(context, 'success');
                    } on FirebaseAuthException catch (e) {
                      if (e.code == 'wrong-password') {
                        Navigator.pop(context, 'wrong-password');
                      } else if (e.code == 'email-already-in-use') {
                        Navigator.pop(context, 'email-in-use');
                      } else {
                        Navigator.pop(context, 'error');
                      }
                    } catch (e) {
                      Navigator.pop(context, 'error');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'success') {
      _showSnackBar(context, 'Email changed successfully!');
    } else if (result == 'wrong-password') {
      _showSnackBar(context, 'Incorrect current password. Please try again.',
          isError: true);
    } else if (result == 'empty') {
      _showSnackBar(context, 'All fields are required.', isError: true);
    } else if (result == 'email-in-use') {
      _showSnackBar(context, 'The new email is already in use.', isError: true);
    } else if (result == 'error') {
      _showSnackBar(context, 'An unexpected error occurred.', isError: true);
    }
  }

  // ... rest of the code is unchanged
  Future<void> _showEditSchoolNameDialog() async {
    final schoolNameController = TextEditingController(text: _schoolName);

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit School Name'),
          content: TextField(
            controller: schoolNameController,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.inputFill,
              labelText: 'School Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (schoolNameController.text.isNotEmpty) {
                  setState(() {
                    _schoolName = schoolNameController.text;
                  });
                  _showSnackBar(context, 'School name updated!');
                } else {
                  _showSnackBar(context, 'School name cannot be empty.',
                      isError: true);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _logout() async {
    try {
      await _auth.signOut();
      Navigator.of(context, rootNavigator: true)
          .pushReplacementNamed('/signin');
    } catch (e) {
      _showSnackBar(context, 'Error logging out.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Account Settings',
                subtitle: 'Manage your profile and security',
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_rounded,
                          color: AppColors.primary),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_rounded,
                          color: AppColors.primary),
                      title: const Text('Change Email'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: _showChangeEmailDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'School Details',
                subtitle: 'Configure school information',
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.school_rounded,
                          color: AppColors.primary),
                      title: const Text('School Name'),
                      subtitle: Text(_schoolName),
                      trailing: const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: _showEditSchoolNameDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.currency_exchange_rounded,
                          color: AppColors.primary),
                      title: const Text('Currency'),
                      subtitle: const Text('DZD - Algerian Dinar'),
                      trailing: const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: () {
                        _showSnackBar(context,
                            'Currency settings are not yet supported.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Advanced',
                subtitle: 'Backup and language options',
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language_rounded,
                          color: AppColors.primary),
                      title: const Text('Language'),
                      subtitle: const Text('English'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: () {
                        _showSnackBar(context,
                            'Language switching is not yet supported.');
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_download_rounded,
                          color: AppColors.primary),
                      title: const Text('Backup & Export Data'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: AppColors.primary),
                      onTap: () {
                        _showSnackBar(
                            context, 'Data backup is not yet implemented.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(
                title: 'Session',
                subtitle: 'Account session management',
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.red),
                  onTap: _logout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Re-using the existing _SectionHeader widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
      ]),
    );
  }
}
