import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../Blocs/Auth/shift_bloc.dart';
import '../../Constants/text.dart';
import '../../Database/db_helper.dart';
import '../../Database/user_db_helper.dart';
import '../../Helper/Extentions/nav_layout_manager.dart';
import '../../Helper/Extentions/theme_notifier.dart';
import '../../Models/Auth/shift_summary_model.dart';
import '../../Preferences/pinaka_preferences.dart';
import '../../Repositories/Auth/shift_repository.dart';
import '../../Widgets/widget_topbar.dart';
import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
import 'Inventory_Tags/inventory_tag_Widget.dart';
import 'Inventory_Tags/inventory_tag_entity.dart';
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_bloc.dart';
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_event.dart';
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_state.dart';
import 'add_product_toinventory/add_product_inventory_entity.dart';
import 'add_product_toinventory/add_product_inventory_get_usecase.dart';
import 'add_product_toinventory/add_product_inventory_remote_data_source.dart';
import 'add_product_toinventory/add_product_inventory_repository_impl.dart';
import 'image_upload_repository.dart';
import 'inventory_Tax/inventory_tax_screen.dart';

import 'inventory_attributes/inventory_attributes_widgets.dart';
import 'inventory_categories/inventory_categories_widgets.dart';
import 'inventory_get_product_types/inventory_get_product_types_widget.dart';

class InventoryScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  const InventoryScreen({super.key, this.lastSelectedIndex});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with LayoutSelectionMixin {
  final _formKey = GlobalKey<FormState>();

  // Basic Information Controllers
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _regularPriceController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _taxClassController = TextEditingController();

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  List<int>? _imageBytes;

  // Product Type
  String? _selectedProductType;

  // Category, Tag, Tax selection
  dynamic _selectedCategory;
  dynamic _selectedTax;
  final List<dynamic> _selectedTags = [];

  // Flags
  bool _hasVariablePrice = false;
  bool _manageStock = true;
  String _priceType = 'Fixed Price';

  // UI State
  int _selectedTab = 0;
  int _selectedSidebarIndex = 4;
  late ShiftBloc shiftBloc;
  final PinakaPreferences _preferences = PinakaPreferences();

  // Variants Data
  List<Map<String, dynamic>> _variants = [];

  // Attribute data for current variant being edited/added
  Map<String, dynamic>? _currentVariantAttribute;
  Map<String, dynamic>? _currentVariantAttributeItem;

  String? _selectedItemSlug;

  List<Map<String, dynamic>> _currentAttributes = [
    {'id': '1', 'unit': 'units', 'name': ''}
  ];
  String _currentVariantName = '';
  String _currentStock = '';
  String _currentRegularPrice = '';
  String _currentSalePrice = '';
  File? _currentImageFile;
  String? _selectedItemName;
  // Current variant index for editing
  int _currentVariantIndex = -1;

  // Add Product BLoC
  late AddProductInventoryTaxBloc _addProductBloc;

  // Controllers
  late TextEditingController _variantNameController;
  late TextEditingController _stockController;

  List<TextEditingController> _attributeControllers = [];

  // Validation & Loading
  final Map<String, String?> _fieldErrors = {};
  bool _isSaving = false;
  List<Map<String, dynamic>> _currentVariantAttributes = [];

  // Add this to your existing state variables
  List<Map<String, dynamic>> _variantAttributes = [
    {
      'attribute': null,
      'attributeItem': null,
      'selectedSlug': null,
    }
  ];


  late final ImageUploadRepository _imageUploadRepo;


  @override
  void initState() {
    super.initState();
    _variantNameController = TextEditingController(text: _currentVariantName);
    _stockController = TextEditingController(text: _currentStock);
    _updateAttributeControllers();

    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    shiftBloc = ShiftBloc(ShiftRepository());

    _initializeAddProductBloc();

    _imageUploadRepo = ImageUploadRepository();
  }

  void _updateAttributeControllers() {
    for (var controller in _attributeControllers) {
      controller.dispose();
    }
    _attributeControllers = _currentAttributes.map((attr) {
      return TextEditingController(text: attr['name'] ?? '');
    }).toList();
  }

  @override
  void dispose() {
    _variantNameController.dispose();
    _stockController.dispose();
    _regularPriceController.dispose();
    _salePriceController.dispose();
    for (var controller in _attributeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAddProductBloc() {
    final remoteDataSource = AddProductInventoryTaxRemoteDataSource();
    final repository = AddProductInventoryTaxRepositoryImpl(remoteDataSource: remoteDataSource);
    final useCase = AddProductInventoryTaxGetUseCase(repository: repository);
    _addProductBloc = AddProductInventoryTaxBloc(addProductUseCase: useCase);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final extension = image.path.split('.').last.toLowerCase();

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
      _imageFile = File(image.path);
      _imageBytes = finalBytes;
    });
  }

  // Future<String?> _uploadImage(String filename, List<int> bytes) async {
  //   try {
  //     const String url = 'https://merchantretail.alektasolutions.com/wp-json/wp/v2/media';
  //     const String username = 'ck_xxx'; // ← replace with real keys
  //     const String password = 'cs_xxx';
  //
  //     final request = http.MultipartRequest('POST', Uri.parse(url));
  //     request.headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  //     request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
  //
  //     final response = await request.send();
  //
  //     if (response.statusCode == 201) {
  //       final respStr = await response.stream.bytesToString();
  //       final data = jsonDecode(respStr);
  //       return data['source_url'];
  //     } else {
  //       print('Image upload failed → ${response.statusCode} ${await response.stream.bytesToString()}');
  //       return null;
  //     }
  //   } catch (e) {
  //     print('Image upload exception: $e');
  //     return null;
  //   }
  // }

  Future<String?> _uploadImageForProduct(File imageFile, {String? customFileName}) async {
    final url = await _imageUploadRepo.uploadImage(
      imageFile: imageFile,
      fileName: customFileName,
    );
    return url;
  }


  String? _validateForm() {
    _fieldErrors.clear();

    if (_nameController.text.trim().isEmpty) {
      _fieldErrors['name'] = 'Product name is required';
    }
    if (_selectedCategory == null) {
      _fieldErrors['category'] = 'Category is required';
    }
    if (_selectedProductType == null || _selectedProductType!.isEmpty) {
      _fieldErrors['productType'] = 'Product type is required';
    }

    if (_selectedProductType?.toLowerCase() == 'variable') {
      if (_variants.isEmpty) {
        _fieldErrors['variants'] = 'At least one variant is required for variable products';
      }
    } else {
      if (_regularPriceController.text.trim().isEmpty) {
        _fieldErrors['regularPrice'] = 'Regular price is required';
      }
    }

    return _fieldErrors.isNotEmpty ? _fieldErrors.values.first : null;
  }

