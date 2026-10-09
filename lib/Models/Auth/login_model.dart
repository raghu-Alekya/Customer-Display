class LoginResponse {
  bool? success;
  int? statusCode;
  String? code;
  String? message;
  String? token;
  dynamic id;
  String? email;
  String? nicename;
  String? firstName;
  String? lastName;
  String? displayName;
  String? role; //Build #1.0.122: Updated
  String? avatar;
  int? shiftId; // Build #1.0.149: Added shift_id from API response
  String? safeEnable;
  String? safeEnableDrop;
  // Build #offline: Terminal identity from login API
  String? deviceDisplayName;
  String? tableId;

  LoginResponse({
    this.success,
    this.statusCode,
    this.code,
    this.message,
    this.token,
    this.id,
    this.email,
    this.nicename,
    this.firstName,
    this.lastName,
    this.displayName,
    this.role,
    this.avatar,
    this.shiftId,
    this.safeEnable,
    this.safeEnableDrop,
    this.deviceDisplayName,
    this.tableId,
  });

  LoginResponse.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> dataMap = {};
    if (json['data'] is Map<String, dynamic>) {
      dataMap = json['data'] as Map<String, dynamic>;
    } else {
      dataMap = json;
    }

    token = json['accessToken']?.toString() ??
        json['token']?.toString() ??
        dataMap['token']?.toString() ??
        dataMap['accessToken']?.toString();

    statusCode = json['statusCode'] is int
        ? json['statusCode'] as int
        : int.tryParse(json['statusCode']?.toString() ?? '');
    code = json['code']?.toString();
    message = json['message']?.toString();

    if (json.containsKey('success') && json['success'] is bool) {
      success = json['success'] as bool;
    } else {
      success = token != null && token!.isNotEmpty;
    }

    Map<String, dynamic> userMap = {};
    if (json['employee'] is Map<String, dynamic>) {
      userMap = json['employee'] as Map<String, dynamic>;
    } else if (json['user'] is Map<String, dynamic>) {
      userMap = json['user'] as Map<String, dynamic>;
    } else {
      userMap = dataMap;
    }

    var rawId = userMap['id'] ?? dataMap['id'] ?? userMap['userId'] ?? dataMap['userId'];
    if (rawId != null) {
      id = int.tryParse(rawId.toString()) ?? rawId;
    } else {
      id = null;
    }

    nicename = userMap['nicename']?.toString() ??
        userMap['employeeCode']?.toString() ??
        userMap['employee_code']?.toString() ??
        dataMap['nicename']?.toString();

    final rawEmail = userMap['email']?.toString() ?? dataMap['email']?.toString();
    if (rawEmail != null && rawEmail.trim().isNotEmpty) {
      email = rawEmail.trim();
    } else if (nicename != null && nicename!.trim().isNotEmpty) {
      email = '${nicename!.trim()}@pos.local';
    } else if (id != null) {
      email = '$id@pos.local';
    } else {
      email = 'cashier@pos.local';
    }

    firstName = userMap['firstName']?.toString() ??
        userMap['first_name']?.toString() ??
        dataMap['firstName']?.toString();
    lastName = userMap['lastName']?.toString() ??
        userMap['last_name']?.toString() ??
        dataMap['lastName']?.toString();

    final fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();

    displayName = userMap['displayName']?.toString() ??
        userMap['display_name']?.toString() ??
        dataMap['displayName']?.toString() ??
        (fullName.isNotEmpty ? fullName : null) ??
        userMap['name']?.toString() ??
        dataMap['name']?.toString();

    if (json['role'] is Map<String, dynamic>) {
      final roleMap = json['role'] as Map<String, dynamic>;
      role = roleMap['code']?.toString() ??
          roleMap['name']?.toString() ??
          roleMap['id']?.toString();
    } else if (dataMap['role'] is Map<String, dynamic>) {
      final roleMap = dataMap['role'] as Map<String, dynamic>;
      role = roleMap['code']?.toString() ??
          roleMap['name']?.toString() ??
          roleMap['id']?.toString();
    } else {
      role = userMap['role']?.toString() ?? dataMap['role']?.toString();
    }

    avatar = userMap['avatar']?.toString() ?? dataMap['avatar']?.toString();

    var rawShiftId = dataMap['shift_id'] ?? dataMap['shiftId'] ?? userMap['shift_id'];
    shiftId = rawShiftId is int ? rawShiftId : int.tryParse(rawShiftId?.toString() ?? '');

    safeEnable = dataMap['safe_enable']?.toString() ?? dataMap['safeEnable']?.toString();
    safeEnableDrop = dataMap['safe_enable_drop']?.toString() ?? dataMap['safeEnableDrop']?.toString();

    if (json['device'] is Map<String, dynamic>) {
      final devMap = json['device'] as Map<String, dynamic>;
      deviceDisplayName = devMap['name']?.toString() ??
          devMap['registerId']?.toString() ??
          devMap['id']?.toString();
    } else {
      deviceDisplayName = dataMap['device_display_name']?.toString() ??
          dataMap['deviceDisplayName']?.toString();
    }

    tableId = dataMap['table_id']?.toString() ?? dataMap['tableId']?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'statusCode': statusCode,
      'code': code,
      'message': message,
      'accessToken': token,
      'data': {
        'token': token,
        'id': id,
        'email': email,
        'nicename': nicename,
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'role': role,
        'avatar': avatar,
        'shift_id': shiftId,
        'safe_enable': safeEnable,
        'safe_enable_drop': safeEnableDrop,
        'device_display_name': deviceDisplayName,
        'table_id': tableId,
      }
    };
  }
}

class LoginRequest {
  String _empLoginPin;

  set empLoginPin(String value) {
    _empLoginPin = value;
  }

  LoginRequest(this._empLoginPin);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['emp_login_pin'] = _empLoginPin;
    return data;
  }
}
