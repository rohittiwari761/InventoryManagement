import 'dart:io';

class AppConstants {
  static const String appName = 'Inventory Management System';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const bool useProductionApi = true; // Set to false to use local development server
  static const String productionUrl = 'https://inventorymanagement-production-e0e9.up.railway.app/api';

  // Local development URLs
  static const String localUrl = 'http://localhost:8000/api'; // For iOS Simulator and web
  static const String networkUrl = 'http://192.168.1.18:8000/api'; // For physical devices (iPhone/Android) on same network

  // Dynamic base URL based on configuration
  static String get baseUrl {
    // Allow environment variable override
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Use production API if enabled
    if (useProductionApi) {
      return productionUrl;
    }

    // Development mode: Use local server
    // For physical devices (Android or iOS), use network URL
    // For simulators/emulators, use localhost
    if (Platform.isAndroid || Platform.isIOS) {
      // Check if running on physical device vs simulator
      // Physical devices need the network IP, simulators can use localhost
      return networkUrl; // Use your Mac's local IP address
    }

    return localUrl; // For web and desktop platforms
  }
  
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
  
  static const List<String> indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Puducherry',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Lakshadweep',
    'Ladakh',
    'Jammu and Kashmir'
  ];
  
  static const List<String> itemUnits = [
    'kg',
    'g',
    'piece',
    'litre',
    'ml',
    'meter',
    'cm',
    'box',
    'dozen'
  ];
  
  static const Map<String, String> unitLabels = {
    'kg': 'Kilogram',
    'g': 'Gram',
    'piece': 'Piece',
    'litre': 'Litre',
    'ml': 'Millilitre',
    'meter': 'Meter',
    'cm': 'Centimeter',
    'box': 'Box',
    'dozen': 'Dozen',
  };
}