  Future<AddProductInventoryTaxEntity?> _buildProductEntity() async {
    final validationError = _validateForm();
    if (validationError != null) return null;

    // ── Main product image ────────────────────────────────────────
    String mainImageUrl = 'https://merchantretail.alektasolutions.com/wp-content/uploads/2025/12/biryani-removebg-preview-1.png';

    if (_imageFile != null) {
      final uploadedUrl = await _uploadImageForProduct(
        _imageFile!,
        customFileName: 'product-${DateTime.now().millisecondsSinceEpoch}.jpg',

      );
      if (uploadedUrl != null) {
        mainImageUrl = uploadedUrl;
        print('╔═══════════════════════════════════════════════');
        print('║               UPLOAD SUCCESS                  ║');
        print('╚═══════════════════════════════════════════════');
        print('URL: $mainImageUrl');

      } else {
        // Optional: show snackbar or log
        print('Main image upload failed → using fallback');
      }
    }

    // ── Categories & Tags ─────────────────────────────────────────
    final List<Map<String, dynamic>> categories = _selectedCategory != null
        ? [{'id': _selectedCategory.id ?? 0}]
        : [];

    final List<Map<String, dynamic>> tags = [];
    final Set<String> seenSlugs = {};
    for (final tag in _selectedTags) {
      final slug = (tag.slug ?? '').trim();
      if (slug.isEmpty || seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);
      tags.add({
        'id': tag.id ?? 0,
        'name': tag.name?.trim() ?? slug,
        'slug': slug,
      });
    }

    // ── Images ────────────────────────────────────────────────────
    final List<Map<String, dynamic>> images = [{'src': mainImageUrl}];

    // ── Common meta ───────────────────────────────────────────────
    final List<Map<String, dynamic>> metaData = [
      {'key': 'custom_product', 'value': 'yes'},
      {'key': 'product_created_by', 'value': '1'},
      {'key': 'has_variable_price', 'value': _hasVariablePrice ? 'yes' : 'no'},
    ];

    // ── SIMPLE PRODUCT ────────────────────────────────────────────
    if (_selectedProductType?.toLowerCase() != 'variable') {
      return AddProductInventoryTaxEntity(
        id: 0,
        name: _nameController.text.trim(),
        type: 'simple',
        sku: _skuController.text.trim().isNotEmpty
            ? _skuController.text.trim()
            : 'SKU${DateTime.now().millisecondsSinceEpoch}',
        regularPrice: _regularPriceController.text.trim(),
        salePrice: _salePriceController.text.trim(),
        categories: categories,
        tags: tags,
        images: images,
        metaData: metaData,
        attributes: const [],
        manageStock: _manageStock,
        stockQuantity: int.tryParse(_qtyController.text.trim()) ?? 0,
        taxStatus: _selectedTax != null ? 'taxable' : 'none',
        taxClass: _selectedTax?.taxClass ?? 'standard',
      );
    }

    // ── VARIABLE PRODUCT ──────────────────────────────────────────
    if (_variants.isEmpty) return null;

    // 1. Collect all possible attribute → values
    final Map<String, Set<String>> attributeOptionsMap = {};

    for (final variant in _variants) {
      // Predefined attribute
      if (variant['attribute'] != null && variant['attributeItem'] != null) {
        final slug = (variant['attribute']['slug'] as String?)?.trim() ?? '';
        final value = (variant['attributeItem']['slug'] as String?)?.trim() ??
            (variant['attributeItem']['name'] as String?)?.trim() ??
            '';

        if (slug.isNotEmpty && value.isNotEmpty) {
          attributeOptionsMap.putIfAbsent(slug, () => {}).add(value);
        }
      }

      // Custom attributes (if you still use them)
      if (variant['attributes'] is List) {
        for (final attr in variant['attributes'] as List) {
          final name = (attr['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          final slug = 'pa_${name.toLowerCase().replaceAll(' ', '-')}';
          attributeOptionsMap.putIfAbsent(slug, () => {}).add(name);
        }
      }
    }

    // 2. Build WooCommerce product.attributes format
    final List<Map<String, dynamic>> productAttributes = attributeOptionsMap.entries.map((entry) {
      final slug = entry.key;
      final cleanName = slug.replaceFirst('pa_', '').replaceAll('-', ' ');
      final capitalized = cleanName.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');

      return {
        'id': 0,
        'name': capitalized,
        'slug': slug,
        'visible': true,
        'variation': true,
        'options': entry.value.toList(),
      };
    }).toList();

    // 3. Build variations payload (the most important part)
    final List<Map<String, dynamic>> variationsPayload = [];

    for (final variant in _variants) {
      final Map<String, dynamic> attrs = {};

      // Predefined attribute
      if (variant['attribute'] != null && variant['attributeItem'] != null) {
        final slug = variant['attribute']['slug']?.toString().trim() ?? '';
        final value = variant['attributeItem']['slug']?.toString().trim() ??
            variant['attributeItem']['name']?.toString().trim() ??
            '';

        if (slug.isNotEmpty && value.isNotEmpty) {
          attrs[slug] = value;
        }
      }

      // Custom attributes (if any)
      if (variant['attributes'] is List) {
        for (final attr in variant['attributes'] as List) {
          final name = attr['name']?.toString().trim() ?? '';
          if (name.isNotEmpty) {
            final slug = 'pa_${name.toLowerCase().replaceAll(' ', '-')}';
            attrs[slug] = name;
          }
        }
      }

      String? variantImageUrl;

      if (variant['imageFile'] != null && variant['imageFile'] is File) {
        try {
          variantImageUrl = await _uploadImageForProduct(
            variant['imageFile'] as File,
            customFileName: 'variant-${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } catch (e) {
          print("Variant image upload failed: $e");
        }
      }

      variationsPayload.add({
        'attributes': attrs,
        'regular_price': (variant['regularPrice']?.toString() ?? '0').trim(),
        'sale_price': (variant['salePrice']?.toString() ?? '').trim(),
        'stock_quantity': int.tryParse(variant['stock']?.toString() ?? '0') ?? 0,
        if (variantImageUrl != null) 'image': {'src': variantImageUrl},
      });

      variationsPayload.add({
        'attributes': attrs,
        'regular_price': (variant['regularPrice']?.toString() ?? '0').trim(),
        'sale_price': (variant['salePrice']?.toString() ?? '').trim(),
        'stock_quantity': int.tryParse(variant['stock']?.toString() ?? '0') ?? 0,
        if (variantImageUrl != null) 'image': {'src': variantImageUrl},
      });
    }

    // 4. Add variations payload to meta (you can rename key if backend expects different name)
    metaData.add({
      'key': '_pos_variations_payload',
      'value': variationsPayload,
    });

    // Optional: keep debug version too
    metaData.add({
      'key': '_pos_variations_payload_debug',
      'value': variationsPayload,
    });

    return AddProductInventoryTaxEntity(
      id: 0,
      name: _nameController.text.trim(),
      type: 'variable',
      sku: _skuController.text.trim().isNotEmpty
          ? _skuController.text.trim()
          : 'SKU${DateTime.now().millisecondsSinceEpoch}',
      regularPrice: '',
      salePrice: '',
      categories: categories,
      tags: tags,
      images: images,
      metaData: metaData,
      attributes: productAttributes,
      manageStock: _manageStock,
      stockQuantity: 0,
      taxStatus: _selectedTax != null ? 'taxable' : 'none',
      taxClass: _selectedTax?.taxClass ?? 'standard',
    );
  }

  // ──────────────────────────────────────────────────────────────
  // The rest of your code remains unchanged
  // ( _printFormData, _saveProduct, _clearForm, build, _buildTabButton, etc.)
  // ──────────────────────────────────────────────────────────────

  void _printFormData() {
    print('=== FORM DATA ===');
    print('Product Name: ${_nameController.text}');
    print('SKU: ${_skuController.text}');
    print('Product Type: $_selectedProductType');
    print('Has Variable Price: $_hasVariablePrice');
    print('Regular Price: ${_regularPriceController.text}');
    print('Sale Price: ${_salePriceController.text}');
    print('Stock Quantity: ${_qtyController.text}');

    if (_selectedCategory != null) {
      print('Category: ${_selectedCategory.name} (ID: ${_selectedCategory.id})');
    }

    if (_selectedTax != null) {
      print('Tax: ${_selectedTax.name} (Class: ${_selectedTax.taxClass})');
    }

    if (_selectedTags.isNotEmpty) {
      print('Tags:');
      final unique = <String, dynamic>{};
      for (var tag in _selectedTags) {
        final slug = tag.slug ?? '';
        if (!unique.containsKey(slug)) unique[slug] = tag;
      }
      for (var tag in unique.values) {
        print('  - ${tag.name} (slug: ${tag.slug})');
      }
    }

    if (_variants.isNotEmpty) {
      print('=== VARIANTS ===');
      for (int i = 0; i < _variants.length; i++) {
        var v = _variants[i];
        print('Variant ${i + 1}: ${v['name'] ?? 'Unnamed'}');
        print('  Stock: ${v['stock'] ?? '—'}');
        print('  Regular Price: ${v['regularPrice'] ?? '—'}');
        print('  Sale Price: ${v['salePrice'] ?? '—'}');

        if (v['attribute'] != null) {
          print('  Attribute: ${v['attribute']['name']} (Slug: ${v['attribute']['slug']})');
        }
        if (v['attributeItem'] != null) {
          final item = v['attributeItem'];
          print('  Selected Item Slug: ${item['slug'] ?? item['name'] ?? '—'}');
        }
      }
    }
    print('=== END FORM DATA ===');
  }

  Future<void> _saveProduct() async {
    if (_isSaving || !mounted) return;
    _fieldErrors.clear();
    setState(() => _isSaving = true);

    try {
      print('╔═══════════════════════════════════════════════');
      print('║          STARTING PRODUCT SAVE PROCESS        ║');
      print('╚═══════════════════════════════════════════════');

      _printFormData();

      final validationError = _validateForm();
      if (validationError != null) {
        print('✗ Validation failed: $validationError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validationError), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final product = await _buildProductEntity();
      if (product == null) {
        print('✗ Failed to build product entity');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to prepare product data'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      print('✓ Entity ready → ${product.name} (${product.type})');
      _addProductBloc.add(AddProductInventoryTaxSubmitEvent(product: product));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saving product...'), backgroundColor: Colors.green),
        );
      }
    } catch (e, st) {
      print('Save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _skuController.clear();
    _nameController.clear();
    _regularPriceController.clear();
    _salePriceController.clear();
    _qtyController.clear();
    _taxClassController.clear();
    _variantNameController.clear();
    _stockController.clear();

    _fieldErrors.clear();

    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _selectedProductType = null;
      _selectedCategory = null;
      _selectedTax = null;
      _selectedTags.clear();
      _hasVariablePrice = false;
      _variants.clear();
      _currentVariantName = '';
      _currentStock = '';
      _currentRegularPrice = '';
      _currentSalePrice = '';
      _currentImageFile = null;
      _currentAttributes = [{'id': '1', 'unit': 'units', 'name': ''}];
      _currentVariantAttribute = null;
      _currentVariantAttributeItem = null;
      _selectedItemSlug = null;
      _currentVariantIndex = -1;
      _updateAttributeControllers();
    });
  }

  Widget _buildTabButton(String text, int index, ThemeNotifier themeHelper) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF2196F3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : (themeHelper.themeMode ==
                ThemeMode.dark ? Colors.white70 : Colors.black54),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;

    bool isSmallScreen = screenWidth < 768;
    bool isMediumScreen = screenWidth >= 768 && screenWidth < 1024;

    return BlocConsumer<AddProductInventoryTaxBloc,
        AddProductInventoryTaxState>(
      bloc: _addProductBloc,
      listener: (context, state) {
        if (state is AddProductInventoryTaxLoaded) {
          setState(() {
            _isSaving = false;
          });
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product Added: ${state.product.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is AddProductInventoryTaxError) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? Color(0xFF1F1D2B) : Color(0xFFF5F5F5),
          body: Column(
            children: [
              TopBar(
                screen: Screen.SHIFT,
                onModeChanged: () async {
                  String newLayout;
                  if (sidebarPosition == SidebarPosition.left) {
                    newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
                  } else if (sidebarPosition == SidebarPosition.right) {
                    newLayout =
                        SharedPreferenceTextConstants.navBottomOrderLeft;
                  } else {
                    newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
                  }
                  PinakaPreferences.layoutSelectionNotifier.value = newLayout;
                  await UserDbHelper().saveUserSettings(
                      {AppDBConst.layoutSelection: newLayout},
                      modeChange: true);
                  setState(() {});
                },
              ),
              const Divider(color: Colors.grey, thickness: 0.4, height: 1),
              Expanded(
                child: Row(
                  children: [
                    if (sidebarPosition == SidebarPosition.left)
                      custom_widgets.NavigationBar(
                        selectedSidebarIndex: _selectedSidebarIndex,
                        onSidebarItemSelected: (index) =>
                            setState(() => _selectedSidebarIndex = index),
                        isVertical: true,
                      ),
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(isSmallScreen ? 5 : 10),
                        decoration: BoxDecoration(
                          color: isDark ? Color(0xFF1F1D2B) : Colors.white,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(
                                  isSmallScreen ? 8.0 : 16.0),
                              child: Row(
                                children: [
                                  Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                        color: Color(0xFF3B4259),
                                        borderRadius: BorderRadius.circular(
                                            6.0)),
                                    child: TextButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.arrow_back_rounded,
                                          color: Colors.white, size: 20),
                                      label: const Text('Back',
                                          style: TextStyle(color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: isDark ? Color(0xFF252837) : Colors
                                          .grey[200],
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildTabButton(
                                            'Add Product', 0, themeHelper),
                                        _buildTabButton(
                                            'Audit list', 1, themeHelper),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _selectedTab == 0
                                  ? _buildAddProductTab(
                                  isDark, isSmallScreen, isMediumScreen)
                                  : _buildAuditListTab(isDark, isSmallScreen),
                            ),

                            // Bottom App Bar with Save & Update and Clear buttons
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? Color(0xFF252837) : Colors
                                    .white,
                                border: Border(
                                  top: BorderSide(
                                    color: isDark ? Color(0xFF3B4259) : Color(
                                        0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: _clearForm,
                                    child: Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: Color(0xFF2196F3),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: Color(0xFF2196F3), width: 2),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              6)),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 30 : 50,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: _isSaving ? null : _saveProduct,
                                    child: _isSaving
                                        ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<
                                            Color>(Colors.white),
                                      ),
                                    )
                                        : Text(
                                      'Save & Update',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2196F3),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              6)),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 30 : 50,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (sidebarPosition == SidebarPosition.right)
                      custom_widgets.NavigationBar(
                        selectedSidebarIndex: _selectedSidebarIndex,
                        onSidebarItemSelected: (index) =>
                            setState(() => _selectedSidebarIndex = index),
                        isVertical: true,
                      ),
                  ],
                ),
              ),
              if (sidebarPosition == SidebarPosition.bottom)
                custom_widgets.NavigationBar(
                  selectedSidebarIndex: _selectedSidebarIndex,
                  onSidebarItemSelected: (index) =>
                      setState(() => _selectedSidebarIndex = index),
                  isVertical: false,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddProductTab(bool isDark, bool isSmallScreen,
      bool isMediumScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 16, vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            isSmallScreen || isMediumScreen
                ? _buildMobileLayout(isDark, isSmallScreen)
                : _buildDesktopLayout(isDark),
            SizedBox(height: 32),

            // Error message display - Only show below text fields
            ..._buildValidationErrors(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildValidationErrors() {
    List<Widget> errorWidgets = [];

    if (_fieldErrors.containsKey('name')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['name']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_fieldErrors.containsKey('category')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['category']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_fieldErrors.containsKey('productType')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['productType']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_fieldErrors.containsKey('regularPrice')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['regularPrice']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_fieldErrors.containsKey('quantity')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['quantity']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    if (_fieldErrors.containsKey('variants')) {
      errorWidgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            _fieldErrors['variants']!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }

    return errorWidgets;
  }

  Widget _buildMobileLayout(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductImageSection(isDark, isSmallScreen),
        SizedBox(height: 16),
        _buildSKUSection(isDark, isSmallScreen),
        SizedBox(height: 16),
        Text('Product Name', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter product name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        SizedBox(height: 16),
        Text('Category', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryCategoriesDropdown(
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
          },
        ),
        SizedBox(height: 16),
        Text('Product Type', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryGetProductTypesWidget(
          onTypeSelected: (selectedType) {
            setState(() {
              _selectedProductType = selectedType;
            });
          },
        ),
        SizedBox(height: 16),
        _buildPriceSection(isDark),
        SizedBox(height: 16),
        Text('Tax', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryTaxDropdownWidget(
          onTaxSelected: (tax) {
            setState(() {
              _selectedTax = tax;
            });
          },
        ),
        SizedBox(height: 16),
        Text('Stock', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        TextFormField(
          controller: _qtyController,
          keyboardType: TextInputType.number,
          enabled: !_hasVariablePrice,
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        SizedBox(height: 16),
        SizedBox(height: 8),
        InventoryTagMultiSelectWidget(
          onTypeSelected: (tag) {
            if (tag != null) {
              setState(() {
                _selectedTags.add(tag);
              });
            }
          },
        ),
        SizedBox(height: 16),
        _buildVariantSection(isDark, isSmallScreen),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery
            .of(context)
            .size
            .height * 0.7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information Card
          Expanded(
            flex: 3,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 470,
              ),
              child: Card(
                color: Theme
                    .of(context)
                    .cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.zero,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF89B1EE) : const Color(
                              0xFFF5F7FA),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            Text(
                              'Product Image',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF3B4259)
                                            : const Color(0xFFE0E0E0),
                                        width: 2,
                                      ),
                                      color: isDark
                                          ? const Color(0xFF252837)
                                          : Colors.white,
                                      image: _imageFile != null
                                          ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover,
                                      )
                                          : null,
                                    ),
                                    child: _imageFile == null
                                        ? Column(
                                      mainAxisAlignment: MainAxisAlignment
                                          .center,
                                      children: [
                                        const Icon(
                                          Icons.image_outlined,
                                          size: 36,
                                          color: Color(0xFF2196F3),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Upload Image',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          'Please upload a clear image',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                        Text(
                                          'of the item',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Max File Size : 200KB',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // SKU
                            Text(
                              'SKU',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF252837) : Colors
                                    .white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3B4259)
                                      : const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _skuController,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors
                                            .black87,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Generate the Sku',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black26,
                                          fontSize: 13,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE91E63),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _skuController.text =
                                          'SKU${DateTime
                                              .now()
                                              .millisecondsSinceEpoch}';
                                        });
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        child: Text(
                                          'Generate',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Product Name
                            Text(
                              'Product Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                hintText: 'Enter the name',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                              ),
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors
                                      .black87),
                            ),
                            const SizedBox(height: 8),

                            // Category
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InventoryCategoriesDropdown(
                              onCategorySelected: (category) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              },
                            ),
                            const SizedBox(height: 8),

                            // Product Type
                            Text(
                              'Product Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InventoryGetProductTypesWidget(
                              onTypeSelected: (selectedType) {
                                setState(() {
                                  _selectedProductType = selectedType;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: 16),

          // Expanded(
          //   flex: 3,
          //   child: ConstrainedBox(
          //     constraints: BoxConstraints(
          //       minHeight: 480,
          //     ),
          //     child: Material(
          //       color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
          //       elevation: 2,
          //       borderRadius: BorderRadius.circular(12),
          //       child: SingleChildScrollView(
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Container(
          //               width: double.infinity,
          //               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          //               decoration: BoxDecoration(
          //                 color: isDark ? const Color(0xFFDAC14A) : const Color(0xFFFFFBF0),
          //                 borderRadius: const BorderRadius.only(
          //                   topLeft: Radius.circular(12),
          //                   topRight: Radius.circular(12),
          //                 ),
          //               ),
          //               child: Text(
          //                 'Pricing & Tax',
          //                 style: TextStyle(
          //                   fontSize: 19,
          //                   fontWeight: FontWeight.w600,
          //                   color: isDark ? Colors.white : Colors.black87,
          //                 ),
          //               ),
          //             ),
          //             Padding(
          //               padding: const EdgeInsets.all(12),
          //               child: Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   // Helper boolean to disable price/stock fields
          //                   Builder(builder: (_) {
          //                     final bool isPriceStockDisabled =
          //                         _hasVariablePrice || _selectedProductType == 'variable';
          //
          //                     return Column(
          //                       children: [
          //                         Row(
          //                           children: [
          //                             // Regular Price
          //                             Expanded(
          //                               child: Column(
          //                                 crossAxisAlignment: CrossAxisAlignment.start,
          //                                 children: [
          //                                   Text(
          //                                     'Regular Price',
          //                                     style: TextStyle(
          //                                       fontSize: 15,
          //                                       fontWeight: FontWeight.w500,
          //                                       color: isDark ? Colors.white70 : Colors.black87,
          //                                     ),
          //                                   ),
          //                                   const SizedBox(height: 2),
          //                                   TextFormField(
          //                                     controller: _regularPriceController,
          //                                     enabled: !isPriceStockDisabled,
          //                                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
          //                                     style: TextStyle(
          //                                       color: isPriceStockDisabled
          //                                           ? (isDark ? Colors.white38 : Colors.black38)
          //                                           : (isDark ? Colors.white : Colors.black87),
          //                                     ),
          //                                     decoration: const InputDecoration(
          //                                       prefixText: '\$  ',
          //                                       hintText: '00.00',
          //                                       border: OutlineInputBorder(),
          //                                       contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          //                                     ),
          //                                   ),
          //                                 ],
          //                               ),
          //                             ),
          //                             const SizedBox(width: 16),
          //                             // Sale Price
          //                             Expanded(
          //                               child: Column(
          //                                 crossAxisAlignment: CrossAxisAlignment.start,
          //                                 children: [
          //                                   Text(
          //                                     'Sale Price',
          //                                     style: TextStyle(
          //                                       fontSize: 15,
          //                                       fontWeight: FontWeight.w500,
          //                                       color: isDark ? Colors.white70 : Colors.black87,
          //                                     ),
          //                                   ),
          //                                   const SizedBox(height: 2),
          //                                   TextFormField(
          //                                     controller: _salePriceController,
          //                                     enabled: !isPriceStockDisabled,
          //                                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
          //                                     style: TextStyle(
          //                                       color: isPriceStockDisabled
          //                                           ? (isDark ? Colors.white38 : Colors.black38)
          //                                           : (isDark ? Colors.white : Colors.black87),
          //                                     ),
          //                                     decoration: const InputDecoration(
          //                                       prefixText: '\$  ',
          //                                       hintText: '00.00',
          //                                       border: OutlineInputBorder(),
          //                                       contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          //                                     ),
          //                                   ),
          //                                 ],
          //                               ),
          //                             ),
          //                           ],
          //                         ),
          //                         const SizedBox(height: 4),
          //                         // Variable Price Checkbox
          //                         VariablePriceCheckboxWidget(
          //                           value: _hasVariablePrice,
          //                           isDark: isDark,
          //                           name: 'Variable Price',
          //                           slug: 'variable-price',
          //                           onChanged: (checked) {
          //                             setState(() {
          //                               _hasVariablePrice = checked;
          //
          //                               // Clear price/quantity fields if variable price enabled
          //                               if (checked) {
          //                                 _regularPriceController.clear();
          //                                 _salePriceController.clear();
          //                                 _qtyController.clear();
          //                               }
          //
          //                               const variablePriceSlug = 'variable-price';
          //
          //                               if (checked) {
          //                                 // Add tag only if not already present
          //                                 if (!_selectedTags.any((t) => t.slug == variablePriceSlug)) {
          //                                   _selectedTags.add(
          //                                     const Inventory_Tag_Entity(
          //                                       id: 0, // local-only tag
          //                                       name: 'Variable Price',
          //                                       slug: variablePriceSlug,
          //                                       description: '',
          //                                       count: 0,
          //                                     ),
          //                                   );
          //                                 }
          //                               } else {
          //                                 // Remove tag when unchecked
          //                                 _selectedTags.removeWhere((t) => t.slug == variablePriceSlug);
          //                               }
          //                             });
          //
          //                             debugPrint(
          //                               'Variable Price Tag -> ${_selectedTags.map((e) => e.slug).toList()}',
          //                             );
          //                           },
          //                         ),
          //                         const SizedBox(height: 4),
          //                         // Tax
          //                         Text(
          //                           'Tax',
          //
          //                           style: TextStyle(
          //                             fontSize: 15,
          //
          //                             fontWeight: FontWeight.w500,
          //                             color: isDark ? Colors.white70 : Colors.black87,
          //                           ),
          //                         ),
          //                         const SizedBox(height: 4),
          //                         InventoryTaxDropdownWidget(
          //                           onTaxSelected: (tax) {
          //                             setState(() {
          //                               _selectedTax = tax;
          //                             });
          //                           },
          //                         ),
          //                         const SizedBox(height: 4),
          //                         // Stock
          //                         Text(
          //                           'Stock',
          //                           style: TextStyle(
          //                             fontSize: 15,
          //                             fontWeight: FontWeight.w500,
          //                             color: isDark ? Colors.white70 : Colors.black87,
          //                           ),
          //                         ),
          //                         const SizedBox(height: 4),
          //                         TextFormField(
          //                           controller: _qtyController,
          //                           enabled: !isPriceStockDisabled,
          //                           keyboardType: TextInputType.number,
          //                           style: TextStyle(
          //                             color: isPriceStockDisabled
          //                                 ? (isDark ? Colors.white38 : Colors.black38)
          //                                 : (isDark ? Colors.white : Colors.black87),
          //                           ),
          //                           decoration: const InputDecoration(
          //                             hintText: 'Enter quantity',
          //                             border: OutlineInputBorder(),
          //                             contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          //                           ),
          //                         ),
          //                         const SizedBox(height: 4),
          //                         // Tags
          //                         Text(
          //                           'Tags',
          //                           style: TextStyle(
          //                             fontSize: 15,
          //                             fontWeight: FontWeight.w500,
          //                             color: isDark ? Colors.white70 : Colors.black87,
          //                           ),
          //                         ),
          //                         const SizedBox(height: 4),
          //                         InventoryTagMultiSelectWidget(
          //                           onTypeSelected: (tag) {
          //                             if (tag != null) {
          //                               setState(() {
          //                                 _selectedTags.add(tag);
          //                               });
          //                             }
          //                           },
          //                         ),
          //                       ],
          //                     );
          //                   }),
          //                 ],
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          ////

          Expanded(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 480),
              child: Material(
                color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFDAC14A)
                              : const Color(0xFFFFFBF0),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Pricing & Tax',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Builder(
                          builder: (_) {
                            final bool isProductTypeVariable =
                                _selectedProductType == 'variable';
                            final bool isPriceStockDisabled =
                                _hasVariablePrice || isProductTypeVariable;

                            final Color disabledFill = Colors.grey.shade200;
                            final Color disabledText = Colors.grey.shade500;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // PRICES
                                Row(
                                  children: [
                                    // Regular Price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Regular Price',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: isPriceStockDisabled
                                                    ? Colors.grey
                                                    : (isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            controller: _regularPriceController,
                                            enabled: !isPriceStockDisabled,
                                            keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                            style: TextStyle(
                                              color: isPriceStockDisabled
                                                  ? disabledText
                                                  : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                            ),
                                            decoration: InputDecoration(
                                              prefixText: '\$  ',
                                              hintText: '00.00',
                                              filled: true,
                                              fillColor: isPriceStockDisabled
                                                  ? disabledFill
                                                  : Colors.transparent,
                                              border:
                                              const OutlineInputBorder(),
                                              contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Sale Price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Sale Price',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: isPriceStockDisabled
                                                    ? Colors.grey
                                                    : (isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          TextFormField(
                                            controller: _salePriceController,
                                            enabled: !isPriceStockDisabled,
                                            keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                            style: TextStyle(
                                              color: isPriceStockDisabled
                                                  ? disabledText
                                                  : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                            ),
                                            decoration: InputDecoration(
                                              prefixText: '\$  ',
                                              hintText: '00.00',
                                              filled: true,
                                              fillColor: isPriceStockDisabled
                                                  ? disabledFill
                                                  : Colors.transparent,
                                              border:
                                              const OutlineInputBorder(),
                                              contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // VARIABLE PRICE CHECKBOX (DISABLED ONLY FOR VARIABLE TYPE)
                                IgnorePointer(
                                  ignoring: isProductTypeVariable,
                                  child: Opacity(
                                    opacity: isProductTypeVariable ? 0.5 : 1,
                                    child: VariablePriceCheckboxWidget(
                                      value: _hasVariablePrice,
                                      isDark: isDark,
                                      name: 'Variable Price',
                                      slug: 'variable-price',
                                      onChanged: (checked) {
                                        setState(() {
                                          _hasVariablePrice = checked;

                                          if (checked) {
                                            _regularPriceController.clear();
                                            _salePriceController.clear();
                                            _qtyController.clear();
                                          }

                                          const slug = 'variable-price';
                                          if (checked) {
                                            if (!_selectedTags.any(
                                                    (t) => t.slug == slug)) {
                                              _selectedTags.add(
                                                const Inventory_Tag_Entity(
                                                  id: 0,
                                                  name: 'Variable Price',
                                                  slug: slug,
                                                  description: '',
                                                  count: 0,
                                                ),
                                              );
                                            }
                                          } else {
                                            _selectedTags.removeWhere(
                                                    (t) => t.slug == slug);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // TAX (TEXT GRAY ONLY — DROPDOWN ENABLED)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Tax',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isProductTypeVariable
                                          ? Colors.grey
                                          : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InventoryTaxDropdownWidget(
                                  onTaxSelected: (tax) {
                                    setState(() => _selectedTax = tax);
                                  },
                                ),

                                const SizedBox(height: 8),

                                // STOCK
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Stock',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isPriceStockDisabled
                                          ? Colors.grey
                                          : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _qtyController,
                                  enabled: !isPriceStockDisabled,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    color: isPriceStockDisabled
                                        ? disabledText
                                        : (isDark
                                        ? Colors.white
                                        : Colors.black87),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter quantity',
                                    filled: true,
                                    fillColor: isPriceStockDisabled
                                        ? disabledFill
                                        : Colors.transparent,
                                    border:
                                    const OutlineInputBorder(),
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // TAGS (TEXT GRAY ONLY)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Tags',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isProductTypeVariable
                                          ? Colors.grey
                                          : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InventoryTagMultiSelectWidget(
                                  onTypeSelected: (tag) {
                                    if (tag != null) {
                                      setState(() => _selectedTags.add(tag));
                                    }
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: 16),

          // Variants Card
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 600,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Color(0xFF1E3A5F) : Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Color(0xFF2196F3) : Color(0xFFBBDEFB),
                      width: 1),
                ),
                child: _buildVariantContent(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Product Image', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: isSmallScreen ? double.infinity : 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
              border: Border.all(
                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
              image: _imageFile != null
                  ? DecorationImage(
                image: FileImage(_imageFile!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: _imageFile == null
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, size: 40, color: Color(0xFF2196F3)),
                SizedBox(height: 8),
                Text('Upload Image',
                    style: TextStyle(color: Color(0xFF2196F3), fontSize: 12)),
              ],
            )
                : null,
          ),
        ),
        SizedBox(height: 4),
        Text('Please upload a clear image of the item',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            textAlign: TextAlign.center),
        Text('Max File Size : 200KB',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildSKUSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SKU', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _skuController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Generate the Sku',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    setState(() =>
                    _skuController.text = 'SKU${DateTime
                        .now()
                        .millisecondsSinceEpoch}'),
                child: Text('Generate', style: TextStyle(color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEA3D8F),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Price', style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPriceField(
                'Regular Price', _regularPriceController, isDark)),
            SizedBox(width: 16),
            Expanded(child: _buildPriceField(
                'Sale Price', _salePriceController, isDark)),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _hasVariablePrice,
              onChanged: (val) =>
                  setState(() => _hasVariablePrice = val ?? false),
              activeColor: Color(0xFF2196F3),
              side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
            ),
            Expanded(
              child: Text(
                'If the product has Variable Price',
                style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller,
      bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black54)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: '\$ 00.00',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            filled: true,
            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSection(bool isDark, bool isSmallScreen) {
    return Container(
      width: 480,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E3A5F) : Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? Color(0xFF2196F3) : Color(0xFFBBDEFB), width: 1),
      ),
      child: _buildVariantContent(isDark),
    );
  }

  ////impo -----

  // Widget _buildVariantContent(bool isDark) {
  //   final bool isVariantsEnabled = (_selectedProductType ?? '').toLowerCase() == 'variable';
  //
  //   return SingleChildScrollView(
  //     child: Opacity(
  //       opacity: isVariantsEnabled ? 1.0 : 0.5,
  //       child: IgnorePointer(
  //         ignoring: !isVariantsEnabled,
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Header
  //             Padding(
  //               padding: const EdgeInsets.only(left: 10, top: 10),
  //               child: Row(
  //                 children: [
  //                   Text(
  //                     "Variant's ",
  //                     style: TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.w600,
  //                       color: isDark ? Colors.white : Colors.black87,
  //                     ),
  //                   ),
  //                   Text(
  //                     isVariantsEnabled ? '(Optional)' : '(Only for Variable products)',
  //                     style: TextStyle(
  //                       fontSize: 12,
  //                       color: isVariantsEnabled ? Colors.grey.shade400 : Colors.grey.shade600,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(height: 12),
  //
  //             // Warning when not variable
  //             if (!isVariantsEnabled) ...[
  //               Container(
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.07),
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(color: Colors.red.withOpacity(0.3)),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Icon(Icons.info_outline, color: Colors.red.shade400, size: 20),
  //                     const SizedBox(width: 12),
  //                     Expanded(
  //                       child: Text(
  //                         'Variants are only available when Product Type is "Variable"',
  //                         style: TextStyle(
  //                           color: isDark ? Colors.red.shade300 : Colors.red.shade700,
  //                           fontSize: 13,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //             ],
  //
  //             // Existing variants list
  //             if (_variants.isNotEmpty) ...[
  //               ..._variants.asMap().entries.map((entry) {
  //                 int index = entry.key;
  //                 var variant = entry.value;
  //                 return Container(
  //                   margin: EdgeInsets.only(bottom: 12),
  //                   padding: EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: isDark ? Color(0xFF1F1D2B) : Colors.white,
  //                     borderRadius: BorderRadius.circular(8),
  //                     border: Border.all(
  //                       color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
  //                     ),
  //                   ),
  //                   child: Row(
  //                     children: [
  //                       Container(
  //                         width: 32,
  //                         height: 32,
  //                         decoration: BoxDecoration(
  //                           color: Color(0xFF2196F3).withOpacity(0.1),
  //                           borderRadius: BorderRadius.circular(6),
  //                         ),
  //                         child: Center(
  //                           child: Text(
  //                             '${index + 1}',
  //                             style: TextStyle(
  //                               fontSize: 14,
  //                               fontWeight: FontWeight.w600,
  //                               color: Color(0xFF2196F3),
  //                             ),
  //                           ),
  //                         ),
  //                       ),
  //                       SizedBox(width: 12),
  //                       Container(
  //                         width: 60,
  //                         height: 60,
  //                         decoration: BoxDecoration(
  //                           borderRadius: BorderRadius.circular(8),
  //                           color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                           border: Border.all(
  //                             color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
  //                           ),
  //                         ),
  //                         child: variant['imageFile'] != null
  //                             ? ClipRRect(
  //                           borderRadius: BorderRadius.circular(8),
  //                           child: Image.file(
  //                             variant['imageFile'],
  //                             fit: BoxFit.cover,
  //                           ),
  //                         )
  //                             : Icon(
  //                           Icons.image_outlined,
  //                           size: 24,
  //                           color: Color(0xFF2196F3),
  //                         ),
  //                       ),
  //                       SizedBox(width: 16),
  //                       Expanded(
  //                         child: Column(
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Row(
  //                               children: [
  //                                 Expanded(
  //                                   child: Column(
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: [
  //                                       Text('Variant Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
  //                                       SizedBox(height: 2),
  //                                       Text(
  //                                         variant['name'] ?? 'Unnamed',
  //                                         style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
  //                                         overflow: TextOverflow.ellipsis,
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                                 SizedBox(width: 16),
  //                                 Column(
  //                                   crossAxisAlignment: CrossAxisAlignment.start,
  //                                   children: [
  //                                     Text('Stock', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
  //                                     SizedBox(height: 2),
  //                                     Text(
  //                                       variant['stock'] ?? '0',
  //                                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
  //                                     ),
  //                                   ],
  //                                 ),
  //                               ],
  //                             ),
  //                             SizedBox(height: 8),
  //                             Row(
  //                               children: [
  //                                 Expanded(
  //                                   child: Column(
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: [
  //                                       Text('Regular Price', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
  //                                       SizedBox(height: 2),
  //                                       Text(
  //                                         '\$ ${variant['regularPrice'] ?? '0.00'}',
  //                                         style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                                 SizedBox(width: 16),
  //                                 Expanded(
  //                                   child: Column(
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: [
  //                                       Text('Sale Price', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
  //                                       SizedBox(height: 2),
  //                                       Text(
  //                                         '\$ ${variant['salePrice'] ?? '0.00'}',
  //                                         style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                               ],
  //                             ),
  //                             // Attributes display
  //                             if (variant['attribute'] != null || variant['attributeItem'] != null)
  //                               Padding(
  //                                 padding: EdgeInsets.only(top: 8),
  //                                 child: Column(
  //                                   crossAxisAlignment: CrossAxisAlignment.start,
  //                                   children: [
  //                                     Text('Attributes:', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
  //                                     if (variant['attribute'] != null)
  //                                       Text(
  //                                         '${variant['attribute']['name']} (${variant['attribute']['slug']})',
  //                                         style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
  //                                       ),
  //                                     if (variant['attributeItem'] != null)
  //                                       Text(
  //                                         'Slug: ${variant['attributeItem']['slug'] ?? '—'}',
  //                                         style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
  //                                       ),
  //                                   ],
  //                                 ),
  //                               ),
  //                           ],
  //                         ),
  //                       ),
  //                       SizedBox(width: 12),
  //                       Row(
  //                         children: [
  //                           InkWell(
  //                             onTap: () {
  //                               setState(() {
  //                                 _currentVariantIndex = index;
  //                                 _currentVariantName = variant['name'] ?? '';
  //                                 _currentStock = variant['stock'] ?? '';
  //                                 _currentRegularPrice = variant['regularPrice'] ?? '';
  //                                 _currentSalePrice = variant['salePrice'] ?? '';
  //                                 _currentImageFile = variant['imageFile'];
  //                                 _currentVariantAttribute = variant['attribute'];
  //                                 _currentVariantAttributeItem = variant['attributeItem'];
  //                                 _selectedItemSlug = variant['attributeItem']?['slug'] ?? '';
  //                                 _variantNameController.text = _currentVariantName;
  //                                 _stockController.text = _currentStock;
  //                                 _regularPriceController.text = _currentRegularPrice;
  //                                 _salePriceController.text = _currentSalePrice;
  //                               });
  //                             },
  //                             child: Container(
  //                               padding: EdgeInsets.all(8),
  //                               decoration: BoxDecoration(
  //                                 color: Color(0xFF2196F3).withOpacity(0.1),
  //                                 borderRadius: BorderRadius.circular(6),
  //                               ),
  //                               child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2196F3)),
  //                             ),
  //                           ),
  //                           SizedBox(width: 8),
  //                           InkWell(
  //                             onTap: () {
  //                               setState(() {
  //                                 _variants.removeAt(index);
  //                               });
  //                             },
  //                             child: Container(
  //                               padding: EdgeInsets.all(8),
  //                               decoration: BoxDecoration(
  //                                 color: Color(0xFFEF5350).withOpacity(0.1),
  //                                 borderRadius: BorderRadius.circular(6),
  //                               ),
  //                               child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF5350)),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               }).toList(),
  //               SizedBox(height: 12),
  //             ],
  //
  //             // ────────────────────────────────────────────────
  //             // Main ADD/EDIT FORM
  //             // ────────────────────────────────────────────────
  //             Container(
  //               width: double.infinity,
  //               height: 480,
  //               padding: const EdgeInsets.all(16),
  //               decoration: BoxDecoration(
  //                 color: isDark ? Color(0xFF1F1D2B) : Colors.white,
  //                 borderRadius: BorderRadius.circular(10),
  //                 border: Border.all(
  //                   color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
  //                 ),
  //               ),
  //               child: SingleChildScrollView(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     // Image + Name/Stock/Price row (unchanged)
  //                     Row(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Column(
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Text(
  //                               'Variant Image',
  //                               style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
  //                             ),
  //                             SizedBox(height: 8),
  //                             InkWell(
  //                               onTap: () async {
  //                                 final XFile? pickedFile = await _picker.pickImage(
  //                                   source: ImageSource.gallery,
  //                                   maxWidth: 200,
  //                                   maxHeight: 200,
  //                                   imageQuality: 85,
  //                                 );
  //                                 if (pickedFile != null) {
  //                                   setState(() {
  //                                     _currentImageFile = File(pickedFile.path);
  //                                   });
  //                                 }
  //                               },
  //                               child: Container(
  //                                 width: 100,
  //                                 height: 100,
  //                                 decoration: BoxDecoration(
  //                                   color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                   borderRadius: BorderRadius.circular(8),
  //                                   border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
  //                                 ),
  //                                 child: _currentImageFile != null
  //                                     ? ClipRRect(
  //                                   borderRadius: BorderRadius.circular(8),
  //                                   child: Image.file(_currentImageFile!, fit: BoxFit.cover),
  //                                 )
  //                                     : Column(
  //                                   mainAxisAlignment: MainAxisAlignment.center,
  //                                   children: [
  //                                     Icon(Icons.cloud_upload_outlined, size: 24, color: Color(0xFF2196F3)),
  //                                     SizedBox(height: 4),
  //                                     Text('Upload', style: TextStyle(fontSize: 11, color: Color(0xFF2196F3))),
  //                                   ],
  //                                 ),
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         SizedBox(width: 16),
  //                         Expanded(
  //                           child: Column(
  //                             children: [
  //                               Row(
  //                                 children: [
  //                                   Expanded(
  //                                     child: Column(
  //                                       crossAxisAlignment: CrossAxisAlignment.start,
  //                                       children: [
  //                                         Text('Variant Name', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
  //                                         SizedBox(height: 6),
  //                                         TextField(
  //                                           controller: _variantNameController,
  //                                           onChanged: (value) => _currentVariantName = value,
  //                                           decoration: InputDecoration(
  //                                             hintText: 'Enter name',
  //                                             filled: true,
  //                                             fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  //                                             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                           ),
  //                                         ),
  //                                       ],
  //                                     ),
  //                                   ),
  //                                   SizedBox(width: 12),
  //                                   SizedBox(
  //                                     width: 100,
  //                                     child: Column(
  //                                       crossAxisAlignment: CrossAxisAlignment.start,
  //                                       children: [
  //                                         Text('Stock', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
  //                                         SizedBox(height: 6),
  //                                         TextField(
  //                                           controller: _stockController,
  //                                           onChanged: (value) => _currentStock = value,
  //                                           keyboardType: TextInputType.number,
  //                                           decoration: InputDecoration(
  //                                             hintText: '0',
  //                                             filled: true,
  //                                             fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  //                                             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                           ),
  //                                         ),
  //                                       ],
  //                                     ),
  //                                   ),
  //                                 ],
  //                               ),
  //                               SizedBox(height: 12),
  //                               Row(
  //                                 children: [
  //                                   Expanded(
  //                                     child: Column(
  //                                       crossAxisAlignment: CrossAxisAlignment.start,
  //                                       children: [
  //                                         Text('Regular Price', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
  //                                         SizedBox(height: 6),
  //                                         TextField(
  //                                           controller: _regularPriceController,
  //                                           onChanged: (value) => _currentRegularPrice = value,
  //                                           keyboardType: TextInputType.numberWithOptions(decimal: true),
  //                                           decoration: InputDecoration(
  //                                             hintText: '\$ 0.00',
  //                                             filled: true,
  //                                             fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  //                                             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                           ),
  //                                         ),
  //                                       ],
  //                                     ),
  //                                   ),
  //                                   SizedBox(width: 12),
  //                                   Expanded(
  //                                     child: Column(
  //                                       crossAxisAlignment: CrossAxisAlignment.start,
  //                                       children: [
  //                                         Text('Sale Price', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
  //                                         SizedBox(height: 6),
  //                                         TextField(
  //                                           controller: _salePriceController,
  //                                           onChanged: (value) => _currentSalePrice = value,
  //                                           keyboardType: TextInputType.numberWithOptions(decimal: true),
  //                                           decoration: InputDecoration(
  //                                             hintText: '\$ 0.00',
  //                                             filled: true,
  //                                             fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  //                                             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                           ),
  //                                         ),
  //                                       ],
  //                                     ),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //
  //                     SizedBox(height: 24),
  //
  //                     // Attribute selection + auto-filled slug field
  //
  //                     Row(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         // Attribute Column
  //                         Expanded(
  //                           flex: 2,
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text(
  //                                 'Attribute',
  //                                 style: TextStyle(
  //                                   fontSize: 12,
  //                                   color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
  //                                 ),
  //                               ),
  //                               SizedBox(height: 8),
  //                               Container(
  //                                 // height: 48,
  //                                 // decoration: BoxDecoration(
  //                                 //   color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
  //                                 //   borderRadius: BorderRadius.circular(6),
  //                                 //   border: Border.all(
  //                                 //     color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
  //                                 //   ),
  //                                 // ),
  //                                 child: InventoryAttributesWithItemsWidget(
  //                                   onAttributeSelected: (attribute) {
  //                                     setState(() {
  //                                       _currentVariantAttribute = {
  //                                         'id': attribute.id,
  //                                         'name': attribute.name,
  //                                         'slug': attribute.slug,
  //                                       };
  //                                       _currentVariantAttributeItem = null;
  //                                       _selectedItemSlug = null;
  //                                     });
  //                                   },
  //                                   onItemSlugSelected: (attribute, slug) {
  //                                     setState(() {
  //                                       _currentVariantAttributeItem = {'slug': slug};
  //                                       _selectedItemSlug = slug;
  //                                     });
  //                                   },
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //
  //                         SizedBox(width: 6),
  //
  //                         // Selected Item Slug Column
  //                         Expanded(
  //                           flex: 1,
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               Text(
  //                                 'Selected Item Slug',
  //                                 style: TextStyle(
  //                                   fontSize: 12,
  //                                   color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
  //                                 ),
  //                               ),
  //                               SizedBox(height: 8),
  //                               TextField(
  //                                 controller: TextEditingController(text: _selectedItemSlug ?? ''),
  //                                 enabled: false,
  //                                 decoration: InputDecoration(
  //                                   hintText: 'Will show selected item slug automatically',
  //                                   filled: true,
  //                                   fillColor: isDark ? Color(0xFF1F1D2B) : Colors.grey.shade100,
  //                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  //                                   contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                 ),
  //                                 style: TextStyle(
  //                                   color: isDark ? Colors.white70 : Colors.black54,
  //                                 ),
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //
  //                     SizedBox(height: 32),
  //
  //                     // Add / Update button
  //                     SizedBox(
  //                       width: double.infinity,
  //                       height: 44,
  //                       child: OutlinedButton(
  //                         onPressed: isVariantsEnabled
  //                             ? () {
  //                           if (_currentVariantName.trim().isEmpty) return;
  //
  //                           setState(() {
  //                             Map<String, dynamic> newVariant = {
  //                               'name': _currentVariantName,
  //                               'stock': _currentStock.isNotEmpty ? _currentStock : '0',
  //                               'regularPrice': _currentRegularPrice.isNotEmpty ? _currentRegularPrice : '0.00',
  //                               'salePrice': _currentSalePrice.isNotEmpty ? _currentSalePrice : '',
  //                               'imageFile': _currentImageFile,
  //                               'attribute': _currentVariantAttribute,
  //                               'attributeItem': _currentVariantAttributeItem,
  //                             };
  //
  //                             if (_currentVariantIndex >= 0) {
  //                               _variants[_currentVariantIndex] = newVariant;
  //                             } else {
  //                               _variants.add(newVariant);
  //                             }
  //
  //                             // Reset
  //                             _currentVariantName = '';
  //                             _currentStock = '';
  //                             _currentRegularPrice = '';
  //                             _currentSalePrice = '';
  //                             _currentImageFile = null;
  //                             _currentVariantAttribute = null;
  //                             _currentVariantAttributeItem = null;
  //                             _selectedItemSlug = null;
  //                             _currentVariantIndex = -1;
  //                             _variantNameController.clear();
  //                             _stockController.clear();
  //                             _regularPriceController.clear();
  //                             _salePriceController.clear();
  //                           });
  //                         }
  //                             : null,
  //                         style: OutlinedButton.styleFrom(
  //                           side: BorderSide(color: isVariantsEnabled ? Color(0xFF00BFA5) : Colors.grey, width: 1.5),
  //                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //                         ),
  //                         child: Text(
  //                           _currentVariantIndex >= 0 ? 'Update Variant' : 'Add New Variant',
  //                           style: TextStyle(
  //                             color: isVariantsEnabled ? Color(0xFF00BFA5) : Colors.grey,
  //                             fontSize: 14,
  //                             fontWeight: FontWeight.w600,
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  //////////----impo


  Widget _buildVariantContent(bool isDark) {
    final bool isVariantsEnabled = (_selectedProductType ?? '').toLowerCase() == 'variable';

    return SingleChildScrollView(
      child: Opacity(
        opacity: isVariantsEnabled ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !isVariantsEnabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 10),
                child: Row(
                  children: [
                    Text(
                      "Variant's ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      isVariantsEnabled ? '(Optional)' : '(Only for Variable products)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isVariantsEnabled ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Warning when not variable
              if (!isVariantsEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red.shade400, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Variants are only available when Product Type is "Variable"',
                          style: TextStyle(
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Existing variants list
              if (_variants.isNotEmpty) ...[
                ..._variants.asMap().entries.map((entry) {
                  int index = entry.key;
                  var variant = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Color(0xFF1F1D2B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            border: Border.all(
                              color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                            ),
                          ),
                          child: variant['imageFile'] != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              variant['imageFile'],
                              fit: BoxFit.cover,
                            ),
                          )
                              : Icon(
                            Icons.image_outlined,
                            size: 24,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Variant Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                        SizedBox(height: 2),
                                        Text(
                                          variant['name'] ?? 'Unnamed',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Stock', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      SizedBox(height: 2),
                                      Text(
                                        variant['stock'] ?? '0',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Regular Price', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                        SizedBox(height: 2),
                                        Text(
                                          '\$ ${variant['regularPrice'] ?? '0.00'}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Sale Price', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                        SizedBox(height: 2),
                                        Text(
                                          '\$ ${variant['salePrice'] ?? '0.00'}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Attributes display - Show all selected attributes
                              if (_getSelectedAttributesForDisplay(variant).isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Attributes:', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ..._getSelectedAttributesForDisplay(variant).map((attrDisplay) {
                                        return Text(
                                          attrDisplay,
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _currentVariantIndex = index;
                                  _currentVariantName = variant['name'] ?? '';
                                  _currentStock = variant['stock'] ?? '';
                                  _currentRegularPrice = variant['regularPrice'] ?? '';
                                  _currentSalePrice = variant['salePrice'] ?? '';
                                  _currentImageFile = variant['imageFile'];

                                  // Load attributes for editing
                                  if (variant['attributes'] != null && (variant['attributes'] as List).isNotEmpty) {
                                    _variantAttributes = List<Map<String, dynamic>>.from(variant['attributes']);
                                  } else if (variant['attribute'] != null) {
                                    // Convert single attribute format to multiple for editing
                                    _variantAttributes = [{
                                      'attribute': variant['attribute'],
                                      'attributeItem': variant['attributeItem'],
                                      'selectedSlug': variant['attributeItem']?['slug'],
                                    }];
                                  } else {
                                    _variantAttributes = [{
                                      'attribute': null,
                                      'attributeItem': null,
                                      'selectedSlug': null,
                                    }];
                                  }

                                  _variantNameController.text = _currentVariantName;
                                  _stockController.text = _currentStock;
                                  _regularPriceController.text = _currentRegularPrice;
                                  _salePriceController.text = _currentSalePrice;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2196F3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2196F3)),
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _variants.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFFEF5350).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF5350)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                SizedBox(height: 12),
              ],

              // Main ADD/EDIT FORM
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Color(0xFF1F1D2B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image + Name/Stock/Price row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Variant Image',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                              SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final XFile? pickedFile = await _picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 200,
                                    maxHeight: 200,
                                    imageQuality: 85,
                                  );
                                  if (pickedFile != null) {
                                    setState(() {
                                      _currentImageFile = File(pickedFile.path);
                                    });
                                  }
                                },
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
                                  ),
                                  child: _currentImageFile != null
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(_currentImageFile!, fit: BoxFit.cover),
                                  )
                                      : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, size: 24, color: Color(0xFF2196F3)),
                                      SizedBox(height: 4),
                                      Text('Upload', style: TextStyle(fontSize: 11, color: Color(0xFF2196F3))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Variant Name', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          SizedBox(height: 6),
                                          TextField(
                                            controller: _variantNameController,
                                            onChanged: (value) => _currentVariantName = value,
                                            decoration: InputDecoration(
                                              hintText: 'Enter name',
                                              filled: true,
                                              fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Stock', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          SizedBox(height: 6),
                                          TextField(
                                            controller: _stockController,
                                            onChanged: (value) => _currentStock = value,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              filled: true,
                                              fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Regular Price', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          SizedBox(height: 6),
                                          TextField(
                                            controller: _regularPriceController,
                                            onChanged: (value) => _currentRegularPrice = value,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              hintText: '\$ 0.00',
                                              filled: true,
                                              fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Sale Price', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                                          SizedBox(height: 6),
                                          TextField(
                                            controller: _salePriceController,
                                            onChanged: (value) => _currentSalePrice = value,
                                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              hintText: '\$ 0.00',
                                              filled: true,
                                              fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Multiple Attributes Section with Add/Remove buttons
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header for attributes
                          Row(
                            children: [
                              Text(
                                'Attributes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '(Optional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          // Dynamic Attribute Rows
                          ..._variantAttributes.asMap().entries.map((entry) {
                            int index = entry.key;
                            var attrData = entry.value;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Attribute Column
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Attribute ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Container(
                                          child: InventoryAttributesWithItemsWidget(
                                            onAttributeSelected: (attribute) {
                                              setState(() {
                                                _variantAttributes[index]['attribute'] = {
                                                  'id': attribute.id,
                                                  'name': attribute.name,
                                                  'slug': attribute.slug,
                                                };
                                                _variantAttributes[index]['attributeItem'] = null;
                                                _variantAttributes[index]['selectedSlug'] = null;
                                              });
                                            },
                                            onItemSlugSelected: (attribute, slug) {
                                              setState(() {
                                                _variantAttributes[index]['attributeItem'] = {'slug': slug};
                                                _variantAttributes[index]['selectedSlug'] = slug;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(width: 6),

                                  // Selected Item Slug Column with Add/Remove buttons
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected Item Slug',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: TextEditingController(
                                                    text: attrData['selectedSlug'] ?? ''
                                                ),
                                                enabled: false,
                                                decoration: InputDecoration(
                                                  hintText: 'Auto-filled slug',
                                                  filled: true,
                                                  fillColor: isDark ? Color(0xFF1F1D2B) : Colors.grey.shade100,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                ),
                                                style: TextStyle(
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Add Button (only on last row)
                                            if (index == _variantAttributes.length - 1)
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _variantAttributes.add({
                                                      'attribute': null,
                                                      'attributeItem': null,
                                                      'selectedSlug': null,
                                                    });
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF2196F3).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: Color(0xFF2196F3), width: 1),
                                                  ),
                                                  child: Icon(
                                                    Icons.add,
                                                    size: 18,
                                                    color: Color(0xFF2196F3),
                                                  ),
                                                ),
                                              ),
                                            // Remove Button (only show if more than one attribute)
                                            if (_variantAttributes.length > 1) ...[
                                              SizedBox(width: 8),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _variantAttributes.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFEF5350).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Color(0xFFEF5350),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),

                      SizedBox(height: 32),

                      // Add / Update button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: isVariantsEnabled
                              ? () {
                            if (_currentVariantName.trim().isEmpty) return;

                            setState(() {
                              // Convert multiple attributes to single attribute format for backend
                              Map<String, dynamic>? singleAttribute;
                              Map<String, dynamic>? singleAttributeItem;

                              // Get the first valid attribute for backend compatibility
                              for (var attr in _variantAttributes) {
                                if (attr['attribute'] != null && attr['attributeItem'] != null) {
                                  singleAttribute = attr['attribute'];
                                  singleAttributeItem = attr['attributeItem'];
                                  break;
                                }
                              }

                              Map<String, dynamic> newVariant = {
                                'name': _currentVariantName,
                                'stock': _currentStock.isNotEmpty ? _currentStock : '0',
                                'regularPrice': _currentRegularPrice.isNotEmpty ? _currentRegularPrice : '0.00',
                                'salePrice': _currentSalePrice.isNotEmpty ? _currentSalePrice : '',
                                'imageFile': _currentImageFile,
                                // For backend compatibility - single attribute
                                'attribute': singleAttribute,
                                'attributeItem': singleAttributeItem,
                                // For UI/display - multiple attributes
                                'attributes': List<Map<String, dynamic>>.from(_variantAttributes),
                              };

                              if (_currentVariantIndex >= 0) {
                                _variants[_currentVariantIndex] = newVariant;
                              } else {
                                _variants.add(newVariant);
                              }

                              // Reset
                              _currentVariantName = '';
                              _currentStock = '';
                              _currentRegularPrice = '';
                              _currentSalePrice = '';
                              _currentImageFile = null;
                              _currentVariantIndex = -1;
                              _variantNameController.clear();
                              _stockController.clear();
                              _regularPriceController.clear();
                              _salePriceController.clear();

                              // Reset attributes
                              _variantAttributes = [{
                                'attribute': null,
                                'attributeItem': null,
                                'selectedSlug': null,
                              }];
                            });
                          }
                              : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isVariantsEnabled ? Color(0xFF00BFA5) : Colors.grey, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            _currentVariantIndex >= 0 ? 'Update Variant' : 'Add New Variant',
                            style: TextStyle(
                              color: isVariantsEnabled ? Color(0xFF00BFA5) : Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper method to get attributes for display
  List<String> _getSelectedAttributesForDisplay(Map<String, dynamic> variant) {
    List<String> displayList = [];

    // First check for multiple attributes
    if (variant['attributes'] != null && (variant['attributes'] as List).isNotEmpty) {
      for (var attr in (variant['attributes'] as List)) {
        if (attr['attribute'] != null && attr['selectedSlug'] != null) {
          displayList.add('${attr['attribute']['name']}: ${attr['selectedSlug']}');
        }
      }
    }
    // Fallback to single attribute
    else if (variant['attribute'] != null) {
      displayList.add('${variant['attribute']['name']} (${variant['attribute']['slug']})');
      if (variant['attributeItem'] != null && variant['attributeItem']['slug'] != null) {
        displayList.add('Slug: ${variant['attributeItem']['slug']}');
      }
    }

    return displayList;
  }


  Widget _buildAuditListTab(bool isDark, bool isSmallScreen) {
    return Center(
      child: Text(
        'Audit List - Feature coming soon',
        style: TextStyle(
          fontSize: 18,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

}