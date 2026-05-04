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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final isLoading = sessionState.isLoading;
    final errorText = sessionState.hasError
        ? _localizedLoginError(sessionState.error, l10n)
        : null;
    final isDesktop = MediaQuery.sizeOf(context).width >= 960;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.unifiedAccess,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.signInTitle,
            style: Theme.of(context).textTheme.headlineMedium,
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
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              hintText: l10n.passwordHint,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            Text(
              errorText,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading
                  ? null
                  : () => ref
                        .read(sessionControllerProvider.notifier)
                        .signIn(
                          _emailController.text.trim(),
                          _passwordController.text,
                        ),
              child: Text(
                isLoading ? l10n.signingIn : l10n.signInCta,
              ),
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
                constraints: const BoxConstraints(maxWidth: 1180),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 32,
                              ),
                              child: _LoginHero(redirectTo: widget.redirectTo),
                            ),
                          ),
                          loginPanel,
                        ],
                      )
                    : Column(
                        children: [
                          const _LoginHero(),
                          const SizedBox(height: 24),
                          loginPanel,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({this.redirectTo});

  final String? redirectTo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.midnight, Color(0xFF243B72), AppColors.sky],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnight.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.hotel_class, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 28),
          Text(
            'CrmHotel',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.loginHeroSubtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.loginHeroBody,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroPill(label: l10n.loginHeroPillUnified),
              _HeroPill(label: l10n.loginHeroPillMatrix),
              _HeroPill(label: l10n.loginHeroPillOffline),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _HeroMetric(label: l10n.modulesLabel, value: '8+'),
              _HeroMetric(
                label: l10n.accessLayersLabel,
                value: l10n.roleAndOverride,
              ),
              _HeroMetric(
                label: l10n.readinessModeLabel,
                value: l10n.operationalReadiness,
              ),
            ],
          ),
          if (redirectTo != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.requiredRouteAfterLogin(redirectTo!),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _localizedLoginError(Object? error, AppLocalizations l10n) {
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}
