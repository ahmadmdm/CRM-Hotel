import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/localization/locale_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/auth/session_controller.dart';
import '../../../../core/widgets/ambient_background.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _validationError = l10n.isArabic
            ? 'أدخل البريد الإلكتروني وكلمة المرور قبل محاولة تسجيل الدخول.'
            : 'Enter both the email address and password before signing in.';
      });
      return;
    }

    if (_validationError != null) {
      setState(() {
        _validationError = null;
      });
    }

    ref
        .read(sessionControllerProvider.notifier)
        .signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final isLoading = sessionState.isLoading;
    final errorText = _validationError ??
      (sessionState.hasError
        ? _localizedLoginError(sessionState.error, l10n)
        : null);

    final loginPanel = Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.mist),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRMHOTEL',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.midnight,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.loginIntro,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
          if (widget.redirectTo != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                l10n.redirectedAfterLogin(widget.redirectTo!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 22),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            onChanged: (_) {
              if (_validationError == null) {
                return;
              }
              setState(() {
                _validationError = null;
              });
            },
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              hintText: l10n.emailHint,
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) {
              if (_validationError == null) {
                return;
              }
              setState(() {
                _validationError = null;
              });
            },
            onSubmitted: (_) => isLoading ? null : _submit(),
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              hintText: l10n.passwordHint,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : _submit,
              child: Text(isLoading ? l10n.signingIn : l10n.signInCta),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Locale>(
              segments: [
                ButtonSegment<Locale>(
                  value: const Locale('ar'),
                  label: Text(l10n.arabic),
                ),
                ButtonSegment<Locale>(
                  value: const Locale('en'),
                  label: Text(l10n.english),
                ),
              ],
              selected: {Locale(currentLocale.languageCode)},
              onSelectionChanged: (selection) {
                ref.read(localeControllerProvider.notifier).state =
                    selection.first;
              },
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: loginPanel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _localizedLoginError(Object? error, AppLocalizations l10n) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final detail = responseData is Map<String, dynamic>
        ? '${responseData['detail'] ?? responseData['message'] ?? ''}'
        : '$responseData';
    final lowerDetail = detail.toLowerCase();

    if (statusCode == 422 ||
        lowerDetail.contains('field required') ||
        lowerDetail.contains('valid email') ||
        lowerDetail.contains('email') ||
        lowerDetail.contains('password')) {
      return l10n.isArabic
          ? 'تحقق من إدخال البريد الإلكتروني وكلمة المرور بصيغة صحيحة ثم أعد المحاولة.'
          : 'Check that the email address and password are filled in correctly, then try again.';
    }

    if (statusCode == 401 ||
        statusCode == 400 ||
        lowerDetail.contains('invalid') ||
        lowerDetail.contains('credential')) {
      return l10n.isArabic
          ? 'بيانات الدخول غير صحيحة. تحقق من اسم المستخدم أو كلمة المرور ثم أعد المحاولة.'
          : 'The login credentials are invalid. Check the username or password and try again.';
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return l10n.isArabic
          ? 'تعذر الاتصال بالخادم حالياً. تحقق من الشبكة ثم أعد المحاولة.'
          : 'Unable to reach the server right now. Check the network and try again.';
    }
  }

  final raw = '$error';
  final lower = raw.toLowerCase();

  if (lower.contains('401') ||
      lower.contains('unauthorized') ||
      lower.contains('invalid') ||
      lower.contains('credential')) {
    return l10n.isArabic
        ? 'بيانات الدخول غير صحيحة. تحقق من البريد الإلكتروني وكلمة المرور.'
        : 'The login credentials are invalid. Check the email and password.';
  }
  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection')) {
    return l10n.isArabic
        ? 'تعذر الاتصال بالخادم حالياً. حاول مرة أخرى بعد التحقق من الاتصال.'
        : 'Unable to reach the server right now. Check the connection and try again.';
  }

  return raw;
}

