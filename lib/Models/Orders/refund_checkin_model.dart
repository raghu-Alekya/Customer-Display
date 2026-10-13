class RefundUser {
  final int id;
  final String name;
  final String role;

  RefundUser({
    required this.id,
    required this.name,
    required this.role,
  });

  factory RefundUser.fromJson(Map<String, dynamic> json) {
    return RefundUser(
      id: json['id'],
      name: json['name'],
      role: json['role'],
    );
  }
}