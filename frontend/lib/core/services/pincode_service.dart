import 'package:dio/dio.dart';

class PincodeDetails {
  final String city;
  final String state;
  final String district;
  final String country;

  PincodeDetails({
    required this.city,
    required this.state,
    required this.district,
    required this.country,
  });

  factory PincodeDetails.fromJson(Map<String, dynamic> json) {
    return PincodeDetails(
      city: json['District'] ?? '',
      state: json['State'] ?? '',
      district: json['District'] ?? '',
      country: json['Country'] ?? 'India',
    );
  }
}

class PincodeService {
  final Dio _dio = Dio();

  /// Lookup city and state details from Indian pincode
  /// Uses free PostalPinCode.in API
  Future<PincodeDetails?> lookupPincode(String pincode) async {
    // Validate pincode format (6 digits)
    if (pincode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pincode)) {
      return null;
    }

    try {
      final response = await _dio.get(
        'https://api.postalpincode.in/pincode/$pincode',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final List data = response.data;

        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'] as List?;

          if (postOffices != null && postOffices.isNotEmpty) {
            // Return the first post office details
            return PincodeDetails.fromJson(postOffices[0]);
          }
        }
      }

      return null;
    } catch (e) {
      // Handle network errors, timeouts, etc.
      print('Error looking up pincode: $e');
      return null;
    }
  }

  /// Dispose the Dio instance
  void dispose() {
    _dio.close();
  }
}
