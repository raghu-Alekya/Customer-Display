// Asset Model
import 'package:flutter/foundation.dart';

class AssetResponse {
  final String baseUrl;
  final List<Media> media;
  final List<Tax> taxes;
  final List<Coupon> coupons;
  final List<OrderStatus> orderStatuses;
  final String currency;
  final String currencySymbol;
  final List<Role> roles;
  final SubscriptionPlan subscriptionPlans;
  final StoreDetails storeDetails;
  final List<Denom> notesDenom; // Build #1.0.69 : updated assets table based on api response
  final List<Denom> coinDenom;
  final List<Denom> safeDenom;
  final List<Denom> tubesDenom;
  final String maxTubesCount;
  final String safeDropAmount;
  final String drawerAmount;
  final List<Vendor> vendors;  //Build #1.0.74
  final List<String> vendorPaymentTypes;
  final List<String> vendorPaymentPurpose;
  final List<Employees> employees;
  final List<OrderType> orderTypes;

  AssetResponse({
    required this.baseUrl,
    required this.media,
    required this.taxes,
    required this.coupons,
    required this.orderStatuses,
    required this.currency,
    required this.currencySymbol,
    required this.roles,
    required this.subscriptionPlans,
    required this.storeDetails,
    required this.notesDenom,
    required this.coinDenom,
    required this.safeDenom,
    required this.tubesDenom,
    required this.maxTubesCount,
    required this.safeDropAmount,
    required this.drawerAmount,
    required this.vendors,
    required this.vendorPaymentTypes,
    required this.vendorPaymentPurpose,
    required this.employees,
    required this.orderTypes,
  });

