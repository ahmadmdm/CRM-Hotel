import 'auth_session.dart';

class DemoAccount {
  const DemoAccount({
    required this.role,
    required this.email,
    required this.password,
    required this.description,
  });

  final UserRole role;
  final String email;
  final String password;
  final String description;
}

const demoAccounts = <DemoAccount>[
  DemoAccount(
    role: UserRole.superAdmin,
    email: 'admin@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'وصول كامل للوحة التحكم والتقارير والمالية.',
  ),
  DemoAccount(
    role: UserRole.subAdmin,
    email: 'subadmin@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'صلاحيات تشغيلية واسعة بدون الإدارة العليا.',
  ),
  DemoAccount(
    role: UserRole.financial,
    email: 'financial@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'المدفوعات والمصروفات والمؤشرات المالية.',
  ),
  DemoAccount(
    role: UserRole.operations,
    email: 'ops@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'الحجوزات وحالة الوحدات والتشغيل اليومي.',
  ),
  DemoAccount(
    role: UserRole.maintenance,
    email: 'maintenance@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'تطبيق الصيانة الميداني وإغلاق التذاكر.',
  ),
  DemoAccount(
    role: UserRole.housekeeping,
    email: 'hk@crmhotel.example.com',
    password: 'ChangeMe123!',
    description: 'مهام التنظيف مع دعم العمل دون اتصال.',
  ),
];

DemoAccount demoAccountForRole(UserRole role) {
  return demoAccounts.firstWhere((account) => account.role == role);
}
