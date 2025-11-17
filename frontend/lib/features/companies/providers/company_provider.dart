import 'package:flutter/foundation.dart';
import '../../../shared/models/company.dart';
import '../services/company_service.dart';

class CompanyProvider extends ChangeNotifier {
  final CompanyService _companyService = CompanyService();

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _isLoading = false;
  String? _errorMessage;

  List<Company> get companies => _companies;
  Company? get selectedCompany => _selectedCompany;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchCompanies() async {
    _setLoading(true);
    _setError(null);
    try {
      _companies = await _companyService.getCompanies();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> fetchCompany(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      _selectedCompany = await _companyService.getCompany(id);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createCompany({
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    required String email,
    required String gstin,
    required String pan,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final company = await _companyService.createCompany(
        name: name,
        description: description,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        email: email,
        gstin: gstin,
        pan: pan,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankIfsc: bankIfsc,
        bankBranch: bankBranch,
        isActive: isActive,
      );
      _companies.add(company);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateCompany({
    required int id,
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    required String email,
    required String gstin,
    required String pan,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedCompany = await _companyService.updateCompany(
        id: id,
        name: name,
        description: description,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        email: email,
        gstin: gstin,
        pan: pan,
        bankName: bankName,
        bankAccountNumber: bankAccountNumber,
        bankIfsc: bankIfsc,
        bankBranch: bankBranch,
        isActive: isActive,
      );

      final index = _companies.indexWhere((c) => c.id == id);
      if (index != -1) {
        _companies[index] = updatedCompany;
      }

      if (_selectedCompany?.id == id) {
        _selectedCompany = updatedCompany;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteCompany(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _companyService.deleteCompany(id);
      _companies.removeWhere((c) => c.id == id);

      if (_selectedCompany?.id == id) {
        _selectedCompany = null;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void selectCompany(Company company) {
    _selectedCompany = company;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCompany = null;
    notifyListeners();
  }

  void clear() {
    _companies = [];
    _selectedCompany = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
