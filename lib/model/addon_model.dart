class AddonModel {
  final int id;
  final String name;
  final double price;
  final String type;
  bool isSelected;

  AddonModel({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    this.isSelected = false,
  });

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    return AddonModel(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      type: json['type'],
    );
  }
}