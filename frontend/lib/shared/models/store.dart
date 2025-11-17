class Store {
  final int id;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final String? email;
  final String invoiceLayoutPreference;
  final int company;
  final String? companyName;
  final int? manager;
  final String? managerName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Store({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.phone,
    this.email,
    this.invoiceLayoutPreference = 'traditional',
    required this.company,
    this.companyName,
    this.manager,
    this.managerName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      name: json['name'] ?? '',
      description: json['description'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      invoiceLayoutPreference: json['invoice_layout_preference'] ?? 'traditional',
      company: json['company'] is int ? json['company'] : (json['company'] != null ? int.parse(json['company'].toString()) : 0),
      companyName: json['company_name'],
      manager: json['manager'] != null ? 
        (json['manager'] is int ? json['manager'] : int.parse(json['manager'].toString())) : null,
      managerName: json['manager_name'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'invoice_layout_preference': invoiceLayoutPreference,
      'company': company,
      'company_name': companyName,
      'manager': manager,
      'manager_name': managerName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Store && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Store(id: $id, name: $name)';
  }
}

class StoreUser {
  final int id;
  final int user;
  final String? userName;
  final String? userEmail;
  final int store;
  final String? storeName;
  final bool isActive;
  final DateTime assignedAt;

  StoreUser({
    required this.id,
    required this.user,
    this.userName,
    this.userEmail,
    required this.store,
    this.storeName,
    required this.isActive,
    required this.assignedAt,
  });

  factory StoreUser.fromJson(Map<String, dynamic> json) {
    return StoreUser(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      user: json['user'] is int ? json['user'] : (json['user'] != null ? int.parse(json['user'].toString()) : 0),
      userName: json['user_name'],
      userEmail: json['user_email'],
      store: json['store'] is int ? json['store'] : (json['store'] != null ? int.parse(json['store'].toString()) : 0),
      storeName: json['store_name'],
      isActive: json['is_active'] ?? true,
      assignedAt: DateTime.parse(json['assigned_at']),
    );
  }
}