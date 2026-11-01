import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/services/api_services.dart';
import '../../../core/profile/profile_keys.dart';

/// Профиль пассажира — локальный кеш + синхронизация с сервером (логика 2048).
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({ApiServices? apiServices})
      : _api = apiServices ?? ApiServices();

  final ApiServices _api;

  bool _loaded = false;
  bool _syncing = false;
  String? _authToken;
  String _displayName = 'Гость';
  String _fullName = '';
  String _phone = '+7 (___) ___-__-__';
  int _avatarIndex = 0;
  int _bonusBalance = 0;
  int _referralCount = 0;
  String _myReferralCode = '';
  String? _usedReferralCode;
  String _promoCode = '';
  int _promoDiscountPercent = 0;
  String _addressHome = '';
  String _addressWork = '';
  String _addressFavorite = '';
  String? _clientId;
  String? _avatarBase64;

  static const avatarColors = <int>[
    0xFF7B5CFA,
    0xFFF5C518,
    0xFF4ADE80,
    0xFFEF4444,
    0xFF38BDF8,
    0xFFF97316,
  ];

  bool get loaded => _loaded;
  bool get syncing => _syncing;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;
  String? get authToken => _authToken;
  String? get clientId => _clientId;

  String get displayName => _displayName;
  String get fullName => _fullName;
  String get phone => _phone;
  String get name {
    final display = _cleanVisibleName(_displayName);
    if (display.isNotEmpty) return display;
    final full = _cleanVisibleName(_fullName);
    if (full.isNotEmpty) return full;
    return 'Гость';
  }

  int get avatarIndex => _avatarIndex;
  int get avatarColorValue => avatarColors[_avatarIndex % avatarColors.length];
  int get bonusBalance => _bonusBalance;
  int get referralCount => _referralCount;
  String get myReferralCode => _myReferralCode;
  String? get usedReferralCode => _usedReferralCode;
  String get promoCode => _promoCode;
  int get promoDiscountPercent => _promoDiscountPercent;
  String get addressHome => _addressHome;
  String get addressWork => _addressWork;
  String get addressFavorite => _addressFavorite;
  String? get avatarBase64 => _avatarBase64;

  bool get canUseReferralCode =>
      _usedReferralCode == null || _usedReferralCode!.trim().isEmpty;

  String get initials {
    final source = name;
    if (source == 'Гость') return 'Г';
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Г';
    final first = parts.first.replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]'), '');
    if (first.isEmpty) return 'Г';
    if (parts.length == 1) return first[0].toUpperCase();
    final lastRaw = parts.last.replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]'), '');
    if (lastRaw.isEmpty) return first[0].toUpperCase();
    return '${first[0]}${lastRaw[0]}'.toUpperCase();
  }

  String get effectiveReferralCode {
    if (_myReferralCode.isNotEmpty) return _myReferralCode;
    final id = _clientId ?? _phone.replaceAll(RegExp(r'\D'), '');
    return id;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(ProfileKeys.authToken);
    _displayName = prefs.getString(ProfileKeys.displayName) ?? 'Гость';
    if (_displayName.trim().isEmpty || _displayName.trim() == '?') {
      _displayName = 'Гость';
    }
    _fullName = prefs.getString(ProfileKeys.fullName) ?? '';
    if (_fullName.trim() == '?') _fullName = '';
    _phone = prefs.getString(ProfileKeys.phone) ?? '+7 (___) ___-__-__';
    _promoCode = prefs.getString(ProfileKeys.promoCode) ?? '';
    _promoDiscountPercent = prefs.getInt(ProfileKeys.promoDiscount) ?? 0;
    _addressHome = prefs.getString(ProfileKeys.addressHome) ?? '';
    _addressWork = prefs.getString(ProfileKeys.addressWork) ?? '';
    _addressFavorite = prefs.getString(ProfileKeys.addressFavorite) ?? '';
    _avatarBase64 = prefs.getString(ProfileKeys.avatarBase64);

    if (_authToken == null || _authToken!.isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }

    _clientId = _normalizeClientId(_phone);
    _loaded = true;
    notifyListeners();

    await syncFromServer();
  }

  Future<void> applyAuthSession({
    required String token,
    String? phone,
    String? displayName,
    String? fullName,
  }) async {
    _authToken = token;
    if (phone != null && phone.trim().isNotEmpty) {
      _phone = phone.trim();
      _clientId = _normalizeClientId(_phone);
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      _displayName = displayName.trim();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      _fullName = fullName.trim();
    }
    await _persistLocal();
    notifyListeners();
    await syncFromServer();
  }

  Future<void> syncFromServer() async {
    if (_syncing) return;
    if (_authToken == null || _authToken!.isEmpty) return;
    _syncing = true;
    notifyListeners();
    try {
      final profile = await _api.user.fetchProfile(token: _authToken);
      _clientId = profile.clientId.isNotEmpty ? profile.clientId : _clientId;
      if (profile.fullName != null && profile.fullName!.trim().isNotEmpty) {
        _fullName = profile.fullName!.trim();
      }
      if (profile.phone != null && profile.phone!.trim().isNotEmpty) {
        _phone = profile.phone!.trim();
      }
      _bonusBalance = profile.bonusAvailable;
      _referralCount = profile.referralCount;
      if (profile.referralCode != null && profile.referralCode!.isNotEmpty) {
        _myReferralCode = profile.referralCode!;
      }
      final used = profile.usedReferralCode?.trim();
      _usedReferralCode =
          (used != null && used.isNotEmpty) ? used : _usedReferralCode;
      if (profile.addressHome != null) {
        _addressHome = profile.addressHome!.trim();
      }
      if (profile.addressWork != null) {
        _addressWork = profile.addressWork!.trim();
      }
      if (profile.addressFavorite != null) {
        _addressFavorite = profile.addressFavorite!.trim();
      }
      if (profile.avatarBase64 != null) {
        _avatarBase64 = profile.avatarBase64;
      }
      await _persistLocal();
    } catch (_) {
      // Оставляем локальный кеш при ошибке сети.
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> savePersonalData({
    required String displayName,
    required String fullName,
    String? referralCode,
  }) async {
    final cleanedDisplay = displayName.trim();
    final cleanedFull = fullName.trim();
    _displayName = (cleanedDisplay.isEmpty || cleanedDisplay == '?')
        ? 'Гость'
        : cleanedDisplay;
    _fullName = cleanedFull == '?' ? '' : cleanedFull;
    await _persistLocal();
    notifyListeners();

    final clientId = _clientId ?? _normalizeClientId(_phone);
    if (clientId.isEmpty) return;

    try {
      final updated = await _api.user.updateProfile(
        clientId: clientId,
        fullName: _fullName.isNotEmpty ? _fullName : _displayName,
        phone: _phone,
        referralCode: referralCode,
        token: _authToken,
        avatarBase64: _avatarBase64,
      );
      _bonusBalance = updated.bonusAvailable;
      _referralCount = updated.referralCount;
      if (updated.referralCode != null && updated.referralCode!.isNotEmpty) {
        _myReferralCode = updated.referralCode!;
      }
      final used = updated.usedReferralCode?.trim();
      if (used != null && used.isNotEmpty) _usedReferralCode = used;
      await _persistLocal();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updatePhone(String value) async {
    _phone = value.trim().isEmpty ? _phone : value.trim();
    _clientId = _normalizeClientId(_phone);
    await _persistLocal();
    notifyListeners();
    await syncFromServer();
  }

  void cycleAvatar() {
    _avatarIndex = (_avatarIndex + 1) % avatarColors.length;
    notifyListeners();
  }

  Future<void> pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 82,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    _avatarBase64 = base64Encode(bytes);
    await _persistLocal();
    notifyListeners();

    final clientId = _clientId ?? _normalizeClientId(_phone);
    if (clientId.isEmpty) return;
    try {
      await _api.user.updateProfile(
        clientId: clientId,
        fullName: _fullName.isNotEmpty ? _fullName : _displayName,
        phone: _phone,
        avatarBase64: _avatarBase64,
        token: _authToken,
      );
    } catch (_) {
      // Keep the local avatar if the server is temporarily unavailable.
    }
  }

  Future<void> saveAddresses({
    required String home,
    required String work,
    required String favorite,
  }) async {
    _addressHome = home.trim();
    _addressWork = work.trim();
    _addressFavorite = favorite.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.addressHome, _addressHome);
    await prefs.setString(ProfileKeys.addressWork, _addressWork);
    await prefs.setString(ProfileKeys.addressFavorite, _addressFavorite);
    notifyListeners();
    final clientId = _clientId ?? _normalizeClientId(_phone);
    if (clientId.isEmpty || _authToken == null) return;
    final updated = await _api.user.updateProfile(
      clientId: clientId,
      fullName: _fullName.isNotEmpty ? _fullName : _displayName,
      phone: _phone,
      addressHome: _addressHome,
      addressWork: _addressWork,
      addressFavorite: _addressFavorite,
      token: _authToken,
    );
    _addressHome = updated.addressHome ?? _addressHome;
    _addressWork = updated.addressWork ?? _addressWork;
    _addressFavorite = updated.addressFavorite ?? _addressFavorite;
    await _persistLocal();
    notifyListeners();
  }

  Future<int> activatePromo(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) throw ArgumentError('empty');
    final clientId = _clientId ?? _normalizeClientId(_phone);
    if (clientId.isEmpty) throw StateError('no client');

    final discount = await _api.user.activatePromo(
      clientId: clientId,
      code: trimmed,
      token: _authToken,
    );
    _promoCode = trimmed;
    _promoDiscountPercent = discount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.promoCode, _promoCode);
    await prefs.setInt(ProfileKeys.promoDiscount, _promoDiscountPercent);
    notifyListeners();
    return discount;
  }

  Future<List<Map<String, dynamic>>> loadOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ProfileKeys.orderHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendOrderHistory(Map<String, dynamic> entry) async {
    final items = await loadOrderHistory();
    items.insert(0, entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.orderHistory, jsonEncode(items));
    notifyListeners();
  }

  Future<void> logout() async {
    _displayName = 'Гость';
    _fullName = '';
    _phone = '+7 (___) ___-__-__';
    _avatarIndex = 0;
    _avatarBase64 = null;
    _bonusBalance = 0;
    _referralCount = 0;
    _myReferralCode = '';
    _usedReferralCode = null;
    _clientId = null;
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileKeys.authToken);
    await _persistLocal();
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.displayName, _displayName);
    await prefs.setString(ProfileKeys.fullName, _fullName);
    await prefs.setString(ProfileKeys.phone, _phone);
    if (_avatarBase64 == null || _avatarBase64!.isEmpty) {
      await prefs.remove(ProfileKeys.avatarBase64);
    } else {
      await prefs.setString(ProfileKeys.avatarBase64, _avatarBase64!);
    }
  }

  String _normalizeClientId(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.length == 10) digits = '7$digits';
    return digits;
  }

  String _cleanVisibleName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^\?+$').hasMatch(trimmed)) return '';
    return trimmed;
  }
}
