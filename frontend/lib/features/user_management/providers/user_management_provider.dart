import 'package:flutter/foundation.dart';
import '../../../shared/models/user.dart';
import '../services/user_management_service.dart';

class UserManagementProvider extends ChangeNotifier {
  final UserManagementService _userService = UserManagementService();
  
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = false;
  String? _errorMessage;

  List<User> get users => _users;
  User? get selectedUser => _selectedUser;
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

  Future<void> fetchUsers() async {
    _setLoading(true);
    _setError(null);
    try {
      _users = await _userService.getUsers();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> fetchUser(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      _selectedUser = await _userService.getUser(id);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<User?> createUser({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    String? phone,
    required String role,
    required String password,
    required String passwordConfirm,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = await _userService.createUser(
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      _users.add(user);
      _setLoading(false);
      return user;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<bool> updateUser({
    required int id,
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    String? phone,
    required String role,
    required bool isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedUser = await _userService.updateUser(
        id: id,
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
        isActive: isActive,
      );
      
      final index = _users.indexWhere((u) => u.id == id);
      if (index != -1) {
        _users[index] = updatedUser;
      }
      
      if (_selectedUser?.id == id) {
        _selectedUser = updatedUser;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _userService.deleteUser(id);
      _users.removeWhere((u) => u.id == id);
      
      if (_selectedUser?.id == id) {
        _selectedUser = null;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> assignUserToStore(int userId, int storeId) async {
    try {
      await _userService.assignUserToStore(userId, storeId);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> removeUserFromStore(int userId, int storeId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _userService.removeUserFromStore(userId, storeId);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<List<User>> getStoreUsers(int storeId) async {
    try {
      return await _userService.getStoreUsers(storeId);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserStores(int userId) async {
    try {
      return await _userService.getUserStores(userId);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<bool> changeUserPassword({
    required int userId,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _userService.changeUserPassword(
        userId: userId,
        newPassword: newPassword,
        newPasswordConfirm: newPasswordConfirm,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> approveUser(int userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedUser = await _userService.approveUser(userId);

      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      if (_selectedUser?.id == userId) {
        _selectedUser = updatedUser;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> rejectUser(int userId) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedUser = await _userService.rejectUser(userId);

      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      if (_selectedUser?.id == userId) {
        _selectedUser = updatedUser;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<int> getPendingUsersCount() async {
    try {
      return await _userService.getPendingUsersCount();
    } catch (e) {
      _setError(e.toString());
      return 0;
    }
  }

  void selectUser(User user) {
    _selectedUser = user;
    notifyListeners();
  }

  void clearSelection() {
    _selectedUser = null;
    notifyListeners();
  }

  List<User> get storeUsers => _users.where((user) => user.isStoreUser).toList();

  void clear() {
    _users = [];
    _selectedUser = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}