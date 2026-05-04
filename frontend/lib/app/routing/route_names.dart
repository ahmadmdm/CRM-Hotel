class RouteNames {
  static const splash = '/splash';
  static const login = '/login';
  static const forbidden = '/forbidden';
  static const dashboard = '/app/dashboard';
  static const reports = '/app/reports';
  static const access = '/app/access';
  static const units = '/app/units';
  static const bookings = '/app/bookings';
  static const crm = '/app/crm';
  static const finance = '/app/finance';
  static const housekeeping = '/worker/housekeeping';
  static const maintenance = '/worker/maintenance';

  static String unit(String unitId) => '/app/units/$unitId';
  static String booking(String bookingId) => '/app/bookings/$bookingId';
  static String client(String clientId) => '/app/crm/$clientId';
}
