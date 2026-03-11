// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:image/image.dart' as img;
//
// import 'add_product_inventory_bloc/add_product_inventory_bloc.dart';
// import 'add_product_inventory_entity.dart';
// import 'add_product_inventory_bloc/add_product_inventory_state.dart';
// import 'add_product_inventory_bloc/add_product_inventory_event.dart';
// import 'add_product_inventory_get_usecase.dart';
// import 'add_product_inventory_remote_data_source.dart';
// import 'add_product_inventory_repository_impl.dart';
//
// class AddProductInventoryTaxScreen extends StatefulWidget {
//   final AddProductInventoryTaxBloc? bloc;
//   final AddProductInventoryTaxGetUseCase? useCase;
//
//   const AddProductInventoryTaxScreen({super.key, this.bloc, this.useCase});
//
//   @override
//   State<AddProductInventoryTaxScreen> createState() =>
//       _AddProductInventoryTaxScreenState();
// }
//
// class _AddProductInventoryTaxScreenState
//     extends State<AddProductInventoryTaxScreen> {
//   late final AddProductInventoryTaxBloc bloc;
//   final _formKey = GlobalKey<FormState>();
//
//   // Controllers
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController skuController = TextEditingController();
//   final TextEditingController regularPriceController = TextEditingController();
//   final TextEditingController salePriceController = TextEditingController();
//   final TextEditingController categoryIdController = TextEditingController();
//   final TextEditingController tagNameController = TextEditingController();
//   final TextEditingController tagSlugController = TextEditingController();
//   final TextEditingController stockQuantityController = TextEditingController();
//   final TextEditingController taxClassController = TextEditingController();
//
//   // Image picker
//   final ImagePicker _picker = ImagePicker();
//   XFile? _pickedImage;
//   String? _base64Image;
//
//   @override
//   void initState() {
//     super.initState();
//
//     if (widget.bloc != null) {
//       bloc = widget.bloc!;
//     } else if (widget.useCase != null) {
//       bloc = AddProductInventoryTaxBloc(addProductUseCase: widget.useCase!);
//     } else {
//       final remoteDataSource = AddProductInventoryTaxRemoteDataSource();
//       final repository =
//       AddProductInventoryTaxRepositoryImpl(remoteDataSource: remoteDataSource);
//       final useCase = AddProductInventoryTaxGetUseCase(repository: repository);
//       bloc = AddProductInventoryTaxBloc(addProductUseCase: useCase);
//     }
//   }
//
//   @override
//   void dispose() {
//     nameController.dispose();
//     skuController.dispose();
//     regularPriceController.dispose();
//     salePriceController.dispose();
//     categoryIdController.dispose();
//     tagNameController.dispose();
//     tagSlugController.dispose();
//     stockQuantityController.dispose();
//     taxClassController.dispose();
//
//     if (widget.bloc == null) {
//       bloc.close();
//     }
//
//     super.dispose();
//   }
//
//
//   Future<void> _pickImage() async {
//     final XFile? image = await _picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 85, // helps JPGs
//     );
//
//     if (image == null) return;
//
//     final bytes = await image.readAsBytes();
//     final extension = image.path.split('.').last.toLowerCase();
//
//     // Decode image
//     img.Image? decoded = img.decodeImage(bytes);
//     if (decoded == null) return;
//
//     // Resize (important)
//     final resized = img.copyResize(
//       decoded,
//       width: 800, // ideal for product images
//     );
//
//     late List<int> compressedBytes;
//     late String mimeType;
//
//     if (extension == 'png') {
//       compressedBytes = img.encodePng(resized, level: 6);
//       mimeType = 'image/png';
//     } else {
//       compressedBytes = img.encodeJpg(resized, quality: 80);
//       mimeType = 'image/jpeg';
//     }
//
//     setState(() {
//       _pickedImage = image;
//       _base64Image =
//       'data:$mimeType;base64,${base64Encode(compressedBytes)}';
//     });
//   }
//
//   void _submitProduct() {
//     if (_formKey.currentState!.validate()) {
//       if (_base64Image == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Please pick an image')),
//         );
//         return;
//       }
//
//       final product = AddProductInventoryTaxEntity(
//         id: 0,
//         name: nameController.text,
//         type: 'simple',
//         sku: skuController.text,
//         regularPrice: regularPriceController.text,
//         salePrice: salePriceController.text,
//         categories: [
//           {'id': int.tryParse(categoryIdController.text) ?? 0}
//         ],
//         tags: [
//           {'name': tagNameController.text, 'slug': tagSlugController.text}
//         ],
//         images: [
//           {'src': _base64Image}
//         ],
//
//         metaData: [
//           {'key': 'custom_product', 'value': 'yes'},
//           {'key': 'product_created_by', 'value': 1}
//         ],
//         manageStock: true,
//         stockQuantity: int.tryParse(stockQuantityController.text) ?? 0,
//         taxStatus: 'taxable',
//         taxClass:
//         taxClassController.text.isEmpty ? 'standard' : taxClassController.text,
//       );
//
//       bloc.add(AddProductInventoryTaxSubmitEvent(product: product));
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Add Product Dynamically')),
//       body: BlocProvider.value(
//         value: bloc,
//         child: BlocBuilder<
//             AddProductInventoryTaxBloc,
//             AddProductInventoryTaxState>(
//           builder: (context, state) {
//             if (state is AddProductInventoryTaxLoading) {
//               return const Center(child: CircularProgressIndicator());
//             } else if (state is AddProductInventoryTaxLoaded) {
//               return Center(
//                   child: Text('✅ Product Added: ${state.product.name}'));
//             } else if (state is AddProductInventoryTaxError) {
//               return Center(child: Text('❌ Error: ${state.message}'));
//             }
//
//             return SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     _buildTextField(controller: nameController, label: 'Name'),
//                     _buildTextField(controller: skuController, label: 'SKU'),
//                     _buildTextField(
//                         controller: regularPriceController,
//                         label: 'Regular Price',
//                         keyboardType: TextInputType.number),
//                     _buildTextField(
//                         controller: salePriceController,
//                         label: 'Sale Price',
//                         keyboardType: TextInputType.number),
//                     _buildTextField(
//                         controller: categoryIdController,
//                         label: 'Category ID',
//                         keyboardType: TextInputType.number),
//                     _buildTextField(
//                         controller: tagNameController, label: 'Tag Name'),
//                     _buildTextField(
//                         controller: tagSlugController, label: 'Tag Slug'),
//                     _buildTextField(
//                         controller: stockQuantityController,
//                         label: 'Stock Quantity',
//                         keyboardType: TextInputType.number),
//                     _buildTextField(
//                         controller: taxClassController, label: 'Tax Class'),
//                     const SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: _pickImage,
//                       child: const Text('Pick Image from Gallery'),
//                     ),
//                     if (_pickedImage != null) ...[
//                       const SizedBox(height: 16),
//                       Image.file(File(_pickedImage!.path), height: 150),
//                     ],
//                     const SizedBox(height: 20),
//                     ElevatedButton(
//                         onPressed: _submitProduct,
//                         child: const Text('Add Product'))
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField({required TextEditingController controller,
//     required String label,
//     TextInputType keyboardType = TextInputType.text}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         controller: controller,
//         keyboardType: keyboardType,
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//         ),
//         validator: (value) =>
//         value == null || value.isEmpty ? '$label cannot be empty' : null,
//       ),
//     );
//   }
// }

/////////////////////



import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

import 'add_product_inventory_bloc/add_product_inventory_bloc.dart';
import 'add_product_inventory_entity.dart';
import 'add_product_inventory_bloc/add_product_inventory_state.dart';
import 'add_product_inventory_bloc/add_product_inventory_event.dart';
import 'add_product_inventory_get_usecase.dart';
import 'add_product_inventory_remote_data_source.dart';
import 'add_product_inventory_repository_impl.dart';

class AddProductInventoryTaxScreen extends StatefulWidget {
  final AddProductInventoryTaxBloc? bloc;
  final AddProductInventoryTaxGetUseCase? useCase;

  const AddProductInventoryTaxScreen({super.key, this.bloc, this.useCase});

  @override
  State<AddProductInventoryTaxScreen> createState() =>
      _AddProductInventoryTaxScreenState();
}

class _AddProductInventoryTaxScreenState
    extends State<AddProductInventoryTaxScreen> {
  late final AddProductInventoryTaxBloc bloc;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  final TextEditingController regularPriceController = TextEditingController();
  final TextEditingController salePriceController = TextEditingController();
  final TextEditingController categoryIdController = TextEditingController();
  final TextEditingController tagNameController = TextEditingController();
  final TextEditingController tagSlugController = TextEditingController();
  final TextEditingController stockQuantityController = TextEditingController();
  final TextEditingController taxClassController = TextEditingController();

  // Image picker
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  List<int>? _imageBytes;

  @override
  void initState() {
    super.initState();

    if (widget.bloc != null) {
      bloc = widget.bloc!;
    } else if (widget.useCase != null) {
      bloc = AddProductInventoryTaxBloc(addProductUseCase: widget.useCase!);
    } else {
      final remoteDataSource = AddProductInventoryTaxRemoteDataSource();
      final repository =
      AddProductInventoryTaxRepositoryImpl(remoteDataSource: remoteDataSource);
      final useCase = AddProductInventoryTaxGetUseCase(repository: repository);
      bloc = AddProductInventoryTaxBloc(addProductUseCase: useCase);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    regularPriceController.dispose();
    salePriceController.dispose();
    categoryIdController.dispose();
    tagNameController.dispose();
    tagSlugController.dispose();
    stockQuantityController.dispose();
    taxClassController.dispose();

    if (widget.bloc == null) {
      bloc.close();
    }

    super.dispose();
  }

  // ------------------- PICK IMAGE -------------------
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();

    // Decode and resize
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: 800);

    late List<int> finalBytes;
    if (extension == 'png') {
      finalBytes = img.encodePng(resized, level: 6);
    } else {
      finalBytes = img.encodeJpg(resized, quality: 80);
    }

    setState(() {
      _pickedImage = image;
      _imageBytes = finalBytes;
    });
  }

  // ------------------- UPLOAD IMAGE TO WOOCOMMERCE -------------------
  Future<String?> _uploadImage(String filename, List<int> bytes) async {
    try {
      // WooCommerce Media API endpoint
      const String url = 'https://yourdomain.com/wp-json/wp/v2/media';
      const String username = 'ck_xxx'; // replace with your consumer key
      const String password = 'cs_xxx'; // replace with your consumer secret

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] =
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final response = await request.send();

      if (response.statusCode == 201) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        return data['source_url']; // WooCommerce returns media URL
      } else {
        print('Image upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Image upload exception: $e');
      return null;
    }
  }

  // ------------------- SUBMIT PRODUCT -------------------
  void _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImage == null || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an image')),
      );
      return;
    }

    // Upload image first
    final imageUrl = await _uploadImage(_pickedImage!.name, _imageBytes!);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload failed')),
      );
      return;
    }

    // Create product entity
    final product = AddProductInventoryTaxEntity(
      id: 0,
      name: nameController.text,
      type: 'simple',
      sku: skuController.text,
      regularPrice: regularPriceController.text,
      salePrice: salePriceController.text,
      categories: [
        {'id': int.tryParse(categoryIdController.text) ?? 0}
      ],
      tags: [
        {'name': tagNameController.text, 'slug': tagSlugController.text}
      ],
      images: [
        {'src': imageUrl} // Use uploaded image URL
      ],
      metaData: [
        {'key': 'custom_product', 'value': 'yes'},
        {'key': 'product_created_by', 'value': 1}
      ],
      manageStock: true,
      stockQuantity: int.tryParse(stockQuantityController.text) ?? 0,
      taxStatus: 'taxable',
      taxClass: taxClassController.text.isEmpty
          ? 'standard'
          : taxClassController.text, attributes: [],
    );

    bloc.add(AddProductInventoryTaxSubmitEvent(product: product));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product Dynamically')),
      body: BlocProvider.value(
        value: bloc,
        child: BlocListener<AddProductInventoryTaxBloc, AddProductInventoryTaxState>(
          listener: (context, state) {
            if (state is AddProductInventoryTaxLoaded) {
              // Show success SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Product Added: ${state.product.name}'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is AddProductInventoryTaxError) {
              // Show error SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<AddProductInventoryTaxBloc, AddProductInventoryTaxState>(
            builder: (context, state) {
              if (state is AddProductInventoryTaxLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(controller: nameController, label: 'Name'),
                      _buildTextField(controller: skuController, label: 'SKU'),
                      _buildTextField(
                          controller: regularPriceController,
                          label: 'Regular Price',
                          keyboardType: TextInputType.number),
                      _buildTextField(
                          controller: salePriceController,
                          label: 'Sale Price',
                          keyboardType: TextInputType.number),
                      _buildTextField(
                          controller: categoryIdController,
                          label: 'Category ID',
                          keyboardType: TextInputType.number),
                      _buildTextField(controller: tagNameController, label: 'Tag Name'),
                      _buildTextField(controller: tagSlugController, label: 'Tag Slug'),
                      _buildTextField(
                          controller: stockQuantityController,
                          label: 'Stock Quantity',
                          keyboardType: TextInputType.number),
                      _buildTextField(controller: taxClassController, label: 'Tax Class'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text('Pick Image from Gallery'),
                      ),
                      if (_pickedImage != null) ...[
                        const SizedBox(height: 16),
                        Image.file(File(_pickedImage!.path), height: 150),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _submitProduct,
                          child: const Text('Add Product'))
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
        required String label,
        TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
        value == null || value.isEmpty ? '$label cannot be empty' : null,
      ),
    );
  }
}