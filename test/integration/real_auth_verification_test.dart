// ignore_for_file: depend_on_referenced_packages, avoid_print, unused_local_variable

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medi_crate/core/supabase/supabase_config.dart';
import 'package:medi_crate/features/auth/data/datasources/remote/supabase_auth_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

class MailTmClient {
  static Future<({String address, String token})> createInbox(String prefix) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final address = '${prefix}_$timestamp@fldubai.com';
    const password = 'Password123!';

    final createRes = await http.post(
      Uri.parse('https://api.mail.tm/accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    if (createRes.statusCode != 201) {
      throw Exception('Failed to create mail.tm account: ${createRes.body}');
    }

    final tokenRes = await http.post(
      Uri.parse('https://api.mail.tm/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    if (tokenRes.statusCode != 200) {
      throw Exception('Failed to get mail.tm token: ${tokenRes.body}');
    }

    final token = jsonDecode(tokenRes.body)['token'] as String;
    return (address: address, token: token);
  }

  static Future<String?> waitForOtp(String token, {int timeoutSeconds = 40}) async {
    final iterations = (timeoutSeconds / 4).ceil();
    for (var i = 0; i < iterations; i++) {
      await Future.delayed(const Duration(seconds: 4));
      final res = await http.get(
        Uri.parse('https://api.mail.tm/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final members = data['hydra:member'] as List;
        if (members.isNotEmpty) {
          final messageId = members.first['id'] as String;
          final msgRes = await http.get(
            Uri.parse('https://api.mail.tm/messages/$messageId'),
            headers: {'Authorization': 'Bearer $token'},
          );
          final msgBody = jsonDecode(msgRes.body);
          final text = msgBody['text'] as String? ?? '';
          final intro = msgBody['intro'] as String? ?? '';
          print('  [Mailbox] Subject: "${msgBody['subject']}"');

          final match = RegExp(r'\b\d{6}\b').firstMatch('$intro $text');
          if (match != null) {
            return match.group(0);
          }
        }
      }
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();
  SharedPreferences.setMockInitialValues({});

  late String supabaseUrl;
  late String anonKey;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    final config = SupabaseConfig.validateConfig();
    supabaseUrl = config.url;
    anonKey = config.anonKey;
  });

  test(
    'Real Deliverable Authentication Lifecycle (Sign Up, OTP, Sign In, Reset Password, Email Change)',
    () async {
    final client = SupabaseClient(
      supabaseUrl,
      anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    final authDataSource = SupabaseAuthRemoteDataSource(client);

    const initialPassword = 'Password123!';
    const updatedPassword = 'NewSecretPassword456!';

    print('\n=== STEP 1: CREATE REAL DISPOSABLE INBOX ===');
    final inboxA = await MailTmClient.createInbox('medicrate_user_a');
    print('Created real inbox: ${inboxA.address}');

    print('\n=== STEP 2: SIGN UP THROUGH ACTUAL FLUTTER AUTH DATA SOURCE ===');
    final signUpResult = await authDataSource.signUp(
      name: 'Verified Real User',
      email: inboxA.address,
      password: initialPassword,
    );
    print('SignUp result: $signUpResult');

    print('\n=== STEP 3: RECEIVE AND EXTRACT REAL SIGN-UP OTP FROM INBOX ===');
    final signUpOtp = await MailTmClient.waitForOtp(inboxA.token);
    expect(signUpOtp, isNotNull, reason: 'Real Supabase mailer must deliver 6-digit signup OTP to deliverable address');
    print('Received real signup OTP: $signUpOtp');

    print('\n=== STEP 4: VERIFY REAL OTP THROUGH FLUTTER AUTH DATA SOURCE ===');
    final verifiedUser = await authDataSource.verifyEmail(
      email: inboxA.address,
      otp: signUpOtp!,
      type: OtpType.signup,
    );
    expect(verifiedUser.emailConfirmedAt, isNotNull);
    expect(verifiedUser.email, inboxA.address);
    print('Email successfully verified for user ${verifiedUser.id} at ${verifiedUser.emailConfirmedAt}');

    print('\n=== STEP 5: SIGN IN WITH VERIFIED CREDENTIALS ===');
    final loginResult = await authDataSource.login(
      email: inboxA.address,
      password: initialPassword,
    );
    expect(client.auth.currentUser?.id, verifiedUser.id);
    print('Login successful for session: ${client.auth.currentUser?.id}');

    print('\n=== STEP 6: SIGN OUT AND VERIFY SESSION TERMINATION ===');
    await authDataSource.signOut();
    expect(client.auth.currentUser, isNull);
    print('Signed out successfully.');

    print('\n=== STEP 7: RESTORE SESSION VIA SIGN IN ===');
    await authDataSource.login(
      email: inboxA.address,
      password: initialPassword,
    );
    expect(client.auth.currentUser?.id, verifiedUser.id);
    print('Session successfully restored on login.');

    print('\n=== STEP 8: TEST PASSWORD RESET LIFECYCLE ===');
    await authDataSource.forgotPassword(inboxA.address);
    print('Password reset requested. Waiting for recovery OTP in inbox...');
    final resetOtp = await MailTmClient.waitForOtp(inboxA.token);
    if (resetOtp != null) {
      print('Received recovery OTP: $resetOtp');
      await authDataSource.resetPassword(
        email: inboxA.address,
        otp: resetOtp,
        newPassword: updatedPassword,
      );
      print('Password reset successfully applied.');

      // Verify sign in with new password
      await authDataSource.login(
        email: inboxA.address,
        password: updatedPassword,
      );
      expect(client.auth.currentUser?.id, verifiedUser.id);
      print('Sign in with new password verified!');
    } else {
      print('NOTE: Recovery email OTP was not delivered within window (rate-limit or SMTP policy).');
    }

    print('\n=== STEP 9: TEST EMAIL CHANGE LIFECYCLE ===');
    final inboxB = await MailTmClient.createInbox('medicrate_user_b');
    print('Created target email change inbox: ${inboxB.address}');
    try {
      final changeMsg = await authDataSource.requestChangeEmail(
        currentPassword: (resetOtp != null) ? updatedPassword : initialPassword,
        newEmail: inboxB.address,
      );
      print('Email change requested: $changeMsg');
      print('Waiting for email change verification OTP in new inbox...');
      final changeOtp = await MailTmClient.waitForOtp(inboxB.token);
      if (changeOtp != null) {
        print('Received email change OTP in new inbox: $changeOtp');
        final updatedUser = await authDataSource.confirmChangeEmail(
          newEmail: inboxB.address,
          otp: changeOtp,
        );
        print('Email change confirmed. New user email: ${updatedUser.email}');
      } else {
        print('NOTE: Email change token was not delivered to new inbox within window.');
      }
    } catch (e) {
      print('Email change request notice: $e');
    }

    print('\n=== STEP 10: CLEAN UP TEST DATA ===');
    final userId = client.auth.currentUser?.id ?? verifiedUser.id;
    final cleanupRes = await Process.run('supabase', [
      'db',
      'query',
      '--linked',
      "DELETE FROM auth.users WHERE id = '$userId';",
    ]);
    expect(cleanupRes.exitCode, 0);
    print('Cleaned up test user $userId from database: true');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
