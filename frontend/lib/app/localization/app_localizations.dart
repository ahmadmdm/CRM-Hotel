import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations is not available.');
    return localizations!;
  }

  bool get isArabic => locale.languageCode == 'ar';
  String get languageCode => isArabic ? 'ar' : 'en';

  String formatNumber(num value, {int decimals = 0}) {
    return NumberFormat.decimalPatternDigits(
      locale: languageCode,
      decimalDigits: decimals,
    ).format(value);
  }

  String formatPercent(num value, {int decimals = 1}) {
    return '${formatNumber(value, decimals: decimals)}%';
  }

  String formatCurrency(num value, {String currencyCode = 'SAR'}) {
    final symbol = isArabic && currencyCode == 'SAR' ? 'ر.س' : currencyCode;
    final decimals = value % 1 == 0 ? 0 : 2;
    return '$symbol ${formatNumber(value, decimals: decimals)}';
  }

  String formatDateTime(DateTime value, {bool includeTime = true}) {
    final normalizedValue = value.toLocal();
    final format = includeTime
        ? DateFormat('d MMM y • HH:mm', languageCode)
        : DateFormat('d MMM y', languageCode);
    return format.format(normalizedValue);
  }

  String formatDateRange(DateTime start, DateTime end) {
    return '${formatDateTime(start)} → ${formatDateTime(end)}';
  }

  String get appTitle => 'CrmHotel';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Retry';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get create => isArabic ? 'إنشاء' : 'Create';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get deactivate => isArabic ? 'تعطيل' : 'Deactivate';
  String get upload => isArabic ? 'رفع' : 'Upload';
  String get loading => isArabic ? 'جارٍ التحميل...' : 'Loading...';
  String get live => isArabic ? 'مباشر' : 'Live';
  String get active => isArabic ? 'نشط' : 'Active';
  String get inactive => isArabic ? 'غير نشط' : 'Inactive';
  String get yes => isArabic ? 'نعم' : 'Yes';
  String get no => isArabic ? 'لا' : 'No';
  String get signOut => isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'الإنجليزية' : 'English';
  String get signInTitle => isArabic ? 'تسجيل الدخول' : 'Sign in';
  String get signInCta =>
      isArabic ? 'الدخول إلى النظام' : 'Enter the system';
  String get signingIn => isArabic ? 'جارٍ تسجيل الدخول...' : 'Signing in...';
  String get unifiedAccess => isArabic ? 'الوصول الموحد' : 'Unified Access';
  String get emailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  String get emailHint => 'name@crmhotel.example.com';
  String get passwordLabel => isArabic ? 'كلمة المرور' : 'Password';
  String get passwordHint =>
      isArabic ? 'أدخل كلمة المرور' : 'Enter your password';
  String get loginIntro => isArabic
      ? 'استخدم حساب النظام الفعلي، وسيبني التطبيق التجربة تلقائياً بحسب الصلاحيات الممنوحة لهذا المستخدم.'
      : 'Use a real backend account and the app will compose the experience automatically from the user\'s effective permissions.';
  String redirectedAfterLogin(String route) => isArabic
      ? 'بعد نجاح الدخول ستتم إعادتك إلى $route.'
      : 'After sign-in you will be returned to $route.';
  String requiredRouteAfterLogin(String route) => isArabic
      ? 'المسار المطلوب بعد الدخول: $route'
      : 'Requested route after sign-in: $route';
  String get loginHeroSubtitle => isArabic
      ? 'منصة موحدة لإدارة الحجوزات والوحدات والعمليات والخدمة والصلاحيات في CrmHotel.'
      : 'A unified CrmHotel workspace for bookings, units, operations, service teams, and access control.';
  String get loginHeroBody => isArabic
      ? 'يسجل كل مستخدم الدخول مرة واحدة ليصل مباشرة إلى الأدوات والمهام التي تخص دوره داخل التشغيل اليومي للفندق.'
      : 'Each user signs in once and lands in the tools, records, and actions tied to their role in day-to-day hotel operations.';
  String get loginHeroPillUnified =>
      isArabic ? 'دخول موحّد' : 'Unified Login';
  String get loginHeroPillMatrix =>
      isArabic ? 'صلاحيات حسب الدور' : 'Role-based Access';
  String get loginHeroPillOffline => isArabic
      ? 'عمليات ميدانية للغرف والصيانة'
      : 'Housekeeping and Maintenance';
  String get modulesLabel => isArabic ? 'الوحدات' : 'Modules';
  String get accessLayersLabel =>
      isArabic ? 'طبقات الوصول' : 'Access layers';
  String get readinessModeLabel =>
      isArabic ? 'وضع الجاهزية' : 'Readiness mode';
  String get roleAndOverride =>
      isArabic ? 'الدور + الاستثناء' : 'Role + Override';
  String get operationalReadiness =>
      isArabic ? 'تشغيلي' : 'Operational';
  String get shellSidebarIntro => isArabic
      ? 'تشغيل ضيافة موحّد يجمع الحجوزات والوحدات والمالية والخدمة ضمن صلاحيات واضحة لكل مستخدم.'
      : 'Unified hospitality operations across bookings, units, finance, and service tasks with clear access for each user.';
  String get shellCommandDeck => isArabic
      ? 'لوحة تشغيل حسب الصلاحيات'
      : 'Role-aware operations';
  String get shellWorkspaceIntro => isArabic
      ? 'مساحة عمل لإدارة تشغيل الفندق بسرعة ووضوح، مع انتقال آمن بين الشاشات المسموح بها لكل دور.'
      : 'A workspace built for fast hotel operations with clear navigation across the screens allowed for each role.';
    String get forbiddenTitle =>
      isArabic ? 'غير مصرح لك بالدخول' : 'Access denied';
    String get forbiddenSubtitle => isArabic
      ? 'هذه الشاشة غير متاحة للدور الحالي.'
      : 'This screen is not available for the current role.';
  String get dashboardTitle =>
      isArabic ? 'مركز قيادة CrmHotel' : 'CrmHotel Command Center';
  String get reportsTitle =>
      isArabic ? 'تقارير الأداء' : 'Performance Reports';
  String get accessTitle =>
      isArabic ? 'إدارة الوصول' : 'Access Management';
  String get unitsTitle => isArabic ? 'محفظة الوحدات' : 'Units Portfolio';
  String get bookingsTitle => isArabic ? 'تدفق الحجوزات' : 'Bookings Flow';
  String get crmTitle => isArabic ? 'إدارة العملاء' : 'Guest CRM';
  String get financeTitle => isArabic ? 'نبض المالية' : 'Finance Pulse';
    String get notificationsTitle =>
      isArabic ? 'مركز الإشعارات' : 'Notifications Center';
  String get maintenanceTitle =>
      isArabic ? 'مكتب الصيانة الميداني' : 'Maintenance Field Desk';
  String get housekeepingTitle =>
      isArabic ? 'مسار الإشراف الفندقي' : 'Housekeeping Flow';
  String get dashboardNav => isArabic ? 'لوحة القيادة' : 'Dashboard';
  String get reportsNav => isArabic ? 'التقارير' : 'Reports';
  String get accessNav => isArabic ? 'الصلاحيات' : 'Access';
  String get unitsNav => isArabic ? 'الوحدات' : 'Units';
  String get bookingsNav => isArabic ? 'الحجوزات' : 'Bookings';
  String get crmNav => isArabic ? 'العملاء' : 'CRM';
  String get financeNav => isArabic ? 'المالية' : 'Finance';
    String get notificationsNav => isArabic ? 'الإشعارات' : 'Notifications';
  String get maintenanceNav => isArabic ? 'الصيانة' : 'Maintenance';
  String get housekeepingNav => isArabic ? 'الإشراف' : 'Housekeeping';
  String get goOffline => isArabic ? 'التحول إلى وضع عدم الاتصال' : 'Go offline';
  String get goOnline => isArabic ? 'العودة إلى الاتصال' : 'Go online';
    String notificationsUnreadCount(int count) =>
      isArabic ? 'غير المقروءة: $count' : 'Unread: $count';
    String get notificationsMarkAllRead =>
      isArabic ? 'تعيين الكل كمقروء' : 'Mark all as read';
    String get notificationsMarkRead =>
      isArabic ? 'تعيين كمقروء' : 'Mark as read';
    String get notificationsEmptyState =>
      isArabic ? 'لا توجد إشعارات حتى الآن.' : 'No notifications yet.';
    String get notificationsLoadErrorTitle => isArabic
      ? 'تعذر تحميل الإشعارات'
      : 'Unable to load notifications';
    String get notificationsStatsUnavailable => isArabic
      ? 'تعذر تحميل ملخص الإشعارات.'
      : 'Notification summary is unavailable.';
    String get notificationsPushCardTitle =>
      isArabic ? 'تنبيهات المتصفح' : 'Browser Push';
    String get notificationsPushCardReady => isArabic
      ? 'يمكنك تفعيل تنبيهات OneSignal لهذا المتصفح وربطها بحسابك الحالي.'
      : 'You can enable OneSignal browser push and link it to the current account.';
    String get notificationsPushEnabled => isArabic
      ? 'تم طلب تفعيل تنبيهات المتصفح لهذا الحساب.'
      : 'Browser push has been requested for this account.';
    String get notificationsPushUnavailable => isArabic
      ? 'تنبيهات المتصفح غير متاحة حالياً أو لم يتم إعداد OneSignal بعد.'
      : 'Browser push is unavailable right now or OneSignal is not configured yet.';
    String get notificationsEnablePush =>
      isArabic ? 'تفعيل تنبيهات المتصفح' : 'Enable browser push';
    String get notificationsBroadcastTitle =>
      isArabic ? 'إشعار عام من الإدارة' : 'Admin Broadcast';
    String get notificationsBroadcastSubjectLabel =>
      isArabic ? 'العنوان' : 'Title';
    String get notificationsBroadcastBodyLabel =>
      isArabic ? 'نص الإشعار' : 'Message';
    String get notificationsBroadcastAction =>
      isArabic ? 'إرسال الإشعار' : 'Send broadcast';
    String get notificationsBroadcastSent =>
      isArabic ? 'تم إرسال الإشعار العام.' : 'The broadcast notification was sent.';

  String routeTitleFor(String location) {
    if (location.startsWith('/app/reports')) {
      return reportsTitle;
    }
    if (location.startsWith('/app/access')) {
      return accessTitle;
    }
    if (location.startsWith('/app/units')) {
      return unitsTitle;
    }
    if (location.startsWith('/app/bookings')) {
      return bookingsTitle;
    }
    if (location.startsWith('/app/crm')) {
      return crmTitle;
    }
    if (location.startsWith('/app/finance')) {
      return financeTitle;
    }
    if (location.startsWith('/app/notifications')) {
      return notificationsTitle;
    }
    if (location.startsWith('/worker/maintenance')) {
      return maintenanceTitle;
    }
    if (location.startsWith('/worker/housekeeping')) {
      return housekeepingTitle;
    }
    return dashboardTitle;
  }

  String connectionRestoredMessage(int pendingCount) => isArabic
      ? 'تمت استعادة الاتصال. توجد $pendingCount عمليات تنتظر المزامنة.'
      : 'Connection restored. $pendingCount actions are waiting to sync.';

  String get offlineModeMessage => isArabic
      ? 'أنت تعمل حالياً دون اتصال. سيتم حفظ العمليات محلياً.'
      : 'You are currently working offline. Actions will be stored locally.';

  String roleLabel(String roleCode) {
    switch (roleCode) {
      case 'super_admin':
        return isArabic ? 'مدير النظام' : 'Super Admin';
      case 'sub_admin':
        return isArabic ? 'إداري فرعي' : 'Sub-Admin';
      case 'financial':
        return isArabic ? 'المالية' : 'Financial';
      case 'operations':
        return isArabic ? 'العمليات' : 'Operations';
      case 'maintenance':
        return isArabic ? 'الصيانة' : 'Maintenance';
      case 'housekeeping':
        return isArabic ? 'الإشراف الفندقي' : 'Housekeeping';
      default:
        return roleCode;
    }
  }

  String moduleLabel(String module) {
    switch (module) {
      case 'dashboard':
        return dashboardNav;
      case 'units':
        return unitsNav;
      case 'bookings':
        return bookingsNav;
      case 'crm':
        return crmNav;
      case 'finance':
        return financeNav;
      case 'notifications':
        return notificationsNav;
      case 'housekeeping':
        return housekeepingNav;
      case 'maintenance':
        return maintenanceNav;
      case 'reports':
        return reportsNav;
      case 'users':
      case 'access':
        return accessNav;
      default:
        return module;
    }
  }

  String permissionName(String code, String fallback) {
    if (!isArabic) {
      return fallback;
    }
    switch (code) {
      case 'dashboard.view':
        return 'عرض لوحة القيادة';
      case 'units.view':
        return 'عرض الوحدات';
      case 'units.manage':
        return 'إدارة الوحدات';
      case 'bookings.view':
        return 'عرض الحجوزات';
      case 'bookings.manage':
        return 'إدارة الحجوزات';
      case 'crm.view':
        return 'عرض العملاء';
      case 'crm.manage':
        return 'إدارة العملاء';
      case 'finance.view':
        return 'عرض المالية';
      case 'finance.manage':
        return 'إدارة المالية';
      case 'housekeeping.view':
        return 'عرض مهام الإشراف';
      case 'housekeeping.complete':
        return 'إكمال مهام الإشراف';
      case 'housekeeping.manage':
        return 'إدارة أوامر النظافة';
      case 'maintenance.view':
        return 'عرض الصيانة';
      case 'maintenance.manage':
        return 'إدارة الصيانة';
      case 'notifications.view':
        return 'عرض الإشعارات';
      case 'notifications.manage':
        return 'إدارة الإشعارات';
      case 'reports.view':
        return 'عرض التقارير';
      case 'users.view':
        return 'عرض المستخدمين';
      case 'users.manage_access':
        return 'إدارة الوصول';
      default:
        return fallback;
    }
  }

  String permissionDescription(String code, String fallback) {
    if (!isArabic) {
      return fallback;
    }
    switch (code) {
      case 'dashboard.view':
        return 'الوصول إلى لوحة القيادة والمؤشرات الرئيسية.';
      case 'units.view':
        return 'عرض الوحدات والصور وبيانات المرافق.';
      case 'units.manage':
        return 'إنشاء الوحدات وتعديلها ورفع صورها وتعطيلها.';
      case 'bookings.view':
        return 'عرض قائمة الحجوزات وتفاصيلها.';
      case 'bookings.manage':
        return 'إنشاء الحجوزات وتنفيذ انتقالاتها التشغيلية.';
      case 'crm.view':
        return 'عرض العملاء وسجلات علاقاتهم.';
      case 'crm.manage':
        return 'إنشاء العملاء وتحديثهم وحظرهم.';
      case 'finance.view':
        return 'عرض المدفوعات والمصروفات.';
      case 'finance.manage':
        return 'تسجيل المدفوعات والمصروفات.';
      case 'housekeeping.view':
        return 'عرض مهام الإشراف الفندقي.';
      case 'housekeeping.complete':
        return 'إكمال مهام الإشراف وتحديث جاهزية الوحدة.';
      case 'housekeeping.manage':
        return 'إنشاء أوامر النظافة وإسنادها إلى أفراد الخدمة.';
      case 'maintenance.view':
        return 'عرض تذاكر الصيانة.';
      case 'maintenance.manage':
        return 'إنشاء تذاكر الصيانة وإغلاقها.';
      case 'notifications.view':
        return 'عرض الإشعارات الشخصية والتنبيهات التشغيلية.';
      case 'notifications.manage':
        return 'إرسال الإشعارات العامة ومتابعة التنبيهات الإدارية.';
      case 'reports.view':
        return 'الوصول إلى التقارير التشغيلية والمالية.';
      case 'users.view':
        return 'عرض المستخدمين وتعيينات الوصول الخاصة بهم.';
      case 'users.manage_access':
        return 'إدارة الأدوار والاستثناءات الفردية للمستخدمين.';
      default:
        return fallback;
    }
  }

  String unitStatus(String status) {
    switch (status) {
      case 'vacant':
        return isArabic ? 'فارغة' : 'Vacant';
      case 'ready':
        return isArabic ? 'جاهزة' : 'Ready';
      case 'reserved':
        return isArabic ? 'محجوزة' : 'Reserved';
      case 'occupied':
        return isArabic ? 'مشغولة' : 'Occupied';
      case 'pending_cleaning':
        return isArabic ? 'بانتظار التنظيف' : 'Pending cleaning';
      case 'maintenance':
        return isArabic ? 'تحت الصيانة' : 'Maintenance';
      default:
        return status;
    }
  }

  String bookingStatus(String status) {
    switch (status) {
      case 'pending':
        return isArabic ? 'قيد التأكيد' : 'Pending';
      case 'confirmed':
        return isArabic ? 'مؤكد' : 'Confirmed';
      case 'checked_in':
        return isArabic ? 'تم تسجيل الدخول' : 'Checked in';
      case 'checked_out':
        return isArabic ? 'تم تسجيل الخروج' : 'Checked out';
      case 'no_show':
        return isArabic ? 'لم يحضر' : 'No show';
      case 'cancelled':
        return isArabic ? 'ملغي' : 'Cancelled';
      default:
        return status;
    }
  }

  String paymentStatus(String status) {
    switch (status) {
      case 'unpaid':
        return isArabic ? 'غير مدفوع' : 'Unpaid';
      case 'partial':
        return isArabic ? 'دفعة جزئية' : 'Partial';
      case 'pending':
        return isArabic ? 'قيد الانتظار' : 'Pending';
      case 'paid':
        return isArabic ? 'مدفوع' : 'Paid';
      case 'failed':
        return isArabic ? 'فشل' : 'Failed';
      case 'refunded':
        return isArabic ? 'مسترد' : 'Refunded';
      default:
        return status;
    }
  }

  String genericStatus(String status) {
    switch (status) {
      case 'open':
        return isArabic ? 'مفتوحة' : 'Open';
      case 'in_progress':
        return isArabic ? 'قيد التنفيذ' : 'In progress';
      case 'blocked':
        return isArabic ? 'متوقفة' : 'Blocked';
      case 'resolved':
        return isArabic ? 'مغلقة' : 'Resolved';
      case 'closed':
        return isArabic ? 'مقفلة' : 'Closed';
      case 'completed':
        return isArabic ? 'مكتملة' : 'Completed';
      default:
        return status;
    }
  }

  String notificationKindLabel(String kind) {
    switch (kind) {
      case 'housekeeping':
        return isArabic ? 'تنظيف' : 'Housekeeping';
      case 'maintenance':
        return isArabic ? 'صيانة' : 'Maintenance';
      case 'auth':
        return isArabic ? 'دخول وخروج' : 'Auth';
      default:
        return isArabic ? 'عام' : 'General';
    }
  }

  String priorityLabel(String priority) {
    switch (priority) {
      case 'low':
        return isArabic ? 'منخفضة' : 'Low';
      case 'normal':
        return isArabic ? 'اعتيادية' : 'Normal';
      case 'medium':
        return isArabic ? 'متوسطة' : 'Medium';
      case 'high':
        return isArabic ? 'عالية' : 'High';
      case 'urgent':
        return isArabic ? 'عاجلة' : 'Urgent';
      default:
        return priority;
    }
  }

  String paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return isArabic ? 'نقدي' : 'Cash';
      case 'card':
        return isArabic ? 'بطاقة' : 'Card';
      case 'bank_transfer':
        return isArabic ? 'تحويل بنكي' : 'Bank transfer';
      default:
        return method;
    }
  }

  String expenseCategoryLabel(String category) {
    switch (category) {
      case 'housekeeping':
        return isArabic ? 'نظافة' : 'Housekeeping';
      case 'maintenance':
        return isArabic ? 'صيانة' : 'Maintenance';
      case 'utilities':
        return isArabic ? 'مرافق' : 'Utilities';
      case 'supplies':
        return isArabic ? 'مستلزمات' : 'Supplies';
      default:
        return category;
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    Intl.defaultLocale = locale.languageCode;
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}