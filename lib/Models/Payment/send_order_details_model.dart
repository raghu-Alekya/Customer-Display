// Build #1.0.159 : Added Model for sending order details request
class SendOrderDetailsRequestModel {
  final String email;
  final bool forceEmailUpdate;

  SendOrderDetailsRequestModel({
    required this.email,
    this.forceEmailUpdate = true, // PostMan API Comment -> hardcode to true
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'force_email_update': forceEmailUpdate,
  };
}

// Model for send order details response
class SendOrderDetailsResponseModel {
  final String message;

  SendOrderDetailsResponseModel({required this.message});

  factory SendOrderDetailsResponseModel.fromJson(Map<String, dynamic> json) =>
      SendOrderDetailsResponseModel(
        message: json['message'] ?? '',
      );
}