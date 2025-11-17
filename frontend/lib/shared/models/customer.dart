class Customer {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final String? gstin;
  final String? phone;
  final String? email;
  final String? website;
  final String? contactPerson;
  final String? pan;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.country,
    this.gstin,
    this.phone,
    this.email,
    this.website,
    this.contactPerson,
    this.pan,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      name: json['name'] ?? '',
      address: json['address'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      country: json['country'],
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      contactPerson: json['contact_person'],
      pan: json['pan'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'gstin': gstin,
      'phone': phone,
      'email': email,
      'website': website,
      'contact_person': contactPerson,
      'pan': pan,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  String get formattedAddress {
    final addressParts = <String>[];
    
    if (address != null && address!.isNotEmpty) {
      addressParts.add(address!);
    }
    if (city != null && city!.isNotEmpty) {
      addressParts.add(city!);
    }
    if (state != null && state!.isNotEmpty) {
      addressParts.add(state!);
    }
    if (pincode != null && pincode!.isNotEmpty) {
      addressParts.add(pincode!);
    }
    if (country != null && country!.isNotEmpty) {
      addressParts.add(country!);
    }
    
    return addressParts.join(', ');
  }

  String get displayName {
    if (contactPerson != null && contactPerson!.isNotEmpty) {
      return '$name (${contactPerson!})';
    }
    return name;
  }

  bool get hasCompleteAddress {
    return address != null && 
           address!.isNotEmpty && 
           city != null && 
           city!.isNotEmpty && 
           state != null && 
           state!.isNotEmpty;
  }

  // Create a copy with updated fields
  Customer copyWith({
    int? id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? country,
    String? gstin,
    String? phone,
    String? email,
    String? website,
    String? contactPerson,
    String? pan,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      gstin: gstin ?? this.gstin,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      contactPerson: contactPerson ?? this.contactPerson,
      pan: pan ?? this.pan,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Customer(id: $id, name: $name, email: $email, phone: $phone)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}