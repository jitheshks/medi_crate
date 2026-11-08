import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/utils/validators.dart';
import 'package:medi_crate/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:medi_crate/features/auth/presentation/widgets/auth_social_sign_in_buttons.dart';
import 'package:medi_crate/features/auth/presentation/widgets/forgot_password_form.dart';
import 'package:medi_crate/features/auth/presentation/widgets/otp_input_row.dart';
import 'package:medi_crate/features/auth/presentation/widgets/reset_password_form.dart';
import 'package:medi_crate/features/auth/presentation/widgets/sign_up_form.dart';

void main() {
  group('Phase 3B.3: Form Validators & OTP Refinement Tests', () {
    test('validateOtp validates standard 6-digit Supabase OTPs', () {
      expect(Validators.validateOtp('123456'), isNull);
      expect(Validators.validateOtp('654321'), isNull);
    });

    test(
      'validateOtp accepts 4-digit legacy OTPs for backward compatibility',
      () {
        expect(Validators.validateOtp('1234', allowLegacy4Digit: true), isNull);
        expect(Validators.validateOtp('9999', allowLegacy4Digit: true), isNull);
      },
    );

    test('validateOtp rejects invalid lengths or non-numeric characters', () {
      expect(Validators.validateOtp(''), contains('verification code'));
      expect(Validators.validateOtp(null), contains('verification code'));
      expect(Validators.validateOtp('12345'), contains('6 digits'));
      expect(Validators.validateOtp('1234567'), contains('6 digits'));
      expect(Validators.validateOtp('12ab56'), contains('numbers only'));
    });

    test('validateEmail validates RFC compliant email addresses', () {
      expect(Validators.validateEmail('user@medicrate.com'), isNull);
      expect(
        Validators.validateEmail('invalid-email'),
        contains('valid email'),
      );
      expect(Validators.validateEmail(''), contains('required'));
      expect(Validators.validateEmail(null), contains('required'));
    });
  });

  group('Phase 3B.3: AuthSocialSignInButtons UI Tests', () {
    testWidgets(
      'renders full-width "Continue with Google" button when showApple is false',
      (tester) async {
        bool googleTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthSocialSignInButtons(
                onGoogleTap: () => googleTapped = true,
                showApple: false,
              ),
            ),
          ),
        );

        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.text('Apple'), findsNothing);

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();
        expect(googleTapped, isTrue);
      },
    );

    testWidgets(
      'renders side-by-side buttons when showApple is true and onAppleTap provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthSocialSignInButtons(
                onGoogleTap: () {},
                onAppleTap: () {},
                showApple: true,
              ),
            ),
          ),
        );

        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Apple'), findsOneWidget);
      },
    );
  });

  group('Phase 3B.3: Real-Time Field Changed Listeners in Forms', () {
    testWidgets('ForgotPasswordForm notifies onFieldChanged when typing', (
      tester,
    ) async {
      int fieldChangedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgotPasswordForm(
              isLoading: false,
              onSubmit: (_) {},
              onFieldChanged: () => fieldChangedCount++,
            ),
          ),
        ),
      );

      final emailField = find.byType(TextFormField);
      expect(emailField, findsOneWidget);

      await tester.enterText(emailField, 'patient@medicrate.com');
      await tester.pump();

      expect(fieldChangedCount, greaterThan(0));
    });

    testWidgets(
      'ResetPasswordForm notifies onFieldChanged when typing new password',
      (tester) async {
        int fieldChangedCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResetPasswordForm(
                isLoading: false,
                onSubmit: (newPassword, confirmPassword) {},
                onFieldChanged: () => fieldChangedCount++,
              ),
            ),
          ),
        );

        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(2));

        await tester.enterText(textFields.first, 'NewPassword123!');
        await tester.pump();

        expect(fieldChangedCount, greaterThan(0));
      },
    );

    testWidgets('SignUpForm notifies onFieldChanged when typing name', (
      tester,
    ) async {
      int fieldChangedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SignUpForm(
                isLoading: false,
                onSubmit: (name, email, password, dob, gender) {},
                onFieldChanged: () => fieldChangedCount++,
              ),
            ),
          ),
        ),
      );

      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);

      await tester.enterText(textFields.first, 'Dr. Sharma');
      await tester.pump();

      expect(fieldChangedCount, greaterThan(0));
    });
  });

  group('Phase 3B.3: OTP Input Row & Verification Screen Tests', () {
    testWidgets('OtpInputRow renders 6 input boxes by default', (tester) async {
      final controllers = List.generate(6, (_) => TextEditingController());
      final focusNodes = List.generate(6, (_) => FocusNode());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: OtpInputRow(
                  controllers: controllers,
                  focusNodes: focusNodes,
                  onChanged: (index, val) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets(
      'OtpVerificationScreen displays masked email and 6 input boxes',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: OtpVerificationScreen(
                email: 'patient@medicrate.com',
                type: 'signup',
                otpLength: 6,
              ),
            ),
          ),
        );

        expect(find.text('Verify your identity'), findsOneWidget);
        expect(find.textContaining('pa***@medicrate.com'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(6));
      },
    );
  });
}
