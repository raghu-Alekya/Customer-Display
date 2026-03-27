class UserLoginResponse {
  final bool success;
  final int statusCode;
  final String message;
  final UserData data;

  UserLoginResponse({
    required this.success,
    required this.statusCode,
    required this.message,
    required this.data,
  });

  factory UserLoginResponse.fromJson(Map<String, dynamic> json) {
    return UserLoginResponse(
      success: json['success'],
      statusCode: json['statusCode'],
      message: json['message'],
      data: UserData.fromJson(json['data']),
    );
  }
}

class UserData {
  final String token;
  final int id;
  final String email;
  final String name;
  final String role;
  final String avatar;

  UserData({
    required this.token,
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.avatar,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      token: json['token'],
      id: json['id'],
      email: json['email'],
      name: json['displayName'],
      role: json['role'],
      avatar: json['avatar'],
    );
  }
}