import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:privateecole/widgets/messege_banner.dart';
import 'constants/app_colors.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final email = _emailController.text.trim();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _message =
            "If an account exists for this email, a reset email has been sent";
        _isSuccess = true;
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else {
        errorMessage = 'An error occurred: ${e.message}';
      }
      setState(() {
        _message = "❌ $errorMessage";
        _isSuccess = false;
      });
    } catch (e) {
      setState(() {
        _message = "❌ An error occurred.";
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.06;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _message != null
                ? MessageBanner(
                    key: ValueKey(_message),
                    message: _message!,
                    isSuccess: _isSuccess,
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.04),

                  // Icon
                  CircleAvatar(
                    radius: size.width * 0.15,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.lock_reset,
                      color: AppColors.primary,
                      size: size.width * 0.15,
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),

                  // Title
                  Text(
                    "Forgot your password?",
                    style: TextStyle(
                      fontSize: size.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: size.height * 0.01),

                  // Subtitle
                  Text(
                    "Enter your email and we'll send you a reset link to create a new password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: size.width * 0.035,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),

                  // Email form
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: "Email",
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your email";
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),

                  // Reset button
                  SizedBox(
                    width: double.infinity,
                    height: size.height * 0.06,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Send Reset Link",
                              style: TextStyle(fontSize: size.width * 0.04),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
