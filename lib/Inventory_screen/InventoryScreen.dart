// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../Constants/text.dart';
// import '../../Database/user_db_helper.dart';
// import '../../Helper/Extentions/nav_layout_manager.dart';
// import '../../Helper/Extentions/theme_notifier.dart';
// import '../../Preferences/pinaka_preferences.dart';
// import '../../Widgets/widget_topbar.dart';
// import '../../Widgets/widget_navigation_bar.dart' as custom_widgets;
// import '../Blocs/Auth/shift_bloc.dart';
// import '../Database/db_helper.dart';
// import '../Models/Auth/shift_summary_model.dart';
// import '../Repositories/Auth/shift_repository.dart';
// import 'Inventory_Tags/inventory_tag_Widget.dart';
// import 'inventory_Tax/inventory_tax_screen.dart';
//
// class InventoryScreen extends StatefulWidget {
//   final int? lastSelectedIndex;
//   const InventoryScreen({super.key, this.lastSelectedIndex});
//
//   @override
//   State<InventoryScreen> createState() => _InventoryScreenState();
// }
//
// class _InventoryScreenState extends State<InventoryScreen> with LayoutSelectionMixin {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _skuController = TextEditingController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _productTypeController = TextEditingController();
//   final TextEditingController _regularPriceController = TextEditingController();
//   final TextEditingController _salePriceController = TextEditingController();
//   final TextEditingController _qtyController = TextEditingController();
//
//   String? _selectedCategory;
//   final List<String> _categories = ['Electronics', 'Clothing', 'Food', 'Books', 'Other'];
//   String _selectedQtyType = 'Units';
//   final List<String> _qtyTypes = ['Units', 'Kg', 'Liter', 'Pieces'];
//   String? _selectedTax;
//   bool _ageRestricted = false;
//   bool _ebtEligible = false;
//   final List<Map<String, dynamic>> _inventory = [];
//   int _selectedTab = 0;
//   int _selectedSidebarIndex = 4;
//   late ShiftBloc shiftBloc;
//   final PinakaPreferences _preferences = PinakaPreferences();
//   List<Shift> _cachedShifts = [];
//   bool _isDataLoaded = false;
//   String _priceType = 'Fixed Price';
//
//   // Variants List
//   List<Map<String, dynamic>> _variants = [];
//   final TextEditingController _variantNameController = TextEditingController();
//   final TextEditingController _variantPriceController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
//     shiftBloc = ShiftBloc(ShiftRepository());
//   }
//
//   Widget _buildTabButton(String text, int index, ThemeNotifier themeHelper) {
//     bool isSelected = _selectedTab == index;
//     return GestureDetector(
//       onTap: () => setState(() => _selectedTab = index),
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFF2196F3) : Colors.transparent,
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Text(
//           text,
//           style: TextStyle(
//             color: isSelected ? Colors.white : (themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.black54),
//             fontSize: 14,
//             fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _addVariant() {
//     if (_variantNameController.text.isNotEmpty && _variantPriceController.text.isNotEmpty) {
//       setState(() {
//         _variants.add({
//           'name': _variantNameController.text,
//           'price': _variantPriceController.text,
//         });
//         _variantNameController.clear();
//         _variantPriceController.clear();
//       });
//     }
//   }
//
//   void _deleteVariant(int index) {
//     setState(() {
//       _variants.removeAt(index);
//     });
//   }
//
//   void _editVariant(int index) {
//     setState(() {
//       _variantNameController.text = _variants[index]['name'];
//       _variantPriceController.text = _variants[index]['price'];
//       _variants.removeAt(index);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final themeHelper = Provider.of<ThemeNotifier>(context);
//     final isDark = themeHelper.themeMode == ThemeMode.dark;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     // Responsive breakpoints
//     bool isSmallScreen = screenWidth < 768;
//     bool isMediumScreen = screenWidth >= 768 && screenWidth < 1024;
//     bool isLargeScreen = screenWidth >= 1024 && screenWidth < 1440;
//     bool isExtraLargeScreen = screenWidth >= 1440;
//
//     return Scaffold(
//       backgroundColor: isDark ? Color(0xFF1F1D2B) : Color(0xFFF5F5F5),
//       body: Column(
//         children: [
//           TopBar(
//             screen: Screen.SHIFT,
//             onModeChanged: () async {
//               String newLayout;
//               if (sidebarPosition == SidebarPosition.left) {
//                 newLayout = SharedPreferenceTextConstants.navRightOrderLeft;
//               } else if (sidebarPosition == SidebarPosition.right) {
//                 newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
//               } else {
//                 newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
//               }
//               PinakaPreferences.layoutSelectionNotifier.value = newLayout;
//               await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
//               setState(() {});
//             },
//           ),
//           const Divider(color: Colors.grey, thickness: 0.4, height: 1),
//           Expanded(
//             child: Row(
//               children: [
//                 if (sidebarPosition == SidebarPosition.left)
//                   custom_widgets.NavigationBar(
//                     selectedSidebarIndex: _selectedSidebarIndex,
//                     onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
//                     isVertical: true,
//                   ),
//                 Expanded(
//                   child: Container(
//                     margin: EdgeInsets.all(isSmallScreen ? 5 : 10),
//                     decoration: BoxDecoration(
//                       color: isDark ? Color(0xFF1F1D2B) : Colors.white,
//                       borderRadius: BorderRadius.circular(6.0),
//                     ),
//                     child: Column(
//                       children: [
//                         Padding(
//                           padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
//                           child: Row(
//                             children: [
//                               Container(
//                                 height: 45,
//                                 decoration: BoxDecoration(color: Color(0xFF3B4259), borderRadius: BorderRadius.circular(6.0)),
//                                 child: TextButton.icon(
//                                   onPressed: () => Navigator.pop(context),
//                                   icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
//                                   label: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
//                                   style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
//                                 ),
//                               ),
//                               const SizedBox(width: 16),
//                               Container(
//                                 height: 45,
//                                 decoration: BoxDecoration(
//                                   color: isDark ? Color(0xFF252837) : Colors.grey[200],
//                                   borderRadius: BorderRadius.circular(6.0),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     _buildTabButton('Add Product', 0, themeHelper),
//                                     _buildTabButton('Audit list', 1, themeHelper),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         Expanded(
//                           child: _selectedTab == 0
//                               ? _buildAddProductTab(isDark, isSmallScreen, isMediumScreen, isLargeScreen, isExtraLargeScreen)
//                               : _buildAuditListTab(isDark, isSmallScreen),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 if (sidebarPosition == SidebarPosition.right)
//                   custom_widgets.NavigationBar(
//                     selectedSidebarIndex: _selectedSidebarIndex,
//                     onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
//                     isVertical: true,
//                   ),
//               ],
//             ),
//           ),
//           if (sidebarPosition == SidebarPosition.bottom)
//             custom_widgets.NavigationBar(
//               selectedSidebarIndex: _selectedSidebarIndex,
//               onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
//               isVertical: false,
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAddProductTab(bool isDark, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen, bool isExtraLargeScreen) {
//     return SingleChildScrollView(
//       padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16, vertical: 8),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           children: [
//             isSmallScreen || isMediumScreen
//                 ? _buildMobileLayout(isDark, isSmallScreen)
//                 : _buildDesktopLayout(isDark, isLargeScreen, isExtraLargeScreen),
//             SizedBox(height: 32),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 OutlinedButton(
//                   onPressed: () {
//                     _formKey.currentState?.reset();
//                     _skuController.clear();
//                     _nameController.clear();
//                     _productTypeController.clear();
//                     _regularPriceController.clear();
//                     _salePriceController.clear();
//                     _qtyController.clear();
//                     _variantNameController.clear();
//                     _variantPriceController.clear();
//                     setState(() {
//                       _selectedCategory = null;
//                       _selectedTax = null;
//                       _ageRestricted = false;
//                       _ebtEligible = false;
//                       _variants.clear();
//                     });
//                   },
//                   child: Text('Clear', style: TextStyle(color: Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.w600)),
//                   style: OutlinedButton.styleFrom(
//                     side: BorderSide(color: Color(0xFF2196F3), width: 2),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//                     padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 30 : 50, vertical: 16),
//                   ),
//                 ),
//                 SizedBox(width: 16),
//                 ElevatedButton(
//                   onPressed: () {
//                     if (_formKey.currentState!.validate()) {
//                       setState(() {
//                         _inventory.add({
//                           'sku': _skuController.text,
//                           'name': _nameController.text,
//                           'productType': _productTypeController.text,
//                           'regularPrice': _regularPriceController.text,
//                           'salePrice': _salePriceController.text,
//                           'quantity': _qtyController.text,
//                           'qtyType': _selectedQtyType,
//                           'category': _selectedCategory,
//                           'tax': _selectedTax,
//                           'ageRestricted': _ageRestricted,
//                           'ebtEligible': _ebtEligible,
//                           'variants': List.from(_variants),
//                         });
//                       });
//                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product added successfully!'), backgroundColor: Color(0xFF4CAF50)));
//                     }
//                   },
//                   child: Text('Save & Update', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF2196F3),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//                     padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 30 : 50, vertical: 16),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMobileLayout(bool isDark, bool isSmallScreen) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildProductImageSection(isDark, isSmallScreen),
//         SizedBox(height: 16),
//         _buildSKUSection(isDark, isSmallScreen),
//         SizedBox(height: 16),
//         Text('Product Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         _buildTextField(_nameController, 'Enter product name', isDark),
//         SizedBox(height: 16),
//         Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         _buildDropdown(_selectedCategory, 'Please select the category', _categories, (val) => setState(() => _selectedCategory = val), isDark),
//         SizedBox(height: 16),
//         Text('Product Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         _buildDropdown(_productTypeController.text.isEmpty ? null : _productTypeController.text, 'Select product type', ['variants', 'simple', 'digital'], (val) {
//           setState(() => _productTypeController.text = val ?? '');
//         }, isDark),
//         SizedBox(height: 16),
//         Text('Qty Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(flex: 2, child: _buildTextField(_qtyController, 'Enter Qty', isDark, inputType: TextInputType.number)),
//             SizedBox(width: 8),
//             Expanded(child: _buildDropdown(_selectedQtyType, '', _qtyTypes, (val) => setState(() => _selectedQtyType = val!), isDark, hasValue: true)),
//           ],
//         ),
//         SizedBox(height: 24),
//         _buildPriceSection(isDark),
//         SizedBox(height: 16),
//         Text('Tax', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//
//         InventoryTaxDropdownWidget(),
//
//         SizedBox(height: 8),
//
//         InventoryTagMultiSelectWidget(),
//         // _buildDropdown(_selectedTax, 'Select the tax', _taxOptions, (val) => setState(() => _selectedTax = val), isDark),
//         // SizedBox(height: 16),
//         // _buildToggleCard('Age Restricted', 'Turn on if age verification is required.', _ageRestricted, (val) => setState(() => _ageRestricted = val), isDark),
//         // SizedBox(height: 12),
//         // _buildToggleCard('EBT Eligible', 'EBT eligible items are non-taxable.', _ebtEligible, (val) => setState(() => _ebtEligible = val), isDark),
//         // SizedBox(height: 16),
//         _buildVariantSection(isDark, isSmallScreen),
//       ],
//     );
//   }
//
//   Widget _buildDesktopLayout(bool isDark, bool isLargeScreen, bool isExtraLargeScreen) {
//     double variantBoxWidth = isExtraLargeScreen ? 400 : (isLargeScreen ? 380 : 350);
//
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//           flex: 2,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text('Product Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                       SizedBox(height: 8),
//                       Container(
//                         width: 120,
//                         height: 120,
//                         decoration: BoxDecoration(
//                           // border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.dashed),
//                           borderRadius: BorderRadius.circular(8),
//                           color: isDark ? Color(0xFF252837) : Colors.grey[50],
//                         ),
//                         child: Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey.shade400)),
//                       ),
//                       SizedBox(height: 8),
//                       SizedBox(
//                         width: 120,
//                         child: ElevatedButton.icon(
//                           onPressed: () {},
//                           icon: Icon(Icons.upload, size: 16, color: Colors.white),
//                           label: Text('Upload', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Color(0xFF2196F3),
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//                             padding: EdgeInsets.symmetric(vertical: 10),
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: 4),
//                       SizedBox(
//                         width: 120,
//                         child: Text('Please upload a clear image\nof the item', style: TextStyle(fontSize: 10, color: Colors.grey.shade500), textAlign: TextAlign.center),
//                       ),
//                       Text('Max File Size : 200KB', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
//                     ],
//                   ),
//                   SizedBox(width: 24),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('SKU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         SizedBox(height: 8),
//                         Container(
//                           height: 48,
//                           decoration: BoxDecoration(
//                             color: isDark ? const Color(0xFF252837) : Colors.grey[100],
//                             borderRadius: BorderRadius.circular(6),
//                           ),
//                           child: Row(
//                             children: [
//                               // Text field
//                               Expanded(
//                                 child: TextFormField(
//                                   controller: _skuController,
//                                   style: TextStyle(
//                                     color: isDark ? Colors.white : Colors.black87,
//                                     fontSize: 14,
//                                   ),
//                                   decoration: InputDecoration(
//                                     hintText: 'Generate the SKU',
//                                     hintStyle: TextStyle(
//                                       color: Colors.grey.shade400,
//                                       fontSize: 13,
//                                     ),
//                                     border: InputBorder.none,
//                                     contentPadding: const EdgeInsets.symmetric(
//                                       horizontal: 16,
//                                       vertical: 12,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//
//                               // Generate button with background
//                               Container(
//                                 height: double.infinity,
//                                 decoration: const BoxDecoration(
//                                   color: Color(0xFFEF5350),
//                                   borderRadius: BorderRadius.only(
//                                     topRight: Radius.circular(6),
//                                     bottomRight: Radius.circular(6),
//                                   ),
//                                 ),
//                                 child: TextButton(
//                                   onPressed: () {
//                                     setState(() {
//                                       _skuController.text =
//                                       'SKU${DateTime.now().millisecondsSinceEpoch}';
//                                     });
//                                   },
//                                   style: TextButton.styleFrom(
//                                     padding: const EdgeInsets.symmetric(horizontal: 20),
//                                     foregroundColor: Colors.white,
//                                   ),
//                                   child: const Text(
//                                     'Generate',
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         SizedBox(height: 16),
//                         Text('Product Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         SizedBox(height: 8),
//                         _buildTextField(_nameController, 'Enter product name', isDark),
//                         SizedBox(height: 16),
//                         Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         SizedBox(height: 8),
//                         _buildDropdown(_selectedCategory, 'Please select the category', _categories, (val) => setState(() => _selectedCategory = val), isDark),
//                         SizedBox(height: 16),
//                         Text('Product Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         SizedBox(height: 8),
//                         _buildDropdown(_productTypeController.text.isEmpty ? null : _productTypeController.text, 'Select product type', ['variants', 'simple', 'digital'], (val) {
//                           setState(() => _productTypeController.text = val ?? '');
//                         }, isDark),
//                         SizedBox(height: 16),
//                         Text('Qty Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         SizedBox(height: 8),
//                         Row(
//                           children: [
//                             Expanded(flex: 2, child: _buildTextField(_qtyController, 'Enter Qty', isDark, inputType: TextInputType.number)),
//                             SizedBox(width: 8),
//                             Expanded(child: _buildDropdown(_selectedQtyType, '', _qtyTypes, (val) => setState(() => _selectedQtyType = val!), isDark, hasValue: true)),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         SizedBox(width: 24),
//         Expanded(
//           flex: 2,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildPriceSection(isDark),
//               SizedBox(height: 16),
//               Text('Tax', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//               SizedBox(height: 8),
//               InventoryTaxDropdownWidget(),
//               // _buildDropdown(_selectedTax, 'Select the tax', _taxOptions, (val) => setState(() => _selectedTax = val), isDark),
//               SizedBox(height: 8),
//
//               // Text('Tags', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//               // SizedBox(height: 8),
//               InventoryTagMultiSelectWidget(),
//               // SizedBox(height: 16),
//               // _buildToggleCard('Age Restricted', 'Turn on if age verification is required.', _ageRestricted, (val) => setState(() => _ageRestricted = val), isDark),
//               // SizedBox(height: 12),
//               // _buildToggleCard('EBT Eligible', 'EBT eligible items are non-taxable.', _ebtEligible, (val) => setState(() => _ebtEligible = val), isDark),
//             ],
//           ),
//         ),
//         SizedBox(width: 24),
//         // Variant Section (Right Side Box)
//         Container(
//           width: variantBoxWidth,
//           padding: EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: isDark ? Color(0xFF1E3A5F) : Color(0xFFE3F2FD),
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: isDark ? Color(0xFF2196F3) : Color(0xFF90CAF9), width: 1),
//           ),
//           child: _buildVariantContent(isDark),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildPriceSection(bool isDark) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 4),
//         Text('Choose how the price is set for this item', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
//         SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: InkWell(
//                 onTap: () => setState(() => _priceType = 'Fixed Price'),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: _priceType == 'Fixed Price' ? Color(0xFF2196F3) : Colors.grey.shade300, width: 2),
//                     borderRadius: BorderRadius.circular(6),
//                     color: isDark ? Color(0xFF252837) : Colors.white,
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 20,
//                         height: 20,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(color: _priceType == 'Fixed Price' ? Color(0xFF2196F3) : Colors.grey.shade400, width: 2),
//                         ),
//                         child: _priceType == 'Fixed Price'
//                             ? Center(
//                           child: Container(
//                             width: 10,
//                             height: 10,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: Color(0xFF2196F3),
//                             ),
//                           ),
//                         )
//                             : null,
//                       ),
//                       SizedBox(width: 8),
//                       Text('Fixed Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(width: 12),
//             Expanded(
//               child: InkWell(
//                 onTap: () => setState(() => _priceType = 'Variable Price'),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: _priceType == 'Variable Price' ? Color(0xFF2196F3) : Colors.grey.shade300, width: 2),
//                     borderRadius: BorderRadius.circular(6),
//                     color: isDark ? Color(0xFF252837) : Colors.white,
//                   ),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 20,
//                         height: 20,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           border: Border.all(color: _priceType == 'Variable Price' ? Color(0xFF2196F3) : Colors.grey.shade400, width: 2),
//                         ),
//                         child: _priceType == 'Variable Price'
//                             ? Center(
//                           child: Container(
//                             width: 10,
//                             height: 10,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               color: Color(0xFF2196F3),
//                             ),
//                           ),
//                         )
//                             : null,
//                       ),
//                       SizedBox(width: 8),
//                       Text('Variable Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 16),
//         Row(
//           children: [
//             Expanded(child: _buildPriceField('Regular Price', _regularPriceController, isDark)),
//             SizedBox(width: 16),
//             Expanded(child: _buildPriceField('Sale Price', _salePriceController, isDark)),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildProductImageSection(bool isDark, bool isSmallScreen) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Text('Product Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         Container(
//           width: isSmallScreen ? double.infinity : 140,
//           height: 140,
//           decoration: BoxDecoration(
//             // border: Border.all(color: Colors.grey.shade400, width: 2, style: BorderStyle.dashed),
//             borderRadius: BorderRadius.circular(8),
//             color: isDark ? Color(0xFF252837) : Colors.grey[50],
//           ),
//           child: Center(child: Icon(Icons.add_photo_alternate_outlined, size: 50, color: Colors.grey.shade400)),
//         ),
//         SizedBox(height: 8),
//         SizedBox(
//           width: isSmallScreen ? double.infinity : 140,
//           child: ElevatedButton.icon(
//             onPressed: () {},
//             icon: Icon(Icons.upload, size: 18, color: Colors.white),
//             label: Text('Upload', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Color(0xFF2196F3),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//               padding: EdgeInsets.symmetric(vertical: 10),
//             ),
//           ),
//         ),
//         SizedBox(height: 4),
//         Text('Please upload a clear image of the item', style: TextStyle(fontSize: 11, color: Colors.grey.shade500), textAlign: TextAlign.center),
//         Text('Max File Size : 200KB', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//       ],
//     );
//   }
//
//   Widget _buildSKUSection(bool isDark, bool isSmallScreen) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('SKU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: Container(
//                 height: 48,
//                 child: TextFormField(
//                   controller: _skuController,
//                   style: TextStyle(color: isDark ? Colors.white : Colors.black87),
//                   decoration: InputDecoration(
//                     hintText: 'Generate the Sku',
//                     hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
//                     filled: true,
//                     fillColor: isDark ? Color(0xFF252837) : Colors.grey[100],
//                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
//                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(width: 8),
//             Container(
//               height: 48,
//               child: ElevatedButton(
//                 onPressed: () => setState(() => _skuController.text = 'SKU${DateTime.now().millisecondsSinceEpoch}'),
//                 child: Text('Generate', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Color(0xFFEF5350),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//                   padding: EdgeInsets.symmetric(horizontal: 24),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
//
//   Widget _buildVariantSection(bool isDark, bool isSmallScreen) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isDark ? Color(0xFF1E3A5F) : Color(0xFFE3F2FD),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: isDark ? Color(0xFF2196F3) : Color(0xFF90CAF9), width: 1),
//       ),
//       child: _buildVariantContent(isDark),
//     );
//   }
//
//   Widget _buildVariantContent(bool isDark) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text('Variant\'s ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//             Text('(Optional)', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
//           ],
//         ),
//         SizedBox(height: 16),
//         // Display added variants
//         ..._variants.asMap().entries.map((entry) {
//           int index = entry.key;
//           var variant = entry.value;
//           return Container(
//             margin: EdgeInsets.only(bottom: 12),
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: isDark ? Color(0xFF1F1D2B) : Colors.white,
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: isDark ? Color(0xFF3B4259) : Colors.grey.shade300),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   width: 50,
//                   height: 50,
//                   decoration: BoxDecoration(
//                     // border: Border.all(color: Colors.grey.shade400, style: BorderStyle.dashed),
//                     borderRadius: BorderRadius.circular(6),
//                     color: isDark ? Color(0xFF252837) : Colors.grey[100],
//                   ),
//                   child: Icon(Icons.add_photo_alternate_outlined, size: 24, color: Colors.grey.shade400),
//                 ),
//                 SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Text('Name : ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                           Expanded(child: Text(variant['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
//                         ],
//                       ),
//                       SizedBox(height: 4),
//                       Row(
//                         children: [
//                           Text('Price : ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                           Text(variant['price'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 Column(
//                   children: [
//                     InkWell(
//                       onTap: () => _editVariant(index),
//                       child: Container(
//                         padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: Color(0xFF2196F3).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.edit, size: 13, color: Color(0xFF2196F3)),
//                             SizedBox(width: 4),
//                             Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF2196F3), fontWeight: FontWeight.w600)),
//                           ],
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 6),
//                     InkWell(
//                       onTap: () => _deleteVariant(index),
//                       child: Container(
//                         padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: Color(0xFFEF5350).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(Icons.delete, size: 13, color: Color(0xFFEF5350)),
//                             SizedBox(width: 4),
//                             Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFEF5350), fontWeight: FontWeight.w600)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//         // Add new variant form
//         Container(
//           padding: EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: isDark ? Color(0xFF1F1D2B) : Colors.white,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: isDark ? Color(0xFF3B4259) : Colors.grey.shade300),
//           ),
//           child: Column(
//             children: [
//               Row(
//                 children: [
//                   Container(
//                     width: 50,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       // border: Border.all(color: Colors.grey.shade400, style: BorderStyle.dashed),
//                       borderRadius: BorderRadius.circular(6),
//                       color: isDark ? Color(0xFF252837) : Colors.grey[100],
//                     ),
//                     child: Icon(Icons.add_photo_alternate_outlined, size: 24, color: Colors.grey.shade400),
//                   ),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       children: [
//                         Row(
//                           children: [
//                             Text('Name :', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Container(
//                                 height: 35,
//                                 child: TextFormField(
//                                   controller: _variantNameController,
//                                   style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
//                                   decoration: InputDecoration(
//                                     hintText: 'Enter item name',
//                                     hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
//                                     filled: true,
//                                     fillColor: isDark ? Color(0xFF252837) : Colors.grey[100],
//                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
//                                     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         SizedBox(height: 8),
//                         Row(
//                           children: [
//                             Text('Price :', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Container(
//                                 height: 35,
//                                 child: TextFormField(
//                                   controller: _variantPriceController,
//                                   keyboardType: TextInputType.number,
//                                   style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
//                                   decoration: InputDecoration(
//                                     hintText: 'Enter price',
//                                     hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
//                                     filled: true,
//                                     fillColor: isDark ? Color(0xFF252837) : Colors.grey[100],
//                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
//                                     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 height: 36,
//                 child: ElevatedButton(
//                   onPressed: _addVariant,
//                   child: Text('Save', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Color(0xFF90A4AE),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         SizedBox(height: 12),
//         OutlinedButton.icon(
//           onPressed: () {
//             setState(() {
//               _variants.add({'name': '', 'price': ''});
//             });
//           },
//           icon: Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF4CAF50)),
//           label: Text('Add', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.w600)),
//           style: OutlinedButton.styleFrom(
//             side: BorderSide(color: Color(0xFF4CAF50)),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
//             minimumSize: Size(double.infinity, 38),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildAuditListTab(bool isDark, bool isSmallScreen) {
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             decoration: BoxDecoration(
//               color: isDark ? Color(0xFF252837) : Colors.grey[200],
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Table(
//               columnWidths: {
//                 0: FlexColumnWidth(1.5),
//                 1: FlexColumnWidth(2),
//                 2: FlexColumnWidth(1.5),
//                 3: FlexColumnWidth(1.5),
//                 4: FlexColumnWidth(1.5),
//                 5: FlexColumnWidth(1),
//                 6: FlexColumnWidth(1.5),
//               },
//               children: [
//                 TableRow(
//                   decoration: BoxDecoration(
//                     color: isDark ? Color(0xFF3B4259) : Colors.grey[400],
//                     borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
//                   ),
//                   children: [
//                     _buildTableHeader('Date', isDark),
//                     _buildTableHeader('Product Name', isDark),
//                     _buildTableHeader('SKU', isDark),
//                     _buildTableHeader('Category', isDark),
//                     _buildTableHeader('Qty', isDark),
//                     _buildTableHeader('Price', isDark),
//                     _buildTableHeader('Status', isDark),
//                   ],
//                 ),
//                 ..._inventory.map((item) {
//                   return TableRow(
//                     decoration: BoxDecoration(
//                       border: Border(bottom: BorderSide(color: isDark ? Color(0xFF3B4259) : Colors.grey[300]!, width: 0.5)),
//                     ),
//                     children: [
//                       _buildTableCell(DateTime.now().toString().substring(0, 10), isDark),
//                       _buildTableCell(item['name'] ?? 'N/A', isDark),
//                       _buildTableCell(item['sku'] ?? 'N/A', isDark),
//                       _buildTableCell(item['category'] ?? 'N/A', isDark),
//                       _buildTableCell('${item['quantity']} ${item['qtyType']}', isDark),
//                       // _buildTableCell('\${item['regularPrice']}', isDark),
//                       _buildStatusCell('Active', isDark),
//                     ],
//                   );
//                 }).toList(),
//               ],
//             ),
//           ),
//           if (_inventory.isEmpty)
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(40.0),
//                 child: Column(
//                   children: [
//                     Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
//                     SizedBox(height: 16),
//                     Text(
//                       'No products added yet',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Add your first product to see it in the audit list',
//                       style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTableHeader(String text, bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//       child: Text(
//         text,
//         style: TextStyle(
//           fontSize: 14,
//           fontWeight: FontWeight.w700,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTableCell(String text, bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//       child: Text(
//         text,
//         style: TextStyle(
//           fontSize: 13,
//           color: isDark ? Colors.white : Colors.black87,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildStatusCell(String status, bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: Color(0xFF4CAF50).withOpacity(0.1),
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Text(
//           status,
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF4CAF50),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTextField(TextEditingController controller, String hint, bool isDark, {IconData? suffixIcon, TextInputType? inputType}) {
//     return Container(
//       height: 48,
//       child: TextFormField(
//         controller: controller,
//         keyboardType: inputType,
//         style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
//         decoration: InputDecoration(
//           hintText: hint,
//           hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
//           filled: true,
//           fillColor: isDark ? Color(0xFF252837) : Colors.grey[100],
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
//           suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey, size: 20) : null,
//           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPriceField(String label, TextEditingController controller, bool isDark) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
//         SizedBox(height: 8),
//         _buildTextField(controller, 'Enter item price', isDark, inputType: TextInputType.number),
//       ],
//     );
//   }
//
//   Widget _buildDropdown(String? value, String hint, List<String> items, Function(String?) onChanged, bool isDark, {bool hasValue = false}) {
//     return Container(
//       height: 48,
//       child: DropdownButtonFormField<String>(
//         value: hasValue ? value : null,
//         hint: Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
//         dropdownColor: isDark ? Color(0xFF252837) : Colors.white,
//         style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
//         decoration: InputDecoration(
//           filled: true,
//           fillColor: isDark ? Color(0xFF252837) : Colors.grey[100],
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
//           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         ),
//         items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
//         onChanged: onChanged,
//       ),
//     );
//   }
//
// }




import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import 'inventory_Tax/inventory_tax_screen.dart';
import 'inventory_categories/inventory_categories_widgets.dart';

class InventoryScreen extends StatefulWidget {
  final int? lastSelectedIndex;
  const InventoryScreen({super.key, this.lastSelectedIndex});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with LayoutSelectionMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _productTypeController = TextEditingController();
  final TextEditingController _regularPriceController = TextEditingController();
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  String? _selectedCategory;
  final List<String> _categories = ['Electronics', 'Clothing', 'Food', 'Books', 'Other'];
  String _selectedQtyType = 'Units';
  final List<String> _qtyTypes = ['Units', 'Kg', 'Liter', 'Pieces'];
  String? _selectedTax;
  final List<String> _taxOptions = ['No Tax', 'GST 5%', 'GST 12%', 'GST 18%', 'GST 28%'];
  bool _ageRestricted = false;
  bool _ebtEligible = false;
  final List<Map<String, dynamic>> _inventory = [];
  int _selectedTab = 0;
  int _selectedSidebarIndex = 4;
  late ShiftBloc shiftBloc;
  final PinakaPreferences _preferences = PinakaPreferences();
  List<Shift> _cachedShifts = [];
  bool _isDataLoaded = false;
  String _priceType = 'Fixed Price';
  bool _hasVariablePrice = false;

  // Variants List
  List<Map<String, dynamic>> _variants = [];
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  final TextEditingController _variantStockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    shiftBloc = ShiftBloc(ShiftRepository());
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60, // compress image
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
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
            color: isSelected ? Colors.white : (themeHelper.themeMode == ThemeMode.dark ? Colors.white70 : Colors.black54),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _addVariant() {
    if (_variantNameController.text.isNotEmpty && _variantPriceController.text.isNotEmpty) {
      setState(() {
        _variants.add({
          'name': _variantNameController.text,
          'price': _variantPriceController.text,
          'stock': _variantStockController.text.isEmpty ? '0' : _variantStockController.text,
        });
        _variantNameController.clear();
        _variantPriceController.clear();
        _variantStockController.clear();
      });
    }
  }

  void _deleteVariant(int index) {
    setState(() {
      _variants.removeAt(index);
    });
  }

  void _editVariant(int index) {
    setState(() {
      _variantNameController.text = _variants[index]['name'];
      _variantPriceController.text = _variants[index]['price'];
      _variantStockController.text = _variants[index]['stock'] ?? '0';
      _variants.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    final isDark = themeHelper.themeMode == ThemeMode.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive breakpoints
    bool isSmallScreen = screenWidth < 768;
    bool isMediumScreen = screenWidth >= 768 && screenWidth < 1024;
    bool isLargeScreen = screenWidth >= 1024 && screenWidth < 1440;
    bool isExtraLargeScreen = screenWidth >= 1440;

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
                newLayout = SharedPreferenceTextConstants.navBottomOrderLeft;
              } else {
                newLayout = SharedPreferenceTextConstants.navLeftOrderRight;
              }
              PinakaPreferences.layoutSelectionNotifier.value = newLayout;
              await UserDbHelper().saveUserSettings({AppDBConst.layoutSelection: newLayout}, modeChange: true);
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
                    onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
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
                          padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),
                          child: Row(
                            children: [
                              Container(
                                height: 45,
                                decoration: BoxDecoration(color: Color(0xFF3B4259), borderRadius: BorderRadius.circular(6.0)),
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                                  label: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: isDark ? Color(0xFF252837) : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Row(
                                  children: [
                                    _buildTabButton('Add Product', 0, themeHelper),
                                    _buildTabButton('Audit list', 1, themeHelper),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _selectedTab == 0
                              ? _buildAddProductTab(isDark, isSmallScreen, isMediumScreen, isLargeScreen, isExtraLargeScreen)
                              : _buildAuditListTab(isDark, isSmallScreen),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sidebarPosition == SidebarPosition.right)
                  custom_widgets.NavigationBar(
                    selectedSidebarIndex: _selectedSidebarIndex,
                    onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
                    isVertical: true,
                  ),
              ],
            ),
          ),
          if (sidebarPosition == SidebarPosition.bottom)
            custom_widgets.NavigationBar(
              selectedSidebarIndex: _selectedSidebarIndex,
              onSidebarItemSelected: (index) => setState(() => _selectedSidebarIndex = index),
              isVertical: false,
            ),
        ],
      ),
    );
  }

  Widget _buildAddProductTab(bool isDark, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen, bool isExtraLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16, vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            isSmallScreen || isMediumScreen
                ? _buildMobileLayout(isDark, isSmallScreen)
                : _buildDesktopLayout(isDark, isLargeScreen, isExtraLargeScreen),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _formKey.currentState?.reset();
                    _skuController.clear();
                    _nameController.clear();
                    _productTypeController.clear();
                    _regularPriceController.clear();
                    _salePriceController.clear();
                    _qtyController.clear();
                    _variantNameController.clear();
                    _variantPriceController.clear();
                    _variantStockController.clear();
                    setState(() {
                      _selectedCategory = null;
                      _selectedTax = null;
                      _ageRestricted = false;
                      _ebtEligible = false;
                      _hasVariablePrice = false;
                      _variants.clear();
                    });
                  },
                  child: Text('Clear', style: TextStyle(color: Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF2196F3), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 30 : 50, vertical: 16),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _inventory.add({
                          'sku': _skuController.text,
                          'name': _nameController.text,
                          'productType': _productTypeController.text,
                          'regularPrice': _regularPriceController.text,
                          'salePrice': _salePriceController.text,
                          'quantity': _qtyController.text,
                          'qtyType': _selectedQtyType,
                          'category': _selectedCategory,
                          'tax': _selectedTax,
                          'ageRestricted': _ageRestricted,
                          'ebtEligible': _ebtEligible,
                          'variants': List.from(_variants),
                        });
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product added successfully!'), backgroundColor: Color(0xFF4CAF50)));
                    }
                  },
                  child: Text('Save & Update', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 30 : 50, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductImageSection(isDark, isSmallScreen),
        SizedBox(height: 16),
        _buildSKUSection(isDark, isSmallScreen),
        SizedBox(height: 16),
        Text('Product Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        _buildTextField(_nameController, 'Enter product name', isDark),
        SizedBox(height: 16),
        Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        // InventoryCategoriesDropdown(),
        // _buildDropdown(_selectedCategory, 'Please select the category', _categories, (val) => setState(() => _selectedCategory = val), isDark),
        SizedBox(height: 16),
        Text('Product Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        _buildDropdown(_productTypeController.text.isEmpty ? null : _productTypeController.text, 'Select product type', ['variants', 'simple', 'digital'], (val) {
          setState(() => _productTypeController.text = val ?? '');
        }, isDark),
        SizedBox(height: 16),
        _buildPriceSection(isDark),
        SizedBox(height: 16),
        Text('Tax', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryTaxDropdownWidget(),
        SizedBox(height: 16),
        Text('Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        _buildTextField(_qtyController, 'Enter quantity', isDark, inputType: TextInputType.number),
        SizedBox(height: 16),
        // _buildToggleCard('Age Restricted', 'Age verification required', _ageRestricted, (val) => setState(() => _ageRestricted = val), isDark),
        // SizedBox(height: 12),
        // _buildToggleCard('EBT Eligible', 'Non-taxable item', _ebtEligible, (val) => setState(() => _ebtEligible = val), isDark),
        // SizedBox(height: 8),
        InventoryTagMultiSelectWidget(),
        SizedBox(height: 16),
        _buildVariantSection(isDark, isSmallScreen),
      ],
    );
  }

  Widget _buildDesktopLayout(bool isDark, bool isLargeScreen, bool isExtraLargeScreen) {
    double variantBoxWidth = isExtraLargeScreen ? 420 : (isLargeScreen ? 400 : 380);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expanded(
        //   flex: 3,
        //   child:
        //   Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       // Section Title
        //       Text(
        //         'Basic Information',
        //         style: TextStyle(
        //           fontSize: 18,
        //           fontWeight: FontWeight.w600,
        //           color: isDark ? Colors.white : Colors.black87,
        //         ),
        //       ),
        //       SizedBox(height: 20),
        //       Row(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           Column(
        //             crossAxisAlignment: CrossAxisAlignment.start,
        //             children: [
        //               Text('Product Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        //               SizedBox(height: 8),
        //               Container(
        //                 width: 120,
        //                 height: 120,
        //                 decoration: BoxDecoration(
        //                   borderRadius: BorderRadius.circular(8),
        //                   color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
        //                   border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
        //                 ),
        //                 child: Column(
        //                   mainAxisAlignment: MainAxisAlignment.center,
        //                   children: [
        //                     Icon(Icons.image_outlined, size: 36, color: Color(0xFF2196F3)),
        //                   ],
        //                 ),
        //               ),
        //               SizedBox(height: 8),
        //               SizedBox(
        //                 width: 120,
        //                 child: ElevatedButton.icon(
        //                   onPressed: () {},
        //                   icon: Icon(Icons.upload, size: 14, color: Colors.white),
        //                   label: Text('Upload Image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        //                   style: ElevatedButton.styleFrom(
        //                     backgroundColor: Color(0xFF2196F3),
        //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        //                     padding: EdgeInsets.symmetric(vertical: 10),
        //                   ),
        //                 ),
        //               ),
        //               SizedBox(height: 6),
        //               SizedBox(
        //                 width: 120,
        //                 child: Text(
        //                   'Please upload a clear image\nof the item',
        //                   style: TextStyle(fontSize: 10, color: Colors.grey.shade400, height: 1.3),
        //                   textAlign: TextAlign.center,
        //                 ),
        //               ),
        //               Text('Max File Size : 200KB', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
        //             ],
        //           ),
        //           SizedBox(width: 20),
        //           Expanded(
        //             child: Column(
        //               crossAxisAlignment: CrossAxisAlignment.start,
        //               children: [
        //                 Text('SKU', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        //                 SizedBox(height: 8),
        //                 Container(
        //                   height: 44,
        //                   decoration: BoxDecoration(
        //                     color: isDark ? const Color(0xFF252837) : Color(0xFFF8F9FA),
        //                     borderRadius: BorderRadius.circular(6),
        //                     border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
        //                   ),
        //                   child: Row(
        //                     children: [
        //                       Expanded(
        //                         child: TextFormField(
        //                           controller: _skuController,
        //                           style: TextStyle(
        //                             color: isDark ? Colors.white : Colors.black87,
        //                             fontSize: 13,
        //                           ),
        //                           decoration: InputDecoration(
        //                             hintText: 'Generate the Sku',
        //                             hintStyle: TextStyle(
        //                               color: Colors.grey.shade400,
        //                               fontSize: 12,
        //                             ),
        //                             border: InputBorder.none,
        //                             contentPadding: const EdgeInsets.symmetric(
        //                               horizontal: 14,
        //                               vertical: 12,
        //                             ),
        //                           ),
        //                         ),
        //                       ),
        //                       Container(
        //                         height: double.infinity,
        //                         decoration: const BoxDecoration(
        //                           color: Color(0xFFEA3D8F),
        //                           borderRadius: BorderRadius.only(
        //                             topRight: Radius.circular(6),
        //                             bottomRight: Radius.circular(6),
        //                           ),
        //                         ),
        //                         child: TextButton(
        //                           onPressed: () {
        //                             setState(() {
        //                               _skuController.text = 'SKU${DateTime.now().millisecondsSinceEpoch}';
        //                             });
        //                           },
        //                           style: TextButton.styleFrom(
        //                             padding: const EdgeInsets.symmetric(horizontal: 20),
        //                             foregroundColor: Colors.white,
        //                           ),
        //                           child: const Text(
        //                             'Generate',
        //                             style: TextStyle(
        //                               fontSize: 12,
        //                               fontWeight: FontWeight.w600,
        //                             ),
        //                           ),
        //                         ),
        //                       ),
        //                     ],
        //                   ),
        //                 ),
        //                 SizedBox(height: 14),
        //                 Text('Product Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        //                 SizedBox(height: 8),
        //                 _buildTextField(_nameController, 'Enter the name', isDark),
        //                 SizedBox(height: 14),
        //                 Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        //                 SizedBox(height: 8),
        //                 _buildDropdown(_selectedCategory, 'Please select the category', _categories, (val) => setState(() => _selectedCategory = val), isDark),
        //                 SizedBox(height: 14),
        //                 Text('Product Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        //                 SizedBox(height: 8),
        //                 _buildDropdown(_productTypeController.text.isEmpty ? null : _productTypeController.text, 'Please select the type', ['variants', 'simple', 'digital'], (val) {
        //                   setState(() => _productTypeController.text = val ?? '');
        //                 }, isDark),
        //               ],
        //             ),
        //           ),
        //         ],
        //       ),
        //     ],
        //   ),
        // ),

        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// SECTION TITLE
              Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              /// PRODUCT IMAGE
              Text(
                'Product Image',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? const Color(0xFF252837) : const Color(0xFFF8F9FA),
                    border: Border.all(
                      color: isDark ? const Color(0xFF3B4259) : const Color(0xFFE0E0E0),
                    ),
                    image: _imageFile != null
                        ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _imageFile == null
                      ? const Icon(
                    Icons.image_outlined,
                    size: 36,
                    color: Color(0xFF2196F3),
                  )
                      : null,
                ),
              ),

              const SizedBox(height: 6),
              const Text(
                'Tap to upload image (Max 200KB)',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              /// SKU
              Text(
                'SKU',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252837) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B4259) : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skuController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Generate the SKU',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF6067C),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _skuController.text =
                            'SKU${DateTime.now().millisecondsSinceEpoch}';
                          });
                        },
                        child: const Text(
                          'Generate',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,color:Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              /// PRODUCT NAME
              Text(
                'Product Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(_nameController, 'Enter the name', isDark),

              const SizedBox(height: 14),

              /// CATEGORY
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),

              InventoryCategoriesDropdown(),

              // _buildDropdown(
              //   _selectedCategory,
              //   'Please select the category',
              //   _categories,
              //       (val) => setState(() => _selectedCategory = val),
              //   isDark,
              // ),

              // InventoryCategoriesDropdown(),

              const SizedBox(height: 14),

              /// PRODUCT TYPE
              Text(
                'Product Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                _productTypeController.text.isEmpty
                    ? null
                    : _productTypeController.text,
                'Please select the type',
                ['variants', 'simple', 'digital'],
                    (val) => setState(() => _productTypeController.text = val ?? ''),
                isDark,
              ),
            ],
          ),
        ),

        SizedBox(width: 24),

        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Text(
                'Pricing & Tax',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Regular Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
                        SizedBox(height: 8),
                        _buildPriceTextField(_regularPriceController, '00.00', isDark),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sale Price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
                        SizedBox(height: 8),
                        _buildPriceTextField(_salePriceController, '00.00', isDark),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _hasVariablePrice,
                    onChanged: (val) => setState(() => _hasVariablePrice = val ?? false),
                    activeColor: Color(0xFF2196F3),
                    side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                  Text(
                    'If the product has Variable Price',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
              SizedBox(height: 14),
              Text('Tax', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
              SizedBox(height: 8),
              InventoryTaxDropdownWidget(),
              SizedBox(height: 14),
              Text('Stock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
              SizedBox(height: 8),
              _buildTextField(_qtyController, 'Enter quantity', isDark, inputType: TextInputType.number),
              SizedBox(height: 14),
              // _buildToggleCard('Age Restricted', 'Age verification required', _ageRestricted, (val) => setState(() => _ageRestricted = val), isDark),
              // SizedBox(height: 10),
              // _buildToggleCard('EBT Eligible', 'Non-taxable items', _ebtEligible, (val) => setState(() => _ebtEligible = val), isDark),
              // SizedBox(height: 14),
              InventoryTagMultiSelectWidget(),
            ],
          ),
        ),

        SizedBox(width: 24),

        SizedBox(width: 24),
        Container(
          width: variantBoxWidth,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF1E3A5F) : Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Color(0xFF2196F3) : Color(0xFFBBDEFB), width: 1),
          ),
          child: _buildVariantContent(isDark),
        ),
      ],
    );
  }

  Widget _buildPriceSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPriceField('Regular Price', _regularPriceController, isDark)),
            SizedBox(width: 16),
            Expanded(child: _buildPriceField('Sale Price', _salePriceController, isDark)),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _hasVariablePrice,
              onChanged: (val) => setState(() => _hasVariablePrice = val ?? false),
              activeColor: Color(0xFF2196F3),
              side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
            ),
            Expanded(
              child: Text(
                'If the product has Variable Price',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildProductImageSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Product Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        Container(
          width: isSmallScreen ? double.infinity : 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
            border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 40, color: Color(0xFF2196F3)),
            ],
          ),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: isSmallScreen ? double.infinity : 140,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.upload, size: 16, color: Colors.white),
            label: Text('Upload Image', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text('Please upload a clear image of the item', style: TextStyle(fontSize: 10, color: Colors.grey.shade400), textAlign: TextAlign.center),
        Text('Max File Size : 200KB', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

// CONTINUATION OF THE PREVIOUS FILE - Helper Widget Methods

  Widget _buildSKUSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SKU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                child: TextFormField(
                  controller: _skuController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Generate the Sku',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Container(
              height: 48,
              child: ElevatedButton(
                onPressed: () => setState(() => _skuController.text = 'SKU${DateTime.now().millisecondsSinceEpoch}'),
                child: Text('Generate', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFEA3D8F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariantSection(bool isDark, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E3A5F) : Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Color(0xFF2196F3) : Color(0xFFBBDEFB), width: 1),
      ),
      child: _buildVariantContent(isDark),
    );
  }

  Widget _buildVariantContent(bool isDark) {
    // Local list to track attributes for the current variant being created
    List<Map<String, dynamic>> _currentAttributes = [{'id': '1', 'unit': 'units', 'name': 'name'}];

    // Local state for current variant fields
    String _currentVariantName = '';
    String _currentStock = '';
    String _currentRegularPrice = '';
    String _currentSalePrice = '';
    String? _currentImageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Variant\'s ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '(Optional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Variant input form
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF1F1D2B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Variant Image, Name, Stock Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variant Image
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variant Image',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          // Handle image upload
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 24,
                                color: Color(0xFF2196F3),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Upload Image',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  // Variant Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Variant Name',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          onChanged: (value) {
                            _currentVariantName = value;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter variant name',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Color(0xFF2196F3),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  // Stock
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          onChanged: (value) {
                            _currentStock = value;
                          },
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter quantity',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Color(0xFF2196F3),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Regular Price and Sale Price Row
              Row(
                children: [
                  // Regular Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Regular Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          onChanged: (value) {
                            _currentRegularPrice = value;
                          },
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '\$ 0.00',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Color(0xFF2196F3),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  // Sale Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sale Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          onChanged: (value) {
                            _currentSalePrice = value;
                          },
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '\$ 0.00',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Color(0xFF2196F3),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Display all attributes
              ..._currentAttributes.asMap().entries.map((entry) {
                int attrIndex = entry.key;
                var attribute = entry.value;

                return Padding(
                  padding: EdgeInsets.only(bottom: attrIndex == _currentAttributes.length - 1 ? 0 : 16),
                  child: Row(
                    children: [
                      // Attribute 1 Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attrIndex == 0 ? 'Attributes' : '',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: attrIndex == 0 ? 8 : 20),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    attribute['id'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Select',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Attribute 2 Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: attrIndex == 0 ? 20 : 0),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    attribute['unit'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Name Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: attrIndex == 0 ? 20 : 0),
                            TextField(
                              onChanged: (value) {
                                _currentAttributes[attrIndex]['name'] = value;
                              },
                              decoration: InputDecoration(
                                hintText: 'name',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade400,
                                ),
                                filled: true,
                                fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                    color: Color(0xFF2196F3),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Add/Remove Button
                      Column(
                        children: [
                          SizedBox(height: attrIndex == 0 ? 20 : 0),
                          InkWell(
                            onTap: () {
                              if (attrIndex == _currentAttributes.length - 1) {
                                // Add new attribute
                                _currentAttributes.add({
                                  'id': (_currentAttributes.length + 1).toString(),
                                  'unit': 'units',
                                  'name': 'name'
                                });
                              } else {
                                // Remove attribute
                                _currentAttributes.removeAt(attrIndex);
                              }
                            },
                            child: Container(
                              width: 32,
                              height: 35,
                              decoration: BoxDecoration(
                                color: attrIndex == _currentAttributes.length - 1
                                    ? Color(0xFF2196F3)
                                    : Color(0xFFEF5350),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                attrIndex == _currentAttributes.length - 1
                                    ? Icons.add
                                    : Icons.remove,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Display added variants
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                    border: Border.all(
                      color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                    ),
                  ),
                  child: variant.containsKey('imageUrl') && variant['imageUrl'] != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      variant['imageUrl'],
                      fit: BoxFit.cover,
                    ),
                  )
                      : Icon(
                    Icons.image_outlined,
                    size: 20,
                    color: Color(0xFF2196F3),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Variant Name',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        variant['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Regular Price',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '\$ ${variant['regularPrice'] ?? variant['price']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sale Price',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '\$ ${variant['salePrice'] ?? variant['price']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stock',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  variant['stock'] ?? '0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Attributes',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          ...(variant['attributes'] as List<Map<String, dynamic>>?)?.map((attr) {
                            return Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Color(0xFF252837) : Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        attr['id'] ?? '1',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        attr['name'] ?? 'Select',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '(${attr['unit'] ?? 'units'})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList() ?? [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              margin: EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Color(0xFF252837) : Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Select',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '(units)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Spacer(),
                          InkWell(
                            onTap: () => _deleteVariant(index),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFFEF5350),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        SizedBox(height: 8),
        // Add new variant button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              // Add variant logic
              if (_currentVariantName.isNotEmpty) {
                // Create new variant from current form data
                Map<String, dynamic> newVariant = {
                  'name': _currentVariantName,
                  'stock': _currentStock.isNotEmpty ? _currentStock : '0',
                  'regularPrice': _currentRegularPrice.isNotEmpty ? _currentRegularPrice : '0.00',
                  'salePrice': _currentSalePrice.isNotEmpty ? _currentSalePrice : '0.00',
                  'attributes': List<Map<String, dynamic>>.from(_currentAttributes),
                  'imageUrl': _currentImageUrl,
                };

                // Add to variants list
                // Note: You'll need to make _variants accessible in this scope
                // or pass it as a parameter to the widget

                // Reset form
                _currentVariantName = '';
                _currentStock = '';
                _currentRegularPrice = '';
                _currentSalePrice = '';
                _currentAttributes = [{'id': '1', 'unit': 'units', 'name': 'name'}];

                // Trigger UI update
                // You might need to use StatefulWidget or pass a callback to update parent state
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 0,
            ),
            child: Text(
              '+ Add New Variant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddVariantDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1F1D2B) : Colors.white,
        title: Text('Add Variant', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _variantNameController,
              decoration: InputDecoration(
                labelText: 'Variant Name',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _variantPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Price',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _variantStockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stock',
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _addVariant();
              Navigator.pop(context);
            },
            child: Text('Add', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditListTab(bool isDark, bool isSmallScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF252837) : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Table(
              columnWidths: {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark ? Color(0xFF3B4259) : Colors.grey[400],
                    borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                  children: [
                    _buildTableHeader('Date', isDark),
                    _buildTableHeader('Product Name', isDark),
                    _buildTableHeader('SKU', isDark),
                    _buildTableHeader('Category', isDark),
                    _buildTableHeader('Qty', isDark),
                    _buildTableHeader('Price', isDark),
                    _buildTableHeader('Status', isDark),
                  ],
                ),
                ..._inventory.map((item) {
                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Color(0xFF3B4259) : Colors.grey[300]!, width: 0.5)),
                    ),
                    children: [
                      _buildTableCell(DateTime.now().toString().substring(0, 10), isDark),
                      _buildTableCell(item['name'] ?? 'N/A', isDark),
                      _buildTableCell(item['sku'] ?? 'N/A', isDark),
                      _buildTableCell(item['category'] ?? 'N/A', isDark),
                      _buildTableCell('${item['quantity']} ${item['qtyType']}', isDark),
                      _buildTableCell('\$${item['regularPrice']}', isDark),
                      _buildStatusCell('Active', isDark),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
          if (_inventory.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                    SizedBox(height: 16),
                    Text(
                      'No products added yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add your first product to see it in the audit list',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4CAF50),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, {IconData? suffixIcon, TextInputType? inputType}) {
    return Container(
      height: 44,
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          filled: true,
          fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Color(0xFF2196F3)),
          ),
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey, size: 20) : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPriceTextField(TextEditingController controller, String hint, bool isDark) {
    return Container(
      height: 44,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          filled: true,
          fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Color(0xFF2196F3)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPriceField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
        SizedBox(height: 8),
        _buildPriceTextField(controller, '\$ 00.00', isDark),
      ],
    );
  }

  Widget _buildDropdown(String? value, String hint, List<String> items, Function(String?) onChanged, bool isDark, {bool hasValue = false}) {
    return Container(
      height: 44,
      child: DropdownButtonFormField<String>(
        value: hasValue ? value : null,
        hint: Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        dropdownColor: isDark ? Color(0xFF252837) : Colors.white,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 12),
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Color(0xFF2196F3)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildToggleCard(String title, String subtitle, bool value, Function(bool) onChanged, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }
}