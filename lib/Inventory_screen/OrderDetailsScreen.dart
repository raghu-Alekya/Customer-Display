import 'package:flutter/material.dart';

import '../Models/Orders/get_orders_model.dart';
import '../Models/Orders/orders_model.dart';
import '../Repositories/Orders/order_repository.dart';
import 'dart:convert';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;
  final UpdateOrderRequestModel request;

  const OrderDetailsScreen({super.key, required this.orderId, required this.request});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Future<OrderModel> _orderFuture;
  String? rawApiResponse; // Store raw response as string

  @override
  void initState() {
    super.initState();
    _orderFuture = fetchUpdatedOrder();
  }

  Future<OrderModel> fetchUpdatedOrder() async {
    try {
      final orderRepository = OrderRepository();
      final order = await orderRepository.updateOrderProducts(
        orderId: widget.orderId,
        request: widget.request,
      );

      // Print full order data
      debugPrint("Full API Response (OrderModel): $order");

      // Optional: store raw JSON string for display
      rawApiResponse = order.toString(); // If you want JSON, you need to manually convert fields

      return order;
    } catch (e) {
      debugPrint("Error fetching order: $e");
      rethrow;
    }
  }

  Widget _buildOrderDetails(OrderModel order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Raw API Response:", style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(rawApiResponse ?? "No raw data"),
        const Divider(height: 32, thickness: 2),

        Row(
          children: [
            const Text("Order ID: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(order.id.toString()),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(order.status),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text("Total Items: ", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(order.lineItems.length.toString()),
          ],
        ),
        const SizedBox(height: 16),
        const Text("Line Items:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

        // Display full line item details
        ...order.lineItems.map((item) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Product ID: ${item.productData.id}"),
                  Text("Name: ${item.productData.name}"),
                  Text("Price: ${item.productData.price}"),
                  Text("Quantity: ${item.quantity}"),
                  Text("regularPrice: ${item.productData.regularPrice}"),
                  Text("salePrice: ${item.productData.salePrice ?? 'N/A'}"),
                  // Add more fields if your productData has more info
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
      ),
      body: FutureBuilder<OrderModel>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          } else if (snapshot.hasData) {
            return _buildOrderDetails(snapshot.data!);
          } else {
            return const Center(child: Text("No data found"));
          }
        },
      ),
    );
  }
}
