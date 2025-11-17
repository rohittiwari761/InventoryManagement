class AssignedStore {
  final int id;
  final String name;
  final String? assignedAt;

  AssignedStore({
    required this.id,
    required this.name,
    this.assignedAt,
  });

  factory AssignedStore.fromJson(Map<String, dynamic> json) {
    return AssignedStore(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      assignedAt: json['assigned_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'assigned_at': assignedAt,
    };
  }
}

class User {
  final int id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String invoiceLayoutPreference;
  final String fullName;
  final int? createdBy;
  final String? createdByName;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AssignedStore> assignedStores;
  final String approvalStatus;
  final int? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.role,
    this.invoiceLayoutPreference = 'classic',
    required this.fullName,
    this.createdBy,
    this.createdByName,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.assignedStores = const [],
    this.approvalStatus = 'pending',
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
  });

  String get displayName => fullName.isNotEmpty ? fullName : '$firstName $lastName';

  bool get isAdmin => role == 'admin';
  bool get isStoreUser => role == 'store_user';
  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  factory User.fromJson(Map<String, dynamic> json) {
    // Generate full name from first and last name if full_name is not provided
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';
    final fullName = json['full_name'] ?? '$firstName $lastName'.trim();

    // Parse assigned stores
    List<AssignedStore> stores = [];
    if (json['assigned_stores'] != null && json['assigned_stores'] is List) {
      try {
        stores = (json['assigned_stores'] as List)
            .map((store) => AssignedStore.fromJson(store))
            .toList();
      } catch (e) {
      }
    } else {
    }

    return User(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      firstName: firstName,
      lastName: lastName,
      phone: json['phone'],
      role: json['role'] ?? 'store_user',
      invoiceLayoutPreference: json['invoice_layout_preference'] ?? 'classic',
      fullName: fullName,
      createdBy: json['created_by'] != null ?
        (json['created_by'] is int ? json['created_by'] : int.parse(json['created_by'].toString())) : null,
      createdByName: json['created_by_name'],
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      assignedStores: stores,
      approvalStatus: json['approval_status'] ?? 'pending',
      approvedBy: json['approved_by'] != null ?
        (json['approved_by'] is int ? json['approved_by'] : int.parse(json['approved_by'].toString())) : null,
      approvedByName: json['approved_by_name'],
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role': role,
      'invoice_layout_preference': invoiceLayoutPreference,
      'full_name': fullName,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'assigned_stores': assignedStores.map((store) => store.toJson()).toList(),
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_by_name': approvedByName,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    String? invoiceLayoutPreference,
    String? fullName,
    int? createdBy,
    String? createdByName,
    bool? isVerified,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AssignedStore>? assignedStores,
    String? approvalStatus,
    int? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      invoiceLayoutPreference: invoiceLayoutPreference ?? this.invoiceLayoutPreference,
      fullName: fullName ?? this.fullName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedStores: assignedStores ?? this.assignedStores,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}