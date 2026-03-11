class APIException implements Exception {
  final _message;
  final _prefix;

  APIException([this._prefix, this._message]);

  String toString() {
    return "$_prefix-$_message";
  }
}

class FetchDataException extends APIException {
  FetchDataException([message])
      : super(message, "Error During Communication: ");
}

// Build #1.1.187: Added all type of exceptions
class BadRequestException extends APIException {
  BadRequestException([message]) : super(message, "Invalid Request: "); // 400 // No need InvalidInputException
}

class UnauthorisedException extends APIException {
  UnauthorisedException([message]) : super(message, "Unauthorised: "); // 401
}

class PaymentRequiredException extends APIException {
  PaymentRequiredException([message]) : super(message, "Payment Required: "); // 402
}

class ForbiddenException extends APIException {
  ForbiddenException([message]) : super(message, "Forbidden: "); // 403
}

class NotFoundException extends APIException {
  NotFoundException([message]) : super(message, "Resource Not Found: "); // 404
}

class MethodNotAllowedException extends APIException {
  MethodNotAllowedException([message]) : super(message, "Method Not Allowed: "); // 405
}

class NotAcceptableException extends APIException {
  NotAcceptableException([message]) : super(message, "Not Acceptable: "); // 406
}

class RequestTimeoutException extends APIException {
  RequestTimeoutException([message]) : super(message, "Request Timeout: "); // 408
}

class ConflictException extends APIException {
  ConflictException([message]) : super(message, "Conflict: "); // 409
}

class GoneException extends APIException {
  GoneException([message]) : super(message, "Gone: "); // 410
}

class UnsupportedMediaTypeException extends APIException {
  UnsupportedMediaTypeException([message]) : super(message, "Unsupported Media Type: "); // 415
}

class TooManyRequestsException extends APIException {
  TooManyRequestsException([message]) : super(message, "Too Many Requests: "); // 429
}

class InternalServerErrorException extends APIException {
  InternalServerErrorException([message]) : super(message, "Internal Server Error: "); // 500
}

class BadGatewayException extends APIException {
  BadGatewayException([message]) : super(message, "Bad Gateway: "); // 502
}

class ServiceUnavailableException extends APIException {
  ServiceUnavailableException([message]) : super(message, "Service Unavailable: "); // 503
}

class GatewayTimeoutException extends APIException {
  GatewayTimeoutException([message]) : super(message, "Gateway Timeout: "); // 504
}
