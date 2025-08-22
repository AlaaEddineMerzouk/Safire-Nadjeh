import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:privateecole/constants/app_colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// The following import is removed to resolve the conflict:
// import 'package:privateecole/main.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo & Title
              Icon(Icons.school, size: 80, color: AppColors.primaryOrange),
              const SizedBox(height: 16),
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Sign in to continue to your account",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email
                    TextFormField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => email = value,
                      validator: (value) => value == null || value.isEmpty
                          ? "Please enter your email"
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.inputFill,
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      obscureText: obscurePassword,
                      onChanged: (value) => password = value,
                      validator: (value) => value == null || value.isEmpty
                          ? "Please enter your password"
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => isLoading = true);

                            try {
                              await FirebaseAuth.instance
                                  .signInWithEmailAndPassword(
                                email: email.trim(),
                                password: password.trim(),
                              );

                              // Navigate to home
                              Navigator.pushReplacementNamed(
                                  context, '/adminhome');
                            } on FirebaseAuthException catch (e) {
                              String errorMessage;
                              if (e.code == 'user-not-found') {
                                errorMessage = 'No user found for that email.';
                              } else if (e.code == 'wrong-password') {
                                errorMessage = 'Incorrect password.';
                              } else {
                                errorMessage = 'Error: ${e.message}';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(errorMessage)),
                              );
                            } finally {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Sign In",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/resetpassword');
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
