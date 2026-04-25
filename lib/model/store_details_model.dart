class StoreDetails {
  final String name;
  final String address;
  final String city;
  final String state;
  final String logo;
  final String country;
  final String zipCode;
  final String phoneNumber;

  const StoreDetails({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.logo,
    required this.country,
    required this.zipCode,
    required this.phoneNumber,
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) {
    String s(String? v) => (v ?? '').trim();

    return StoreDetails(
      name: s(json['name'] as String?),
      address: s(json['address'] as String?),
      city: s(json['city'] as String?),
      state: s(json['state'] as String?),
      logo: s(json['logo'] as String?),
      country: s(json['country'] as String?),
      zipCode: s(json['zip_code'] as String?),
      phoneNumber: s(json['phone_number'] as String?),
    );
  }

  // ✅ ADD THIS
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'logo': logo,
      'country': country,
      'zip_code': zipCode,
      'phone_number': phoneNumber,
    };
  }

  String get cityLine {
    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (zipCode.isNotEmpty) parts.add(zipCode);
    return parts.join(', ');
  }
}