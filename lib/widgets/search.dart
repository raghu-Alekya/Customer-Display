import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product_bloc.dart';
import '../customize_screen.dart';
// import 'bloc/product_bloc.dart';
// import 'model/product model.dart';

class SearchScreen extends StatefulWidget {
  final String query;

  const SearchScreen({super.key, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController controller = TextEditingController();
  Timer? debounce;

  @override
  void initState() {
    super.initState();

    controller.text = widget.query;

    /// 🔥 If coming with pre-filled query
    if (widget.query.isNotEmpty && widget.query.length >= 2) {
      context.read<ProductBloc>().add(SearchProducts(widget.query));
    }
  }

  void _onSearchChanged(String value) {
    debounce?.cancel();

    final query = value.trim();

    // clear old results immediately
    if (query.isNotEmpty && query.length < 2) {
      context.read<ProductBloc>().add(ClearProducts());
      return;
    }

    if (query.isEmpty) {
      context.read<ProductBloc>().add(ClearProducts());
      return;
    }

    debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      context.read<ProductBloc>().add(SearchProducts(query));
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            /// 🔶 TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                children: [
                  /// 🔙 BACK BUTTON
                  InkWell(
                    onTap: () {
                      context.read<ProductBloc>().add(const ResetProducts());
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 100, // Increase width
                      height: 50, // Increase height
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_back_ios,
                            size: 18, // Larger icon
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Back",
                            style: TextStyle(
                              fontSize: 16, // Larger text
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// 🔍 SEARCH BAR
                  Expanded(
                    child: Container(
                        width: 50,

                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child:Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),

                          Expanded(
                            child: TextField(
                              controller: controller,
                              autofocus: true,
                              onChanged: (value) {
                                setState(() {});
                                _onSearchChanged(value);
                              },
                              decoration: const InputDecoration(
                                hintText: "Search for items here",
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),

                          /// 🔥 CLEAR BUTTON
                          if (controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                controller.clear();
                                context.read<ProductBloc>().add(ClearProducts());
                                setState(() {});
                              },
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      )
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🔥 RESULT / EMPTY STATE
            Expanded(
              child: BlocBuilder<ProductBloc, ProductState>(
                builder: (context, state) {
                  final query = controller.text.trim();

                  /// 🔹 EMPTY STATE
                  if (query.isEmpty) {
                    return _emptyState();
                  }

                  /// 🔹 LOADING
                  if (state is ProductLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  /// 🔹 RESULTS
                  if (state is ProductLoaded) {
                    if (state.products.isEmpty) {
                      return const Center(child: Text("No results found"));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: state.products.length,
                      itemBuilder: (_, index) {
                        final item = state.products[index];

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>CustomizeScreen(
                                  product: item,
                                  addons: const [],
                                  orderType: "Dine-In",
                                  openedFromSearch: true,
                                )
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                /// IMAGE
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                      ? Image.network(
                                    item.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                      : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.fastfood),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// TEXT
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "\$${item.price.toString().replaceAll('₹', '').trim()}",
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 EMPTY STATE UI
  Widget _emptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("assets/search.png", height: 180),
        const SizedBox(height: 20),

        const Text(
          "Search from our curated menu of dishes\nand combos",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}