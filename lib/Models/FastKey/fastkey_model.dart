import 'fastkey_product_model.dart';

<<<<<<< HEAD
// //Using for Fast Key Screen Horizontal List Scroll
// class FastKeyModel { // Build #1.0.19: No need
//   late int id; // Build #1.0.11
//   late String name; //Build #1.0.4
//   late String itemCount;
//   late String imageAsset;
//
//   FastKeyModel({
//     required this.id,
//     required this.name,
//     required this.itemCount,
//     required this.imageAsset,
//   });
// }

/// ==============================================
/// 1. FAST KEY CREATION AND LISTING MODELS
/// ==============================================

/// API: POST /fastkeys/create
/// Creates a new FastKey
=======
>>>>>>> origin/Grocery_pch_api_integration
class FastKeyRequest {  // Build #1.0.15
  final String fastkeyTitle;
  final int fastkeyIndex;
  final String fastkeyImage;
  final int? userId;
<<<<<<< HEAD
  final int? fastkeyServerId;
=======
  final dynamic fastkeyServerId;
>>>>>>> origin/Grocery_pch_api_integration

  FastKeyRequest({
    required this.fastkeyTitle,
    required this.fastkeyIndex,
    required this.fastkeyImage,
    this.userId,
    this.fastkeyServerId, // Build #1.0.89: added for update fast key api
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'fastkey_title': fastkeyTitle,
      'fastkey_index': fastkeyIndex,
      'fastkey_image': fastkeyImage,
    };
    if (userId != null) {
      data['user_id'] = userId;
    }
    if (fastkeyServerId != null) {
      data['fastkey_id'] = fastkeyServerId;
    }
    return data;
  }
}

/// API RESPONSE: POST /fastkeys/create
/// Response when creating a FastKey
class FastKeyResponse {
  final String status;
  final String message;
<<<<<<< HEAD
  final int fastkeyId;
=======
  final dynamic fastkeyId;
>>>>>>> origin/Grocery_pch_api_integration
  final String fastkeyTitle;
  final String fastkeyIndex;
  final String fastkeyImage;

  FastKeyResponse({
    required this.status,
    required this.message,
    required this.fastkeyId,
    required this.fastkeyTitle,
    required this.fastkeyIndex,
    required this.fastkeyImage,
  });

  factory FastKeyResponse.fromJson(Map<String, dynamic> json) {
<<<<<<< HEAD
    return FastKeyResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      fastkeyId: json['fastkey_id'] ?? 0,
      fastkeyTitle: json['fastkey_title'] ?? '',
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      fastkeyImage: json['fastkey_image'] ?? '',
=======
    var rawId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    return FastKeyResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      fastkeyId: rawId?.toString() ?? '',
      fastkeyTitle: json['fastkey_title']?.toString() ?? '',
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      fastkeyImage: json['fastkey_image']?.toString() ?? '',
>>>>>>> origin/Grocery_pch_api_integration
    );
  }
}

/// API RESPONSE: GET /fastkeys/get-by-user
/// Response for listing all FastKeys for a user
class FastKeyListResponse {
  final String status;
  final String message;
  final int userId;
  final List<FastKey> fastkeys;

  FastKeyListResponse({
    required this.status,
    required this.message,
    required this.userId,
    required this.fastkeys,
  });

  factory FastKeyListResponse.fromJson(Map<String, dynamic> json) {
<<<<<<< HEAD
    return FastKeyListResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      userId: json['user_id'] ?? 0,
      fastkeys: (json['fastkeys'] as List<dynamic>?)
          ?.map((item) => FastKey.fromJson(item))
=======
    List<dynamic>? rawList;
    if (json['fastkeys'] is List) {
      rawList = json['fastkeys'] as List<dynamic>;
    } else if (json['data'] is List) {
      rawList = json['data'] as List<dynamic>;
    } else if (json['data'] is Map && json['data']['fastkeys'] is List) {
      rawList = json['data']['fastkeys'] as List<dynamic>;
    }

    return FastKeyListResponse(
      status: json['status']?.toString() ?? (json['success'] == true ? 'success' : ''),
      message: json['message']?.toString() ?? '',
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      fastkeys: rawList
          ?.map((item) => FastKey.fromJson(item as Map<String, dynamic>))
>>>>>>> origin/Grocery_pch_api_integration
          .toList() ??
          [],
    );
  }
}

/// Shared model for FastKey representation
/// Used in both creation and listing responses
class FastKey {
<<<<<<< HEAD
  final int fastkeyServerId; // Build #1.0.19: Updated fastkeyId to fastkeyServerId for better understanding
=======
  final dynamic fastkeyServerId; // Build #1.0.19: Updated fastkeyId to fastkeyServerId for better understanding
>>>>>>> origin/Grocery_pch_api_integration
  final int userId;
  final String fastkeyTitle;
  final dynamic fastkeyImage; // Can be bool or String
  final String fastkeyIndex;
  final int itemCount;
  final List<FastKeyProduct>? products; // Build #1.0.197: updated for Fixed [SCRUM - 328] -> At first logon Empty items shows in fast keys for the selected folder

  FastKey({
    required this.fastkeyServerId,
    required this.userId,
    required this.fastkeyTitle,
    required this.fastkeyImage,
    required this.fastkeyIndex,
    required this.itemCount,
    this.products
  });

  factory FastKey.fromJson(Map<String, dynamic> json) {
<<<<<<< HEAD
    return FastKey(
      fastkeyServerId: json['fastkey_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      fastkeyTitle: json['fastkey_title'] ?? '',
      fastkeyImage: json['fastkey_image'],
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      itemCount: json['itemCount'] ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item))
=======
    var rawServerId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    var rawUserId = json['user_id'] ?? json['userId'];

    return FastKey(
      fastkeyServerId: rawServerId?.toString() ?? '',
      userId: rawUserId is int ? rawUserId : (int.tryParse(rawUserId?.toString() ?? '') ?? 0),
      fastkeyTitle: json['fastkey_title']?.toString() ?? json['title']?.toString() ?? json['name']?.toString() ?? '',
      fastkeyImage: json['fastkey_image'] ?? json['image'],
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      itemCount: json['itemCount'] is int ? json['itemCount'] as int : (int.tryParse(json['itemCount']?.toString() ?? '') ?? 0),
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item as Map<String, dynamic>))
>>>>>>> origin/Grocery_pch_api_integration
          .toList() ?? [],
    );
  }

  FastKey copyWith({
<<<<<<< HEAD
    int? fastkeyServerId,
=======
    dynamic fastkeyServerId,
>>>>>>> origin/Grocery_pch_api_integration
    int? userId,
    String? fastkeyTitle,
    dynamic fastkeyImage,
    String? fastkeyIndex,
    int? itemCount,
    List<FastKeyProduct>? products
  }) {
    return FastKey(
      fastkeyServerId: fastkeyServerId ?? this.fastkeyServerId,
      userId: userId ?? this.userId,
      fastkeyTitle: fastkeyTitle ?? this.fastkeyTitle,
      fastkeyImage: fastkeyImage ?? this.fastkeyImage,
      fastkeyIndex: fastkeyIndex ?? this.fastkeyIndex,
      itemCount: itemCount ?? this.itemCount,
      products: products ?? this.products,
    );
  }
}