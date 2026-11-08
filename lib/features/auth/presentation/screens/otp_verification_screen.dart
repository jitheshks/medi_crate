import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/feedback/offline_banner.dart';
import '../../../../shared/widgets/feedback/vault_badge.dart';
import '../providers/auth_providers.dart';
import '../widgets/otp_verification_form.dart';

/// OtpVerificationScreen processes OTP verification for email verification (A2)
/// and password reset routing (A6).
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String type; // 'signup' | 'reset_password' | 'change_email'
  final int? initialTimerSeconds;
  final int? userId;
  final int otpLength;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.type = 'signup',
    this.initialTimerSeconds,
    this.userId,
    int otpLength = 6,
  }) : otpLength = (otpLength >= 4 && otpLength <= 8) ? otpLength : 6;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late int _secondsRemaining;
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

  String get effectiveEmail => widget.email.trim();
  bool get hasValidEmail =>
      effectiveEmail.isNotEmpty && effectiveEmail.contains('@');

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.otpLength,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.otpLength, (_) => FocusNode());
    _secondsRemaining = widget.initialTimerSeconds ?? 60;
    if (hasValidEmail) {
      final timerEnabled = ref.read(otpTimerEnabledProvider);
      if (timerEnabled && _secondsRemaining > 0) {
        _startTimer();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNodes.isNotEmpty) {
          _focusNodes[0].requestFocus();
        }
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _formattedTimer {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleOtpInput(int index, String val) {
    final count = widget.otpLength;
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < count && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= count) {
        FocusScope.of(context).unfocus();
      } else if (digits.isNotEmpty) {
        final nextIndex = digits.length < count ? digits.length : count - 1;
        _focusNodes[nextIndex].requestFocus();
      }
      setState(() {});
      return;
    }

    if (val.isNotEmpty) {
      if (index < count - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    setState(() {});
  }

  Future<void> _handleResend() async {
    if (!hasValidEmail) {
      setState(
        () => _error = 'No email address found. Please restart verification.',
      );
      return;
    }

    final isOnline = ref.read(isOnlineProvider).value ?? true;
    if (!isOnline) {
      context.showErrorSnackBar('Internet connection required to resend code.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .resendOtp(email: effectiveEmail, type: widget.type);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _secondsRemaining = widget.initialTimerSeconds ?? 60;
        final timerEnabled = ref.read(otpTimerEnabledProvider);
        if (timerEnabled && _secondsRemaining > 0) {
          _startTimer();
        }
        context.showSuccessSnackBar('Verification code sent successfully.');
      } else {
        final error = ref.read(authControllerProvider).otpError;
        context.showErrorSnackBar(
          error ?? 'Failed to resend verification code.',
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!hasValidEmail) {
      setState(
        () => _error = 'No email address found. Please restart verification.',
      );
      return;
    }

    final isOnline = ref.read(isOnlineProvider).value ?? true;
    if (!isOnline) {
      context.showErrorSnackBar(
        'Internet connection required for verification.',
      );
      return;
    }

    final code = _controllers.map((c) => c.text).join();
    if (code.length < widget.otpLength) {
      setState(() => _error = 'Please enter all ${widget.otpLength} digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.type == 'reset_password') {
      _timer?.cancel();
      setState(() => _isLoading = false);
      TextInput.finishAutofillContext();
      context.pushGuarded(
        AppRoutes.resetPassword,
        extra: {'email': effectiveEmail, 'code': code, 'token': code},
      );
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyEmail(email: effectiveEmail, otp: code);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _timer?.cancel();
        TextInput.finishAutofillContext();
        context.go(AppRoutes.dashboard);
      } else {
        final authError = ref.read(authControllerProvider).otpError;
        setState(() => _error = authError ?? 'Invalid verification code.');
      }
    }
  }

  void _handleChangeEmail() {
    _timer?.cancel();
    if (widget.type == 'reset_password') {
      context.go(AppRoutes.forgotPassword);
    } else {
      context.popOrGo(AppRoutes.signup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final isCodeComplete = _controllers.every((c) => c.text.isNotEmpty);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft, size: 20),
          onPressed: () {
            _timer?.cancel();
            context.popOrGo(AppRoutes.login);
          },
        ),
        title: Text(
          'MediCrate',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: VaultBadge(label: "VERIFY IT'S YOU"),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline) const OfflineBanner(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 8,
                      bottom: 24,
                    ),
                    child: hasValidEmail
                        ? OtpVerificationForm(
                            email: effectiveEmail,
                            type: widget.type,
                            controllers: _controllers,
                            focusNodes: _focusNodes,
                            error: _error,
                            isLoading: _isLoading,
                            isOnline: isOnline,
                            isCodeComplete: isCodeComplete,
                            secondsRemaining: _secondsRemaining,
                            formattedTimer: _formattedTimer,
                            onOtpInput: _handleOtpInput,
                            onVerify: _verifyOtp,
                            onResend: _handleResend,
                            onChangeEmail: _handleChangeEmail,
                          )
                        : _buildMissingEmailState(context, colorScheme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingEmailState(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 36,
            color: colorScheme.error,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Email Address Missing',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'No valid email address was provided for verification. Please return to the previous screen to sign in or create an account.',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.go(AppRoutes.signup),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          child: const Text('Return to Sign Up'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.login),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          child: const Text('Return to Sign In'),
        ),
      ],
    );
  }
}
