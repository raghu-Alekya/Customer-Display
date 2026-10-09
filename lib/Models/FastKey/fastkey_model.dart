import 'fastkey_product_model.dart';

class FastKeyRequest {  // Build #1.0.15
  final String fastkeyTitle;
  final int fastkeyIndex;
  final String fastkeyImage;
  final int? userId;
  final int? fastkeyServerId;

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
  final dynamic fastkeyId;
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
    var rawId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    return FastKeyResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      fastkeyId: rawId ?? 0,
      fastkeyTitle: json['fastkey_title']?.toString() ?? '',
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      fastkeyImage: json['fastkey_image']?.toString() ?? '',
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
              .toList() ??
          [],
    );
  }
}

/// Shared model for FastKey representation
/// Used in both creation and listing responses
class FastKey {
  final int fastkeyServerId; // Build #1.0.19: Updated fastkeyId to fastkeyServerId for better understanding
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
    var rawServerId = json['fastkey_id'] ?? json['fastkeyId'] ?? json['id'];
    var rawUserId = json['user_id'] ?? json['userId'];

    return FastKey(
      fastkeyServerId: rawServerId is int ? rawServerId : (int.tryParse(rawServerId?.toString() ?? '') ?? 0),
      userId: rawUserId is int ? rawUserId : (int.tryParse(rawUserId?.toString() ?? '') ?? 0),
      fastkeyTitle: json['fastkey_title']?.toString() ?? json['title']?.toString() ?? json['name']?.toString() ?? '',
      fastkeyImage: json['fastkey_image'] ?? json['image'],
      fastkeyIndex: json['fastkey_index']?.toString() ?? '0',
      itemCount: json['itemCount'] is int ? json['itemCount'] as int : (int.tryParse(json['itemCount']?.toString() ?? '') ?? 0),
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => FastKeyProduct.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  FastKey copyWith({
    int? fastkeyServerId,
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