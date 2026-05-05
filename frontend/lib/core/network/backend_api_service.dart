import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_client.dart';

double _asDouble(Object? value) {
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    return value;
  }
  return double.tryParse('$value') ?? 0;
}

class DashboardKpis {
  const DashboardKpis({
    required this.totalUnits,
    required this.occupiedUnits,
    required this.activeBookings,
    required this.pendingCleaning,
    required this.openTickets,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.occupancyRate,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      totalUnits: json['total_units'] as int? ?? 0,
      occupiedUnits: json['occupied_units'] as int? ?? 0,
      activeBookings: json['active_bookings'] as int? ?? 0,
      pendingCleaning: json['pending_cleaning'] as int? ?? 0,
      openTickets: json['open_tickets'] as int? ?? 0,
      totalRevenue: _asDouble(json['total_revenue']),
      totalExpenses: _asDouble(json['total_expenses']),
      occupancyRate: _asDouble(json['occupancy_rate']),
    );
  }

  final int totalUnits;
  final int occupiedUnits;
  final int activeBookings;
  final int pendingCleaning;
  final int openTickets;
  final double totalRevenue;
  final double totalExpenses;
  final double occupancyRate;
}

class UnitSummary {
  const UnitSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.status,
    required this.nightlyRate,
    required this.coverImagePath,
    required this.coverImageUrl,
    required this.amenityCodes,
  });

  factory UnitSummary.fromJson(Map<String, dynamic> json) {
    return UnitSummary(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      status: json['status'] as String? ?? '',
      nightlyRate: _asDouble(json['nightly_rate']),
      coverImagePath: json['cover_image_path'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      amenityCodes: ((json['amenity_codes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  final String id;
  final String code;
  final String name;
  final String city;
  final String status;
  final double nightlyRate;
  final String? coverImagePath;
  final String? coverImageUrl;
  final List<String> amenityCodes;
}

class AmenityOption {
  const AmenityOption({
    required this.id,
    required this.code,
    required this.name,
  });

  factory AmenityOption.fromJson(Map<String, dynamic> json) {
    return AmenityOption(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  final String id;
  final String code;
  final String name;
}

class UnitImageAsset {
  const UnitImageAsset({
    required this.id,
    required this.filePath,
    required this.originalFilename,
    required this.contentType,
    required this.sizeBytes,
    required this.isCover,
    required this.sortOrder,
    required this.publicUrl,
  });

  factory UnitImageAsset.fromJson(Map<String, dynamic> json) {
    return UnitImageAsset(
      id: json['id'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      originalFilename: json['original_filename'] as String?,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int?,
      isCover: json['is_cover'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      publicUrl: json['public_url'] as String?,
    );
  }

  final String id;
  final String filePath;
  final String? originalFilename;
  final String? contentType;
  final int? sizeBytes;
  final bool isCover;
  final int sortOrder;
  final String? publicUrl;

  bool get isImage => (contentType ?? '').startsWith('image/');

  String get displayName {
    if (originalFilename != null && originalFilename!.isNotEmpty) {
      return originalFilename!;
    }
    if (filePath.isEmpty) {
      return 'attachment';
    }
    return filePath.split('/').last;
  }
}

class UnitDetail {
  const UnitDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.country,
    required this.status,
    required this.nightlyRate,
    required this.monthlyRate,
    required this.monthlyDepreciation,
    required this.currency,
    required this.capacity,
    required this.bedrooms,
    required this.bathrooms,
    required this.isActive,
    required this.smartLockCodeEncrypted,
    required this.images,
    required this.amenities,
  });

  factory UnitDetail.fromJson(Map<String, dynamic> json) {
    return UnitDetail(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      status: json['status'] as String? ?? '',
      nightlyRate: _asDouble(json['nightly_rate']),
      monthlyRate: _asDouble(json['monthly_rate']),
      monthlyDepreciation: _asDouble(json['monthly_depreciation']),
      currency: json['currency'] as String? ?? 'SAR',
      capacity: json['capacity'] as int? ?? 0,
      bedrooms: json['bedrooms'] as int? ?? 0,
      bathrooms: json['bathrooms'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      smartLockCodeEncrypted: json['smart_lock_code_encrypted'] as String?,
      images: ((json['images'] as List?) ?? const [])
          .cast<Map>()
          .map((item) => UnitImageAsset.fromJson(item.cast<String, dynamic>()))
          .toList(),
      amenities: ((json['amenities'] as List?) ?? const [])
          .cast<Map>()
          .map((item) => AmenityOption.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }

  final String id;
  final String code;
  final String name;
  final String city;
  final String country;
  final String status;
  final double nightlyRate;
  final double monthlyRate;
  final double monthlyDepreciation;
  final String currency;
  final int capacity;
  final int bedrooms;
  final int bathrooms;
  final bool isActive;
  final String? smartLockCodeEncrypted;
  final List<UnitImageAsset> images;
  final List<AmenityOption> amenities;
}

class BookingSummary {
  const BookingSummary({
    required this.id,
    required this.unitId,
    required this.bookingReference,
    required this.clientName,
    required this.clientPhone,
    required this.status,
    required this.paymentStatus,
    required this.checkInAt,
    required this.checkOutAt,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    return BookingSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      bookingReference: json['booking_reference'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      clientPhone: json['client_phone'] as String? ?? '',
      status: json['status'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? '',
      checkInAt: json['check_in_at'] as String? ?? '',
      checkOutAt: json['check_out_at'] as String? ?? '',
    );
  }

  final String id;
  final String unitId;
  final String bookingReference;
  final String clientName;
  final String clientPhone;
  final String status;
  final String paymentStatus;
  final String checkInAt;
  final String checkOutAt;
}

class ClientSummary {
  const ClientSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isBlacklisted,
  });

  factory ClientSummary.fromJson(Map<String, dynamic> json) {
    return ClientSummary(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      isBlacklisted: json['is_blacklisted'] as bool? ?? false,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final bool isBlacklisted;
}

class PaymentSummary {
  const PaymentSummary({
    required this.id,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.createdAt,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String?,
      unitCode: json['unit_code'] as String?,
      unitName: json['unit_name'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      amount: _asDouble(json['amount']),
      currency: json['currency'] as String? ?? '',
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  final String id;
  final String? unitId;
  final String? unitCode;
  final String? unitName;
  final DateTime createdAt;
  final double amount;
  final String currency;
  final String method;
  final String status;
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.id,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.createdAt,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
  });

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String?,
      unitCode: json['unit_code'] as String?,
      unitName: json['unit_name'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: _asDouble(json['amount']),
      currency: json['currency'] as String? ?? '',
    );
  }

  final String id;
  final String? unitId;
  final String? unitCode;
  final String? unitName;
  final DateTime createdAt;
  final String category;
  final String description;
  final double amount;
  final String currency;
}

class AssetSummary {
  const AssetSummary({
    required this.id,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.name,
    required this.category,
    required this.acquisitionCost,
    required this.residualValue,
    required this.usefulLifeMonths,
    required this.commissionedAt,
    required this.monthlyDepreciation,
    required this.periodDepreciation,
    required this.isActive,
    required this.notes,
  });

  factory AssetSummary.fromJson(Map<String, dynamic> json) {
    return AssetSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      unitCode: json['unit_code'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      acquisitionCost: _asDouble(json['acquisition_cost']),
      residualValue: _asDouble(json['residual_value']),
      usefulLifeMonths: json['useful_life_months'] as int? ?? 0,
      commissionedAt:
          DateTime.tryParse(json['commissioned_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      monthlyDepreciation: _asDouble(json['monthly_depreciation']),
      periodDepreciation: _asDouble(json['period_depreciation']),
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String unitId;
  final String unitCode;
  final String unitName;
  final String name;
  final String category;
  final double acquisitionCost;
  final double residualValue;
  final int usefulLifeMonths;
  final DateTime commissionedAt;
  final double monthlyDepreciation;
  final double periodDepreciation;
  final bool isActive;
  final String? notes;
}

class UnitCostCenterSummary {
  const UnitCostCenterSummary({
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.currency,
    required this.revenue,
    required this.expenses,
    required this.capitalExpenditure,
    required this.depreciation,
    required this.profitLoss,
    required this.paymentCount,
    required this.expenseCount,
    required this.assetCount,
  });

  factory UnitCostCenterSummary.fromJson(Map<String, dynamic> json) {
    return UnitCostCenterSummary(
      unitId: json['unit_id'] as String? ?? '',
      unitCode: json['unit_code'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'SAR',
      revenue: _asDouble(json['revenue']),
      expenses: _asDouble(json['expenses']),
      capitalExpenditure: _asDouble(json['capital_expenditure']),
      depreciation: _asDouble(json['depreciation']),
      profitLoss: _asDouble(json['profit_loss']),
      paymentCount: json['payment_count'] as int? ?? 0,
      expenseCount: json['expense_count'] as int? ?? 0,
      assetCount: json['asset_count'] as int? ?? 0,
    );
  }

  final String unitId;
  final String unitCode;
  final String unitName;
  final String currency;
  final double revenue;
  final double expenses;
  final double capitalExpenditure;
  final double depreciation;
  final double profitLoss;
  final int paymentCount;
  final int expenseCount;
  final int assetCount;
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.payments,
    required this.expenses,
    required this.assets,
    required this.costCenters,
  });

  final List<PaymentSummary> payments;
  final List<ExpenseSummary> expenses;
  final List<AssetSummary> assets;
  final List<UnitCostCenterSummary> costCenters;
}

class AccessPermissionEntry {
  const AccessPermissionEntry({
    required this.code,
    required this.name,
    required this.module,
    required this.description,
  });

  factory AccessPermissionEntry.fromJson(Map<String, dynamic> json) {
    return AccessPermissionEntry(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      module: json['module'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  final String code;
  final String name;
  final String module;
  final String description;
}

class AccessPermissionGroup {
  const AccessPermissionGroup({
    required this.code,
    required this.name,
    required this.permissionCodes,
    required this.isSystem,
    required this.memberCount,
  });

  factory AccessPermissionGroup.fromJson(Map<String, dynamic> json) {
    return AccessPermissionGroup(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      permissionCodes: ((json['permission_codes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      isSystem: json['is_system'] as bool? ?? false,
      memberCount: json['member_count'] as int? ?? 0,
    );
  }

  final String code;
  final String name;
  final List<String> permissionCodes;
  final bool isSystem;
  final int memberCount;
}

class UserPermissionOverrideEntry {
  const UserPermissionOverrideEntry({
    required this.permissionCode,
    required this.effect,
  });

  factory UserPermissionOverrideEntry.fromJson(Map<String, dynamic> json) {
    return UserPermissionOverrideEntry(
      permissionCode: json['permission_code'] as String? ?? '',
      effect: json['effect'] as String? ?? 'allow',
    );
  }

  final String permissionCode;
  final String effect;
}

class AssignedUnitSummary {
  const AssignedUnitSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
  });

  factory AssignedUnitSummary.fromJson(Map<String, dynamic> json) {
    return AssignedUnitSummary(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
    );
  }

  final String id;
  final String code;
  final String name;
  final String city;
}

class AccessUserSummary {
  const AccessUserSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.roleCodes,
  });

  factory AccessUserSummary.fromJson(Map<String, dynamic> json) {
    return AccessUserSummary(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      roleCodes: ((json['role_codes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final bool isActive;
  final List<String> roleCodes;
}

class AccessUserDetail extends AccessUserSummary {
  const AccessUserDetail({
    required super.id,
    required super.email,
    required super.fullName,
    required super.isActive,
    required super.roleCodes,
    required this.inheritedPermissions,
    required this.effectivePermissions,
    required this.overrides,
    required this.assignedUnitIds,
    required this.assignedUnits,
  });

  factory AccessUserDetail.fromJson(Map<String, dynamic> json) {
    return AccessUserDetail(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      roleCodes: ((json['role_codes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      inheritedPermissions:
          ((json['inherited_permissions'] as List?) ?? const [])
              .map((item) => '$item')
              .toList(),
      effectivePermissions:
          ((json['effective_permissions'] as List?) ?? const [])
              .map((item) => '$item')
              .toList(),
      overrides: ((json['overrides'] as List?) ?? const [])
          .cast<Map>()
          .map(
            (item) => UserPermissionOverrideEntry.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      assignedUnitIds: ((json['assigned_unit_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      assignedUnits: ((json['assigned_units'] as List?) ?? const [])
          .cast<Map>()
          .map(
            (item) => AssignedUnitSummary.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  final List<String> inheritedPermissions;
  final List<String> effectivePermissions;
  final List<UserPermissionOverrideEntry> overrides;
  final List<String> assignedUnitIds;
  final List<AssignedUnitSummary> assignedUnits;
}

class AccessUserCreateInput {
  const AccessUserCreateInput({
    required this.fullName,
    required this.email,
    required this.password,
    this.isActive = true,
    this.roleCodes = const [],
    this.overrides = const [],
    this.assignedUnitIds = const [],
  });

  final String fullName;
  final String email;
  final String password;
  final bool isActive;
  final List<String> roleCodes;
  final List<UserPermissionOverrideEntry> overrides;
  final List<String> assignedUnitIds;
}

class OperationTeamMemberSummary {
  const OperationTeamMemberSummary({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleCodes,
  });

  factory OperationTeamMemberSummary.fromJson(Map<String, dynamic> json) {
    return OperationTeamMemberSummary(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      roleCodes: ((json['role_codes'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final List<String> roleCodes;
}

class OperationTeamKpiSummary {
  const OperationTeamKpiSummary({
    required this.openWorkItems,
    required this.overdueWorkItems,
    required this.averageCloseHours,
  });

  factory OperationTeamKpiSummary.fromJson(Map<String, dynamic> json) {
    return OperationTeamKpiSummary(
      openWorkItems: json['open_work_items'] as int? ?? 0,
      overdueWorkItems: json['overdue_work_items'] as int? ?? 0,
      averageCloseHours: _asDouble(json['average_close_hours']),
    );
  }

  final int openWorkItems;
  final int overdueWorkItems;
  final double averageCloseHours;
}

class OperationTeamSummary {
  const OperationTeamSummary({
    required this.id,
    required this.name,
    required this.operationType,
    required this.description,
    required this.isActive,
    required this.unitIds,
    required this.memberUserIds,
    required this.units,
    required this.members,
    required this.kpis,
  });

  factory OperationTeamSummary.fromJson(Map<String, dynamic> json) {
    return OperationTeamSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      operationType: json['operation_type'] as String? ?? 'housekeeping',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      unitIds: ((json['unit_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      memberUserIds: ((json['member_user_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      units: ((json['units'] as List?) ?? const [])
          .cast<Map>()
          .map(
            (item) => AssignedUnitSummary.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      members: ((json['members'] as List?) ?? const [])
          .cast<Map>()
          .map(
            (item) => OperationTeamMemberSummary.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      kpis: OperationTeamKpiSummary.fromJson(
        (json['kpis'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String name;
  final String operationType;
  final String? description;
  final bool isActive;
  final List<String> unitIds;
  final List<String> memberUserIds;
  final List<AssignedUnitSummary> units;
  final List<OperationTeamMemberSummary> members;
  final OperationTeamKpiSummary kpis;
}

class AssignableUserSummary {
  const AssignableUserSummary({
    required this.id,
    required this.targetType,
    required this.name,
    required this.email,
    required this.description,
    required this.assignedUnitIds,
    required this.memberUserIds,
  });

  factory AssignableUserSummary.fromJson(Map<String, dynamic> json) {
    return AssignableUserSummary(
      id: json['id'] as String? ?? '',
      targetType: json['target_type'] as String? ?? 'user',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      description: json['description'] as String?,
      assignedUnitIds: ((json['assigned_unit_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
      memberUserIds: ((json['member_user_ids'] as List?) ?? const [])
          .map((item) => '$item')
          .toList(),
    );
  }

  final String id;
  final String targetType;
  final String name;
  final String? email;
  final String? description;
  final List<String> assignedUnitIds;
  final List<String> memberUserIds;

  bool get isTeam => targetType == 'team';

  String get fullName => name;
}

class HousekeepingTaskSummary {
  const HousekeepingTaskSummary({
    required this.id,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.bookingId,
    required this.assignedUserId,
    required this.assignedUserName,
    required this.assignedUserEmail,
    required this.assignedTeamId,
    required this.assignedTeamName,
    required this.status,
    required this.priority,
    required this.notes,
  });

  factory HousekeepingTaskSummary.fromJson(Map<String, dynamic> json) {
    return HousekeepingTaskSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      unitCode: json['unit_code'] as String?,
      unitName: json['unit_name'] as String?,
      bookingId: json['booking_id'] as String?,
      assignedUserId: json['assigned_user_id'] as String?,
      assignedUserName: json['assigned_user_name'] as String?,
      assignedUserEmail: json['assigned_user_email'] as String?,
      assignedTeamId: json['assigned_team_id'] as String?,
      assignedTeamName: json['assigned_team_name'] as String?,
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String unitId;
  final String? unitCode;
  final String? unitName;
  final String? bookingId;
  final String? assignedUserId;
  final String? assignedUserName;
  final String? assignedUserEmail;
  final String? assignedTeamId;
  final String? assignedTeamName;
  final String status;
  final String priority;
  final String? notes;
}

class MaintenanceTicketSummary {
  const MaintenanceTicketSummary({
    required this.id,
    required this.unitId,
    required this.unitCode,
    required this.unitName,
    required this.bookingId,
    required this.assignedUserId,
    required this.assignedUserName,
    required this.assignedUserEmail,
    required this.assignedTeamId,
    required this.assignedTeamName,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
  });

  factory MaintenanceTicketSummary.fromJson(Map<String, dynamic> json) {
    return MaintenanceTicketSummary(
      id: json['id'] as String? ?? '',
      unitId: json['unit_id'] as String? ?? '',
      unitCode: json['unit_code'] as String?,
      unitName: json['unit_name'] as String?,
      bookingId: json['booking_id'] as String?,
      assignedUserId: json['assigned_user_id'] as String?,
      assignedUserName: json['assigned_user_name'] as String?,
      assignedUserEmail: json['assigned_user_email'] as String?,
      assignedTeamId: json['assigned_team_id'] as String?,
      assignedTeamName: json['assigned_team_name'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
    );
  }

  final String id;
  final String unitId;
  final String? unitCode;
  final String? unitName;
  final String? bookingId;
  final String? assignedUserId;
  final String? assignedUserName;
  final String? assignedUserEmail;
  final String? assignedTeamId;
  final String? assignedTeamName;
  final String title;
  final String? description;
  final String status;
  final String priority;
}

class NotificationFeedItem {
  const NotificationFeedItem({
    required this.id,
    required this.recipientUserId,
    required this.actorUserId,
    required this.kind,
    required this.title,
    required this.body,
    required this.resourceType,
    required this.resourceId,
    required this.metadataJson,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationFeedItem.fromJson(Map<String, dynamic> json) {
    return NotificationFeedItem(
      id: json['id'] as String? ?? '',
      recipientUserId: json['recipient_user_id'] as String? ?? '',
      actorUserId: json['actor_user_id'] as String?,
      kind: json['kind'] as String? ?? 'broadcast',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      resourceType: json['resource_type'] as String?,
      resourceId: json['resource_id'] as String?,
      metadataJson: json['metadata_json'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  final String id;
  final String recipientUserId;
  final String? actorUserId;
  final String kind;
  final String title;
  final String body;
  final String? resourceType;
  final String? resourceId;
  final String? metadataJson;
  final bool isRead;
  final String? readAt;
  final String createdAt;
}

class NotificationStats {
  const NotificationStats({required this.unreadCount});

  factory NotificationStats.fromJson(Map<String, dynamic> json) {
    return NotificationStats(unreadCount: json['unread_count'] as int? ?? 0);
  }

  final int unreadCount;
}

class NotificationDeliveryConfig {
  const NotificationDeliveryConfig({
    required this.enabled,
    required this.appId,
    required this.serviceWorkerPath,
    required this.serviceWorkerScope,
  });

  factory NotificationDeliveryConfig.fromJson(Map<String, dynamic> json) {
    return NotificationDeliveryConfig(
      enabled: json['enabled'] as bool? ?? false,
      appId: json['app_id'] as String? ?? '',
      serviceWorkerPath:
          json['service_worker_path'] as String? ??
          'push/onesignal/OneSignalSDKWorker.js',
      serviceWorkerScope:
          json['service_worker_scope'] as String? ?? '/push/onesignal/',
    );
  }

  final bool enabled;
  final String appId;
  final String serviceWorkerPath;
  final String serviceWorkerScope;
}

class BackendApiService {
  BackendApiService(this._dio);

  final Dio _dio;

  Future<DashboardKpis> fetchDashboard() async {
    final response = await _dio.get<Map<String, dynamic>>('reports/dashboard');
    return DashboardKpis.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<DashboardKpis> fetchReportsSummary() async {
    final response = await _dio.get<Map<String, dynamic>>('reports/summary');
    return DashboardKpis.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<UnitSummary>> fetchUnits({int pageSize = 100}) async {
    final resolvedPageSize = pageSize.clamp(1, 100);
    final response = await _dio.get<Map<String, dynamic>>(
      'units',
      queryParameters: {'page_size': resolvedPageSize},
    );
    final items = ((response.data?['items'] as List?) ?? const [])
        .cast<Map>()
        .map((item) => UnitSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    return items;
  }

  Future<UnitDetail> fetchUnitDetail(String unitId) async {
    final response = await _dio.get<Map<String, dynamic>>('units/$unitId');
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<AmenityOption>> fetchUnitAmenitiesCatalog() async {
    final response = await _dio.get<List<dynamic>>('units/amenities/catalog');
    return (response.data ?? const [])
        .cast<Map>()
        .map((item) => AmenityOption.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<UnitDetail> createUnit(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'units',
      data: payload,
    );
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<UnitDetail> updateUnit(
    String unitId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'units/$unitId',
      data: payload,
    );
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<UnitDetail> updateUnitAmenities(
    String unitId,
    List<String> amenityCodes,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      'units/$unitId/amenities',
      data: {'amenity_codes': amenityCodes},
    );
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<UnitDetail> uploadUnitImage(
    String unitId,
    PlatformFile file, {
    required bool isCover,
    required int sortOrder,
  }) async {
    if (file.bytes == null) {
      throw StateError('Unable to read the selected file.');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      'units/$unitId/images',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        'is_cover': isCover,
        'sort_order': sortOrder,
      }),
    );
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<UnitDetail> deleteUnitImage(String unitId, String imageId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      'units/$unitId/images/$imageId',
    );
    return UnitDetail.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> deactivateUnit(String unitId) async {
    await _dio.delete('units/$unitId');
  }

  Future<List<BookingSummary>> fetchBookings() async {
    final response = await _dio.get<Map<String, dynamic>>('bookings');
    final items = ((response.data?['items'] as List?) ?? const [])
        .cast<Map>()
        .map((item) => BookingSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    return items;
  }

  Future<BookingSummary> createBooking({
    required String unitId,
    required String clientName,
    required String clientPhone,
    required DateTime checkInAt,
    required DateTime checkOutAt,
    required int guestCount,
    required double totalAmount,
    String sourceChannel = 'direct',
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'bookings',
      data: {
        'unit_id': unitId,
        'client_name': clientName,
        'client_phone': clientPhone,
        'source_channel': sourceChannel,
        'check_in_at': checkInAt.toUtc().toIso8601String(),
        'check_out_at': checkOutAt.toUtc().toIso8601String(),
        'guest_count': guestCount,
        'base_amount': totalAmount,
        'tax_amount': 0,
        'security_deposit': 0,
        'total_amount': totalAmount,
        'outstanding_amount': totalAmount,
      },
    );
    return BookingSummary.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<void> checkInBooking(String bookingId) async {
    await _dio.post('bookings/$bookingId/check-in');
  }

  Future<void> checkOutBooking(String bookingId) async {
    await _dio.post('bookings/$bookingId/check-out');
  }

  Future<List<ClientSummary>> fetchClients() async {
    final response = await _dio.get<Map<String, dynamic>>('clients');
    final items = ((response.data?['items'] as List?) ?? const [])
        .cast<Map>()
        .map((item) => ClientSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    return items;
  }

  Future<FinanceSnapshot> fetchFinance({
    required String period,
    required DateTime anchorDate,
  }) async {
    final queryParameters = {
      'period': period,
      'anchor_date': anchorDate.toIso8601String().split('T').first,
    };
    final responses = await Future.wait([
      _dio.get<List<dynamic>>(
        'finance/payments',
        queryParameters: queryParameters,
      ),
      _dio.get<List<dynamic>>(
        'finance/expenses',
        queryParameters: queryParameters,
      ),
      _dio.get<List<dynamic>>(
        'finance/assets',
        queryParameters: queryParameters,
      ),
      _dio.get<List<dynamic>>(
        'finance/cost-centers',
        queryParameters: queryParameters,
      ),
    ]);
    final payments = (responses[0].data ?? const [])
        .cast<Map>()
        .map((item) => PaymentSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    final expenses = (responses[1].data ?? const [])
        .cast<Map>()
        .map((item) => ExpenseSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    final assets = (responses[2].data ?? const [])
        .cast<Map>()
        .map((item) => AssetSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
    final costCenters = (responses[3].data ?? const [])
        .cast<Map>()
        .map(
          (item) => UnitCostCenterSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
    return FinanceSnapshot(
      payments: payments,
      expenses: expenses,
      assets: assets,
      costCenters: costCenters,
    );
  }

  Future<PaymentSummary> createPayment({
    required String bookingId,
    required double amount,
    required String method,
    String currency = 'SAR',
    String? referenceNo,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'finance/payments',
      data: {
        'booking_id': bookingId,
        'amount': amount,
        'method': method,
        'currency': currency,
        'reference_no': referenceNo,
      },
    );
    return PaymentSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<ExpenseSummary> createExpense({
    required String unitId,
    required String category,
    required double amount,
    String currency = 'SAR',
    String? description,
    String? bookingId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'finance/expenses',
      data: {
        'unit_id': unitId,
        'booking_id': bookingId,
        'category': category,
        'description': description,
        'amount': amount,
        'currency': currency,
      },
    );
    return ExpenseSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<AssetSummary> createAsset({
    required String unitId,
    required String name,
    required String category,
    required double acquisitionCost,
    required int usefulLifeMonths,
    double residualValue = 0,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'finance/assets',
      data: {
        'unit_id': unitId,
        'name': name,
        'category': category,
        'acquisition_cost': acquisitionCost,
        'residual_value': residualValue,
        'useful_life_months': usefulLifeMonths,
        'notes': notes,
      },
    );
    return AssetSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<List<AccessPermissionEntry>> fetchPermissionCatalog() async {
    final response = await _dio.get<List<dynamic>>(
      'access/permissions-catalog',
    );
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) =>
              AccessPermissionEntry.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<AccessPermissionGroup>> fetchPermissionGroups() async {
    final response = await _dio.get<List<dynamic>>('access/permission-groups');
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => AccessPermissionGroup.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<AccessPermissionGroup> createPermissionGroup({
    required String name,
    required List<String> permissionCodes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'access/permission-groups',
      data: {
        'name': name,
        'permission_codes': permissionCodes,
      },
    );
    return AccessPermissionGroup.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<AccessPermissionGroup> updatePermissionGroup(
    String roleCode, {
    required String name,
    required List<String> permissionCodes,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'access/permission-groups/$roleCode',
      data: {
        'name': name,
        'permission_codes': permissionCodes,
      },
    );
    return AccessPermissionGroup.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> deletePermissionGroup(String roleCode) async {
    await _dio.delete('access/permission-groups/$roleCode');
  }

  Future<List<AccessUserSummary>> fetchAccessUsers() async {
    final response = await _dio.get<List<dynamic>>('users');
    return (response.data ?? const [])
        .cast<Map>()
        .map((item) => AccessUserSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<AccessUserDetail> createAccessUser(AccessUserCreateInput input) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'users',
      data: {
        'full_name': input.fullName,
        'email': input.email,
        'password': input.password,
        'is_active': input.isActive,
        'role_codes': input.roleCodes,
        'overrides': [
          for (final override in input.overrides)
            {
              'permission_code': override.permissionCode,
              'effect': override.effect,
            },
        ],
        'assigned_unit_ids': input.assignedUnitIds,
      },
    );
    return AccessUserDetail.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> deleteAccessUser(String userId) async {
    await _dio.delete('users/$userId');
  }

  Future<AccessUserDetail> fetchUserAccess(String userId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'users/$userId/access',
    );
    return AccessUserDetail.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<AccessUserDetail> updateUserAccess(
    String userId, {
    required List<String> roleCodes,
    required List<UserPermissionOverrideEntry> overrides,
    required List<String> assignedUnitIds,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'users/$userId/access',
      data: {
        'role_codes': roleCodes,
        'overrides': [
          for (final override in overrides)
            {
              'permission_code': override.permissionCode,
              'effect': override.effect,
            },
        ],
        'assigned_unit_ids': assignedUnitIds,
      },
    );
    return AccessUserDetail.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<List<OperationTeamSummary>> fetchOperationTeams() async {
    final response = await _dio.get<List<dynamic>>('access/operation-teams');
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => OperationTeamSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<OperationTeamSummary> createOperationTeam({
    required String name,
    required String operationType,
    String? description,
    required bool isActive,
    required List<String> unitIds,
    required List<String> memberUserIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'access/operation-teams',
      data: {
        'name': name,
        'operation_type': operationType,
        'description': description,
        'is_active': isActive,
        'unit_ids': unitIds,
        'member_user_ids': memberUserIds,
      },
    );
    return OperationTeamSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<OperationTeamSummary> updateOperationTeam(
    String teamId, {
    required String name,
    required String operationType,
    String? description,
    required bool isActive,
    required List<String> unitIds,
    required List<String> memberUserIds,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'access/operation-teams/$teamId',
      data: {
        'name': name,
        'operation_type': operationType,
        'description': description,
        'is_active': isActive,
        'unit_ids': unitIds,
        'member_user_ids': memberUserIds,
      },
    );
    return OperationTeamSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<List<HousekeepingTaskSummary>> fetchHousekeepingTasks() async {
    final response = await _dio.get<List<dynamic>>('housekeeping/tasks');
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) =>
              HousekeepingTaskSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<AssignableUserSummary>> fetchHousekeepingAssignees({
    String? unitId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'housekeeping/assignees',
      queryParameters: unitId == null ? null : {'unit_id': unitId},
    );
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => AssignableUserSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<HousekeepingTaskSummary> createHousekeepingTask({
    required String unitId,
    String? bookingId,
    String? assignedUserId,
    String? assignedTeamId,
    String priority = 'normal',
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'housekeeping/tasks',
      data: {
        'unit_id': unitId,
        'booking_id': bookingId,
        'assigned_user_id': assignedUserId,
        'assigned_team_id': assignedTeamId,
        'priority': priority,
        'notes': notes,
      },
    );
    return HousekeepingTaskSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<HousekeepingTaskSummary> assignHousekeepingTask(
    String taskId, {
    String? assignedUserId,
    String? assignedTeamId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'housekeeping/tasks/$taskId/assignee',
      data: {
        'assigned_user_id': assignedUserId,
        'assigned_team_id': assignedTeamId,
      },
    );
    return HousekeepingTaskSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> completeHousekeepingTask(String taskId) async {
    await _dio.post('housekeeping/tasks/$taskId/complete');
  }

  Future<List<MaintenanceTicketSummary>> fetchMaintenanceTickets() async {
    final response = await _dio.get<List<dynamic>>('maintenance/tickets');
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) =>
              MaintenanceTicketSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<AssignableUserSummary>> fetchMaintenanceAssignees({
    String? unitId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      'maintenance/assignees',
      queryParameters: unitId == null ? null : {'unit_id': unitId},
    );
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => AssignableUserSummary.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<MaintenanceTicketSummary> createMaintenanceTicket({
    required String unitId,
    required String title,
    String? description,
    String priority = 'normal',
    String? bookingId,
    String? assignedUserId,
    String? assignedTeamId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'maintenance/tickets',
      data: {
        'unit_id': unitId,
        'title': title,
        'description': description,
        'priority': priority,
        'booking_id': bookingId,
        'assigned_user_id': assignedUserId,
        'assigned_team_id': assignedTeamId,
      },
    );
    return MaintenanceTicketSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<MaintenanceTicketSummary> assignMaintenanceTicket(
    String ticketId, {
    String? assignedUserId,
    String? assignedTeamId,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      'maintenance/tickets/$ticketId/assignee',
      data: {
        'assigned_user_id': assignedUserId,
        'assigned_team_id': assignedTeamId,
      },
    );
    return MaintenanceTicketSummary.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<void> resolveMaintenanceTicket(String ticketId) async {
    await _dio.post('maintenance/tickets/$ticketId/resolve');
  }

  Future<List<NotificationFeedItem>> fetchNotifications({int limit = 100}) async {
    final response = await _dio.get<List<dynamic>>(
      'notifications',
      queryParameters: {'limit': limit.clamp(1, 200)},
    );
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => NotificationFeedItem.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<NotificationStats> fetchNotificationStats() async {
    final response = await _dio.get<Map<String, dynamic>>('notifications/stats');
    return NotificationStats.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<NotificationFeedItem> markNotificationRead(String notificationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'notifications/$notificationId/read',
    );
    return NotificationFeedItem.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<int> markAllNotificationsRead() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'notifications/read-all',
    );
    return response.data?['updated'] as int? ?? 0;
  }

  Future<List<NotificationFeedItem>> createNotificationBroadcast({
    required String title,
    required String body,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      'notifications/broadcast',
      data: {'title': title, 'body': body},
    );
    return (response.data ?? const [])
        .cast<Map>()
        .map(
          (item) => NotificationFeedItem.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<NotificationDeliveryConfig> fetchNotificationDeliveryConfig() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'notifications/delivery-config',
    );
    return NotificationDeliveryConfig.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}

final backendApiProvider = Provider<BackendApiService>((ref) {
  return BackendApiService(ref.read(dioProvider));
});
