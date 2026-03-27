import 'package:flutter/material.dart';

class CustomizeScreen extends StatefulWidget {
  final String orderType; // 👈 add this

  const CustomizeScreen({super.key, required this.orderType});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  int qty = 1;

  List<Map<String, dynamic>> addons = [
    {
      "name": "Chee",
      "price": 20,
      "selected": true,
      "image": "assets/cheese.png" // ✅ ADD THIS
    },
    {
      "name": "Karam Podi",
      "price": 20,
      "selected": false,
      "image": "assets/podi.png" // ✅ ADD THIS
    },
  ];

  late String orderType;

  @override
  void initState() {
    super.initState();
    orderType = widget.orderType; // 👈 get value from home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // 🔶 Top Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white, // ✅ background white
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF9B17)), // optional border
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context); // ✅ go to previous screen
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        // border: Border.all(color: const Color(0xFFFF9B17)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.arrow_back_ios,
                            size: 14,
                            color: Color(0xFFFF9B17),
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Menu",
                            style: TextStyle(
                              color: Color(0xFFFF9B17),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ),

                const Text(
                  "Customize",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    orderType,
                    style: const TextStyle(
                      color: Color(0xFF506796), // ✅ applied here
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Main Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(12), // 🔻 reduced padding
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ IMPORTANT (reduces height)
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔹 HEADER ROW
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(flex: 5, child: Text("Item Name", style: TextStyle(fontSize: 12, color: Colors.grey))),
                        Expanded(flex: 2, child: Text("Qty", style: TextStyle(fontSize: 12, color: Colors.grey))),
                        Expanded(flex: 2, child: Text("Sub Total", style: TextStyle(fontSize: 12, color: Colors.grey))),
                        Expanded(flex: 2, child: Text("Total", style: TextStyle(fontSize: 12, color: Colors.grey))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 🔹 ITEM CARD (SMALL SIZE)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E2CC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // 🔹 Image
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, size: 18),
                        ),

                        const SizedBox(width: 8),

                        // 🔹 Item Name
                        const Expanded(
                          flex: 3,
                          child: Text(
                            "Karam dosa",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),

                        // 🔹 Qty
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.remove, size: 14),
                              ),
                              const SizedBox(width: 6),
                              const Text("1", style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF7A00),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.add, size: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // 🔹 Subtotal
                        const Expanded(
                          flex: 2,
                          child: Text(
                            "90.00",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),

                        // 🔹 Total
                        const Expanded(
                          flex: 2,
                          child: Text(
                            "110.00",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔹 Customize Section
                  const Text(
                    "Customize",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text(
                    "Choose one or more add ons to this item",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Row(
                    children: List.generate(addons.length, (index) {
                      final item = addons[index];
                      final isSelected = item["selected"];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            item["selected"] = !item["selected"];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(10),
                          width: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF7A00) // ✅ orange border
                                  : Colors.grey.shade300,   // ❌ grey border
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  // 🔹 Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      item["image"],
                                      height: 50,
                                      width: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                  // 🔹 Check icon (top-right)
                                  if (isSelected)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF7A00),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // 🔹 Name
                              Text(
                                item["name"],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? const Color(0xFFFF7A00) // ✅ orange text when selected
                                      : Colors.black,
                                ),
                              ),

                              // 🔹 Price
                              Text(
                                "₹${item["price"]}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  )

                ],
              ),
            )
          ),

          // 🔻 Bottom Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),  // ✅ rounded top
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF7A00)),
                      foregroundColor: const Color(0xFFFF7A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ button radius
                      ),
                    ),
                    child: const Text("Clear All"),
                  ),
                ),

                const SizedBox(width: 40),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // ✅ button radius
                      ),
                    ),
                    onPressed: () {},
                    child: const Text("Add to Cart"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}