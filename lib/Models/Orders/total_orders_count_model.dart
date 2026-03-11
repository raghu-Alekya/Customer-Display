import 'get_orders_model.dart'; // Alias to avoid name conflicts

class TotalOrdersResponseModel { // Build #1.0.118: Updated this class from orders_screen
  final int orderTotalCount;
  ///Build #1.0.134: Updated ordersData same as getOrders api orderModel
  /// here changed ordersList to orderModel
  final List<OrderModel> ordersData;

  TotalOrdersResponseModel({
    required this.orderTotalCount,
    required this.ordersData,
  });

  factory TotalOrdersResponseModel.fromJson(Map<String, dynamic> json) {
    return TotalOrdersResponseModel(
      orderTotalCount: json['order_total_count'] ?? 0,
      ordersData: (json['orders_data'] as List<dynamic>?)
          ?.map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

}
