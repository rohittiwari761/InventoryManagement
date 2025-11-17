class Item {
  final int id;
  final String name;
  final String? description;
  final String sku;
  final String? hsnCode;
  final String unit;
  final double price;
  final double taxRate;
  final List<int> companies;
  final List<String>? companyNames;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item({
    required this.id,
    required this.name,
    this.description,
    required this.sku,
    this.hsnCode,
    required this.unit,
    required this.price,
    required this.taxRate,
    required this.companies,
    this.companyNames,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    // Parse companies list
    List<int> companies = [];
    if (json['companies'] != null && json['companies'] is List) {
      companies = (json['companies'] as List)
          .map((id) => id is int ? id : int.parse(id.toString()))
          .toList();
    }

    // Parse company names list
    List<String>? companyNames;
    if (json['company_names'] != null && json['company_names'] is List) {
      companyNames = (json['company_names'] as List)
          .map((name) => name.toString())
          .toList();
    }

    return Item(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      name: json['name'] ?? '',
      description: json['description'],
      sku: json['sku'] ?? '',
      hsnCode: json['hsn_code'],
      unit: json['unit'] ?? '',
      price: json['price'] != null ? double.parse(json['price'].toString()) : 0.0,
      taxRate: json['tax_rate'] != null ? double.parse(json['tax_rate'].toString()) : 0.0,
      companies: companies,
      companyNames: companyNames,
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
      'sku': sku,
      'hsn_code': hsnCode,
      'unit': unit,
      'price': price,
      'tax_rate': taxRate,
      'companies': companies,
      'company_names': companyNames,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Item(id: $id, name: $name, sku: $sku)';
  }
}

class StoreInventory {
  final int id;
  final int item;
  final String? itemName;
  final String? itemSku;
  final String? itemUnit;
  final double? itemPrice;
  final int store;
  final String? storeName;
  final int company;
  final String? companyName;
  final double quantity;
  final double minStockLevel;
  final double maxStockLevel;
  final bool isLowStock;
  final DateTime lastUpdated;

  StoreInventory({
    required this.id,
    required this.item,
    this.itemName,
    this.itemSku,
    this.itemUnit,
    this.itemPrice,
    required this.store,
    this.storeName,
    required this.company,
    this.companyName,
    required this.quantity,
    required this.minStockLevel,
    required this.maxStockLevel,
    required this.isLowStock,
    required this.lastUpdated,
  });

  factory StoreInventory.fromJson(Map<String, dynamic> json) {
    return StoreInventory(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.parse(json['id'].toString()) : 0),
      item: json['item'] is int ? json['item'] : (json['item'] != null ? int.parse(json['item'].toString()) : 0),
      itemName: json['item_name'],
      itemSku: json['item_sku'],
      itemUnit: json['item_unit'],
      itemPrice: json['item_price'] != null
          ? double.parse(json['item_price'].toString())
          : null,
      store: json['store'] is int ? json['store'] : (json['store'] != null ? int.parse(json['store'].toString()) : 0),
      storeName: json['store_name'],
      company: json['company'] is int ? json['company'] : (json['company'] != null ? int.parse(json['company'].toString()) : 0),
      companyName: json['company_name'],
      quantity: json['quantity'] != null ? double.parse(json['quantity'].toString()) : 0.0,
      minStockLevel: json['min_stock_level'] != null ? double.parse(json['min_stock_level'].toString()) : 0.0,
      maxStockLevel: json['max_stock_level'] != null ? double.parse(json['max_stock_level'].toString()) : 0.0,
      isLowStock: json['is_low_stock'] ?? false,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item': item,
      'item_name': itemName,
      'item_sku': itemSku,
      'item_unit': itemUnit,
      'item_price': itemPrice,
      'store': store,
      'store_name': storeName,
      'company': company,
      'company_name': companyName,
      'quantity': quantity,
      'min_stock_level': minStockLevel,
      'max_stock_level': maxStockLevel,
      'is_low_stock': isLowStock,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}