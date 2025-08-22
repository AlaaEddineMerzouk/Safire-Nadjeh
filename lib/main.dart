import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:privateecole/admin_home_page.dart';

import 'package:privateecole/firebase_options.dart';

import 'package:privateecole/forget_password.dart';

import 'package:privateecole/sign_in_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Private Ecole',

      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

// Use the AuthWrapper as the home widget

      home: const AuthWrapper(),

      routes: {
        '/adminhome': (context) => const AdminApp(),
        '/signin': (context) => const SignInPage(),
        '/resetpassword': (context) => const ForgetPasswordPage(),
      },
    );
  }
}

// A new widget to manage the authentication state

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
// StreamBuilder listens to authentication state changes

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
// If the connection is active, we are waiting for the state to be ready

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;

          if (user == null) {
// User is not signed in, show the SignInPage

            return const SignInPage();
          } else {
// User is signed in, show the AdminHomePage

            return const AdminApp();
          }
        }

// While waiting for the connection, show a loading indicator

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