  factory AssetResponse.fromJson(Map<String, dynamic> json) {
    return AssetResponse(
      baseUrl: json['base_url']?.toString() ?? '',
      media: (json['media'] as List<dynamic>?)
          ?.map((item) => Media.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      taxes: (json['taxes'] as List<dynamic>?)
          ?.map((item) => Tax.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      coupons: (json['coupons'] as List<dynamic>?)
          ?.map((item) => Coupon.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      orderStatuses: (json['order_statuses'] as List<dynamic>?)
          ?.map((item) => OrderStatus.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      currency: json['currency']?.toString() ?? '',
      currencySymbol: json['currency_symbol']?.toString() ?? '',
      roles: (json['roles'] as List<dynamic>?)
          ?.map((item) => Role.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      subscriptionPlans: SubscriptionPlan.fromJson(
          json['subscription_plans'] as Map<String, dynamic>? ?? {}),
      storeDetails: StoreDetails.fromJson(
          json['store_details'] as Map<String, dynamic>? ?? {}),
      notesDenom: (json['notes_denom'] as List<dynamic>?)
          ?.map((item) => Denom.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      coinDenom: (json['coin_denom'] as List<dynamic>?)
          ?.map((item) => Denom.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      safeDenom: (json['safe_denom'] as List<dynamic>?)
          ?.map((item) => Denom.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      tubesDenom: (json['tubes_denom'] as List<dynamic>?)
          ?.map((item) => Denom.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      maxTubesCount: json['max_tubes_count']?.toString() ?? '',
      safeDropAmount: json['safe_drop_amount']?.toString() ?? '',
      drawerAmount: json['drawer_amount']?.toString() ?? '',
      vendors: (json['vendors'] as List<dynamic>?)
          ?.map((item) => Vendor.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      vendorPaymentTypes: (json['vendor_payment_types'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList() ??
          [],
      vendorPaymentPurpose: (json['vendor_payment_purpose'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList() ??
          [],
      employees: (json['employees'] as List<dynamic>?)
          ?.map((item) => Employees.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      orderTypes: (json['order_types'] as List<dynamic>?)
          ?.map((item) => OrderType.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}
class Media {
  final int id;
  final String title;
  final String url;

  Media({required this.id, required this.title, required this.url});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  // Add this to convert DB rows to Media
  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      url: map['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
    };
  }
}
// class Media {
//   final int id;
//   final String title;
//   final String url;
//
//   Media({required this.id, required this.title, required this.url});
//
//   factory Media.fromJson(Map<String, dynamic> json) {
//     return Media(
//       id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
//       title: json['title']?.toString() ?? '',
//       url: json['url']?.toString() ?? '',
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'title': title,
//       'url': url,
//     };
//   }
// }

class Tax {  //Build #1.0.68: updated
  final String slug;
  final String name;

  Tax({
    required this.slug,
    required this.name,
  });

  factory Tax.fromJson(Map<String, dynamic> json) {
    return Tax(
      slug: json['slug']?.toString() ?? 'tax-${json['name']?.toString().toLowerCase().replaceAll(' ', '-') ?? 'unknown'}',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
    };
  }
}

class Coupon {
  final int id;
  final String code;
  final String amount;
  final String discountType;
  final String usageLimit;
  final String expiryDate;

  Coupon({
    required this.id,
    required this.code,
    required this.amount,
    required this.discountType,
    required this.usageLimit,
    required this.expiryDate,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: json['code']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? '',
      usageLimit: json['usage_limit']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'amount': amount,
      'discount_type': discountType,
      'usage_limit': usageLimit,
      'expiry_date': expiryDate,
    };
  }
}

class OrderStatus {
  final String slug;
  final String name;

  OrderStatus({required this.slug, required this.name});

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    return OrderStatus(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
    };
  }
}

class Role {
  final String slug;
  final String name;

  Role({required this.slug, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
    };
  }
}

class SubscriptionPlan {
  final String type;
  final String key;
  final String expiration;
  final String origin;
  final String storeId; // Changed from bool to String

  SubscriptionPlan({
    required this.type,
    required this.key,
    required this.expiration,
    required this.origin,
    required this.storeId,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      type: json['type']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      expiration: json['expiration']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      storeId: json['store_id']?.toString() ?? '', // Changed to String
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'key': key,
      'expiration': expiration,
      'origin': origin,
      'store_id': storeId, // Updated to handle String
    };
  }
}

class StoreDetails {
  final String name;
  final String address;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final String? phoneNumber; // Changed to String? to handle potential phone numbers or null

  StoreDetails({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    this.phoneNumber, // Nullable to handle missing or varied data
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) {
    String? phoneNumber = json['phone_number']?.toString();
    if (json['phone_number'] is bool) { // Build #1.0.70 - fixed null issue
      if (kDebugMode) {
        print("#### Warning: phone_number is a boolean in API response, defaulting to '0'");
      }
      phoneNumber = '0'; // Provide a default value
    }
    return StoreDetails(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      zipCode: json['zip_code']?.toString() ?? '',
      phoneNumber: phoneNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'zip_code': zipCode,
      'phone_number': phoneNumber ?? '0', // Provide a default value if phoneNumber is null
    };
  }
}

class Denom { // Build #1.0.69 : updated assets table based on api response
  final String denom;
  final String? image;
  final int? tubeLimit;
  final String? symbol;

  Denom({
    required this.denom,
    this.image,
    this.tubeLimit,
    this.symbol,
  });

  factory Denom.fromJson(Map<String, dynamic> json) {
    return Denom(
      denom: json['denom']?.toString() ?? '', // Ensures numbers are converted to strings
      image: json['image']?.toString(),
      tubeLimit: int.tryParse(json['tube_limit']?.toString() ?? ''),
      symbol: json['symbol']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'denom': denom,
      'image': image,
      'tube_limit': tubeLimit,
      'symbol': symbol,
    };
  }
}
//Build #1.0.74 : updated with new response
class Vendor{
  final int id;
  final String vendorName;

  Vendor({required this.id, required this.vendorName});

  factory Vendor.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) print("Vendor.fromJson: Parsing vendor JSON: $json");
    final idValue = json['id'] ?? json['vendor_id'];
    final parsedId = int.tryParse(idValue?.toString() ?? '');
    if (parsedId == null || parsedId == 0) {
      if (kDebugMode) print("Vendor.fromJson: Invalid or missing vendor ID, received: $idValue");
    }
    return Vendor(
      id: parsedId ?? 0,
      vendorName: json['vendor_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': id,
      'vendor_name': vendorName,
    };
  }
}

//Build #1.0.80 : updated with Employees response
class Employees{
  final String? iD;
  final String? userLogin;
  final String? userPass;
  final String? userNicename;
  final String? userEmail;
  final String? userUrl;
  final String? userRegistered;
  final String? userActivationKey;
  final String? userStatus;
  final String? displayName;

  Employees(
    {this.iD,
    this.userLogin,
    this.userPass,
    this.userNicename,
    this.userEmail,
    this.userUrl,
    this.userRegistered,
    this.userActivationKey,
    this.userStatus,
    this.displayName});

  factory Employees.fromJson(Map<String, dynamic> json) {
    return Employees(
      iD : json['ID'],
      userLogin : json['user_login'],
      userPass : json['user_pass'],
      userNicename : json['user_nicename'],
      userEmail : json['user_email'],
      userUrl:  json['user_url'],
      userRegistered : json['user_registered'],
      userActivationKey : json['user_activation_key'],
      userStatus : json['user_status'],
      displayName : json['display_name']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['ID'] = this.iD;
    data['user_login'] = this.userLogin;
    data['user_pass'] = this.userPass;
    data['user_nicename'] = this.userNicename;
    data['user_email'] = this.userEmail;
    data['user_url'] = this.userUrl;
    data['user_registered'] = this.userRegistered;
    data['user_activation_key'] = this.userActivationKey;
    data['user_status'] = this.userStatus;
    data['display_name'] = this.displayName;
    return data;
  }
}

class OrderType {
  final String slug;
  final String name;

  OrderType({required this.slug, required this.name});

  factory OrderType.fromJson(Map<String, dynamic> json) {
    return OrderType(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'name': name,
    };
  }
}

// Build #1.0.163: Added Image assets api response model
class ImageAssetsResponse {
  final List<Media> media;

  ImageAssetsResponse({required this.media});

  factory ImageAssetsResponse.fromJson(Map<String, dynamic> json) {
    return ImageAssetsResponse(
      media: (json['media'] as List<dynamic>?)
          ?.map((item) => Media.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}