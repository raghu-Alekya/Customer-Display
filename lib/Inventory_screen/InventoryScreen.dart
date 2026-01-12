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
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_bloc.dart';
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_event.dart';
import 'add_product_toinventory/add_product_inventory_bloc/add_product_inventory_state.dart';
import 'add_product_toinventory/add_product_inventory_entity.dart';
import 'add_product_toinventory/add_product_inventory_get_usecase.dart';
import 'add_product_toinventory/add_product_inventory_remote_data_source.dart';
import 'add_product_toinventory/add_product_inventory_repository_impl.dart';
import 'inventory_Tax/inventory_tax_screen.dart';
import 'inventory_attribute_items/inventory_attribute_items_bloc/inventory_attribute_items_bloc.dart';
import 'inventory_attribute_items/inventory_attribute_items_get_usecase.dart';
import 'inventory_attribute_items/inventory_attribute_items_remote_data_source.dart';
import 'inventory_attribute_items/inventory_attribute_items_repository_impl.dart';
import 'inventory_attribute_items/inventory_attribute_items_widget.dart';
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
  bool _ageRestricted = false;
  bool _ebtEligible = false;
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
  List<Map<String, dynamic>> _currentAttributes = [{'id': '1', 'unit': 'units', 'name': 'name'}];
  String _currentVariantName = '';
  String _currentStock = '';
  String _currentRegularPrice = '';
  String _currentSalePrice = '';
  File? _currentImageFile;

  // Add Product BLoC
  late AddProductInventoryTaxBloc _addProductBloc;

  @override
  void initState() {
    super.initState();
    _selectedSidebarIndex = widget.lastSelectedIndex ?? 4;
    shiftBloc = ShiftBloc(ShiftRepository());

    // Initialize Add Product BLoC
    _initializeAddProductBloc();
  }

  void _initializeAddProductBloc() {
    final remoteDataSource = AddProductInventoryTaxRemoteDataSource();
    final repository = AddProductInventoryTaxRepositoryImpl(remoteDataSource: remoteDataSource);
    final useCase = AddProductInventoryTaxGetUseCase(repository: repository);
    _addProductBloc = AddProductInventoryTaxBloc(addProductUseCase: useCase);
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _regularPriceController.dispose();
    _salePriceController.dispose();
    _qtyController.dispose();
    _taxClassController.dispose();
    _addProductBloc.close();
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
      _imageFile = File(image.path);
      _imageBytes = finalBytes;
    });
  }

  // ------------------- UPLOAD IMAGE TO WOOCOMMERCE -------------------
  Future<String?> _uploadImage(String filename, List<int> bytes) async {
    try {
      // WooCommerce Media API endpoint - Replace with your actual endpoint
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

  // ------------------- VALIDATE FORM -------------------
  String? _validateForm() {
    if (_nameController.text.isEmpty) {
      return 'Product name is required';
    }
    if (_selectedCategory == null) {
      return 'Category is required';
    }
    if (_selectedProductType == null || _selectedProductType!.isEmpty) {
      return 'Product type is required';
    }
    if (!_hasVariablePrice) {
      // if (_regularPriceController.text.isEmpty) {
      //   return 'Regular price is required';
      // }
      if (_qtyController.text.isEmpty) {
        return 'Stock quantity is required';
      }
    }
    return null;
  }

  // ------------------- BUILD PRODUCT ENTITY -------------------
  Future<AddProductInventoryTaxEntity?> _buildProductEntity() async {
    // Validate form
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return null;
    }

    // Upload image if exists
    String? imageUrl;
    if (_imageFile != null && _imageBytes != null) {
      imageUrl = await _uploadImage(_imageFile!.path.split('/').last, _imageBytes!);
      if (imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed')),
        );
        return null;
      }
    }

    // Prepare categories
    List<Map<String, dynamic>> categories = [];
    if (_selectedCategory != null) {
      categories.add({
        'id': _selectedCategory.id ?? 0,
        'name': _selectedCategory.name ?? '',
        'slug': _selectedCategory.slug ?? '',
      });
    }

    // Prepare tags
    List<Map<String, dynamic>> tags = [];
    for (var tag in _selectedTags) {
      tags.add({
        'id': tag.id ?? 0,
        'name': tag.name ?? '',
        'slug': tag.slug ?? '',
      });
    }

    // Prepare images
    List<Map<String, dynamic>> images = [];
    if (imageUrl != null) {
      images.add({'src': imageUrl});
    }

    // Prepare variants if product type is variable
    List<Map<String, dynamic>> variantData = [];
    if (_selectedProductType?.toLowerCase() == 'variable' && _variants.isNotEmpty) {
      for (var variant in _variants) {
        variantData.add({
          'name': variant['name'] ?? '',
          'regular_price': variant['regularPrice'] ?? '0.00',
          'sale_price': variant['salePrice'] ?? '',
          'stock_quantity': int.tryParse(variant['stock'] ?? '0') ?? 0,
          'manage_stock': true,
          'attributes': variant['attributes'] ?? [],
        });
      }
    }

    // Create product entity
    return AddProductInventoryTaxEntity(
      id: 0,
      name: _nameController.text,
      type: (_selectedProductType?.toLowerCase() == 'variable') ? 'variable' : 'simple',
      sku: _skuController.text.isEmpty ? 'SKU${DateTime.now().millisecondsSinceEpoch}' : _skuController.text,
      regularPrice: _hasVariablePrice ? '' : _regularPriceController.text,
      salePrice: _hasVariablePrice ? '' : _salePriceController.text,
      categories: categories,
      tags: tags,
      images: images,
      metaData: [
        {'key': 'custom_product', 'value': 'yes'},
        {'key': 'product_created_by', 'value': 1},
        if (_ageRestricted) {'key': 'age_restricted', 'value': 'yes'},
        if (_ebtEligible) {'key': 'ebt_eligible', 'value': 'yes'},
      ],
      manageStock: _manageStock,
      stockQuantity: _hasVariablePrice ? 0 : int.tryParse(_qtyController.text) ?? 0,
      taxStatus: _selectedTax != null ? 'taxable' : 'none',
      taxClass: _selectedTax?.taxClass ?? 'standard',
      // attributes: _currentAttributes,
      // variations: variantData,
      // status: 'publish',
      // description: '',
      // shortDescription: '',
      // weight: '',
      // dimensions: {'length': '', 'width': '', 'height': ''},
      // price: _hasVariablePrice ? '' : _regularPriceController.text,
    );
  }

  // ------------------- SAVE PRODUCT -------------------
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final product = await _buildProductEntity();
    if (product == null) {
      return;
    }

    // Dispatch event to BLoC
    _addProductBloc.add(AddProductInventoryTaxSubmitEvent(product: product));
  }

  // ------------------- CLEAR FORM -------------------
  void _clearForm() {
    _formKey.currentState?.reset();
    _skuController.clear();
    _nameController.clear();
    _regularPriceController.clear();
    _salePriceController.clear();
    _qtyController.clear();
    _taxClassController.clear();

    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _selectedProductType = null;
      _selectedCategory = null;
      _selectedTax = null;
      _selectedTags.clear();
      _ageRestricted = false;
      _ebtEligible = false;
      _hasVariablePrice = false;
      _variants.clear();
      _currentVariantName = '';
      _currentStock = '';
      _currentRegularPrice = '';
      _currentSalePrice = '';
      _currentImageFile = null;
      _currentAttributes = [];
    });
  }

  // ------------------- UI BUILDERS -------------------
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

    return BlocConsumer<AddProductInventoryTaxBloc, AddProductInventoryTaxState>(
      bloc: _addProductBloc,
      listener: (context, state) {
        if (state is AddProductInventoryTaxLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product Added: ${state.product.name}'),
              backgroundColor: Colors.green,
            ),
          );
          _clearForm(); // Clear form after successful submission
        } else if (state is AddProductInventoryTaxError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        bool isLoading = state is AddProductInventoryTaxLoading;

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
                                  ? _buildAddProductTab(isDark, isSmallScreen, isMediumScreen, isLargeScreen, isExtraLargeScreen, isLoading)
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
      },
    );
  }

  Widget _buildAddProductTab(bool isDark, bool isSmallScreen, bool isMediumScreen, bool isLargeScreen, bool isExtraLargeScreen, bool isLoading) {
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

            // Error message display (from validation)
            if (_validateForm() != null && _formKey.currentState?.validate() == false)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validateForm()!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _clearForm,
                  child: Text('Clear', style: TextStyle(color: Color(0xFF2196F3), fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF2196F3), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 30 : 50, vertical: 16),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : _saveProduct,
                  child: isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text('Save & Update', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter product name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Product name is required';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryCategoriesDropdown(
          onCategorySelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
            if (category != null) {
              debugPrint('Parent received category -> ID: ${category.id}, Name: ${category.name}');
            } else {
              debugPrint('No category selected');
            }
          },
        ),
        SizedBox(height: 16),
        Text('Product Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryGetProductTypesWidget(
          onTypeSelected: (selectedType) {
            setState(() {
              _selectedProductType = selectedType;
            });
            print('Parent received selected type: $selectedType');
          },
        ),
        SizedBox(height: 16),
        _buildPriceSection(isDark),
        SizedBox(height: 16),
        Text('Tax', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        InventoryTaxDropdownWidget(
          onTaxSelected: (tax) {
            setState(() {
              _selectedTax = tax;
            });
            if (tax != null) {
              debugPrint('Parent received selected Tax -> ID: ${tax.id}, Name: ${tax.name}, taxClass: ${tax.taxClass}');
            }
          },
        ),
        SizedBox(height: 16),
        Text('Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        TextFormField(
          controller: _qtyController,
          keyboardType: TextInputType.number,
          enabled: !_hasVariablePrice,
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            filled: true,
            fillColor: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          validator: (value) {
            if (!_hasVariablePrice && (value == null || value.isEmpty)) {
              return 'Stock quantity is required';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        SizedBox(height: 8),
        InventoryTagMultiSelectWidget(
          onTypeSelected: (tag) {
            if (tag != null) {
              setState(() {
                _selectedTags.add(tag);
              });
              debugPrint('Parent received selected tag -> id: ${tag.id}, name: ${tag.name}, slug: ${tag.slug}');
            } else {
              debugPrint('No tag selected');
            }
          },
        ),
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
        Expanded(
          flex: 3,
          child: Card(
            color: Theme.of(context).cardColor,
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF89B1EE) : const Color(0xFFF5F7FA),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),),
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
                        Text(
                          'Product Image',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SKU',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF252837) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
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
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Generate the Sku',
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.white24 : Colors.black26,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
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
                                      'SKU${DateTime.now().millisecondsSinceEpoch}';
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
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Product name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
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
                            if (category != null) {
                              debugPrint(
                                  'Parent received category -> ID: ${category.id}, Name: ${category.name}');
                            } else {
                              debugPrint('No category selected');
                            }
                          },
                        ),
                        const SizedBox(height: 8),
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
                            print('Parent received selected type: $selectedType');
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

        SizedBox(width: 24),

        Expanded(
          flex: 3,
          child: Material(
            color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFDAC14A) : const Color(0xFFFFFBF0),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Regular Price',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextFormField(
                                    controller: _regularPriceController,
                                    enabled: !_hasVariablePrice,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                      color: _hasVariablePrice
                                          ? (isDark ? Colors.white38 : Colors.black38)
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                    decoration: const InputDecoration(
                                      prefixText: '\$  ',
                                      hintText: '00.00',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    ),
                                    // validator: (value) {
                                    //   if (!_hasVariablePrice && (value == null || value.isEmpty)) {
                                    //     return 'Regular price is required';
                                    //   }
                                    //   return null;
                                    // },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sale Price',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  TextFormField(
                                    controller: _salePriceController,
                                    enabled: !_hasVariablePrice,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: TextStyle(
                                      color: _hasVariablePrice
                                          ? (isDark ? Colors.white38 : Colors.black38)
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                    decoration: const InputDecoration(
                                      prefixText: '\$  ',
                                      hintText: '00.00',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _hasVariablePrice,
                                onChanged: (val) {
                                  setState(() {
                                    _hasVariablePrice = val ?? false;
                                    if (_hasVariablePrice) {
                                      _regularPriceController.clear();
                                      _salePriceController.clear();
                                      _qtyController.clear();
                                    }
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                  color: isDark ? Colors.white38 : const Color(0xFFBDBDBD),
                                  width: 2,
                                ),
                                checkColor: Colors.white,
                                fillColor: MaterialStateProperty.all(const Color(0xFF2196F3)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            RichText(
                              text: TextSpan(
                                text: 'If the product has ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Variable Price',
                                    style: TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tax',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InventoryTaxDropdownWidget(
                          onTaxSelected: (tax) {
                            setState(() {
                              _selectedTax = tax;
                            });
                            if (tax != null) {
                              debugPrint('Parent received selected Tax -> ID: ${tax.id}, Name: ${tax.name}, taxClass: ${tax.taxClass}');
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stock',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _qtyController,
                          enabled: !_hasVariablePrice,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: _hasVariablePrice
                                ? (isDark ? Colors.white38 : Colors.black38)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter quantity',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          validator: (value) {
                            if (!_hasVariablePrice && (value == null || value.isEmpty)) {
                              return 'Stock quantity is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InventoryTagMultiSelectWidget(
                          onTypeSelected: (tag) {
                            if (tag != null) {
                              setState(() {
                                _selectedTags.add(tag);
                              });
                              debugPrint('Parent received selected tag -> id: ${tag.id}, name: ${tag.name}, slug: ${tag.slug}');
                            }
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

  Widget _buildProductImageSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Product Image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: isSmallScreen ? double.infinity : 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
              border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
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
                Text('Upload Image', style: TextStyle(color: Color(0xFF2196F3), fontSize: 12)),
              ],
            )
                : null,
          ),
        ),
        SizedBox(height: 4),
        Text('Please upload a clear image of the item', style: TextStyle(fontSize: 10, color: Colors.grey.shade400), textAlign: TextAlign.center),
        Text('Max File Size : 200KB', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildSKUSection(bool isDark, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SKU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
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

  Widget _buildPriceField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
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
              borderSide: BorderSide(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          // validator: (value) {
          //   if (!_hasVariablePrice && (value == null || value.isEmpty)) {
          //     return 'Regular price is required';
          //   }
          //   return null;
          // },
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
    final bool isVariantsEnabled = (_selectedProductType ?? '').toLowerCase() == 'variable';

    return Opacity(
      opacity: isVariantsEnabled ? 1.0 : 0.45,
      child: IgnorePointer(
        ignoring: !isVariantsEnabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    color: isVariantsEnabled
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height:12),

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
                                      Text(
                                        'Variant Name',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        variant['name'] ?? 'Unnamed',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Column(
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
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
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
                                      Text(
                                        'Regular Price',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '\$ ${variant['regularPrice'] ?? '0.00'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
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
                                        '\$ ${variant['salePrice'] ?? '0.00'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
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
                      SizedBox(width: 12),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _currentVariantName = variant['name'] ?? '';
                                _currentStock = variant['stock'] ?? '';
                                _currentRegularPrice = variant['regularPrice'] ?? '';
                                _currentSalePrice = variant['salePrice'] ?? '';
                                _currentImageFile = variant['imageFile'];
                                _currentAttributes = List<Map<String, dynamic>>.from(
                                  variant['attributes'] ?? [
                                    {'id': '1', 'unit': 'units', 'name': 'name'}
                                  ],
                                );
                                _variants.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF2196F3).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Color(0xFF2196F3),
                              ),
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
                              child: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFEF5350),
                              ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            onTap: () async {
                              final XFile? pickedFile = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 800,
                                maxHeight: 800,
                                imageQuality: 85,
                              );
                              if (pickedFile != null) {
                                setState(() {
                                  _currentImageFile = File(pickedFile.path);
                                });
                              }
                            },
                            child: Container(
                              width: 80,
                              height: 120,
                              decoration: BoxDecoration(
                                color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0),
                                ),
                              ),
                              child: _currentImageFile != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _currentImageFile!,
                                  width: 80,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              )
                                  : Column(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
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
                                        controller: TextEditingController(text: _currentVariantName),
                                        onChanged: (value) {
                                          setState(() {
                                            _currentVariantName = value;
                                          });
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
                                SizedBox(width: 12),
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
                                        controller: TextEditingController(text: _currentStock),
                                        onChanged: (value) {
                                          setState(() {
                                            _currentStock = value;
                                          });
                                        },
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: '0',
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
                            Row(
                              children: [
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
                                        controller: TextEditingController(text: _currentRegularPrice),
                                        onChanged: (value) {
                                          setState(() {
                                            _currentRegularPrice = value;
                                          });
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
                                SizedBox(width: 12),
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
                                        controller: TextEditingController(text: _currentSalePrice),
                                        onChanged: (value) {
                                          setState(() {
                                            _currentSalePrice = value;
                                          });
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Attributes',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  ..._currentAttributes.asMap().entries.map((entry) {
                    int attrIndex = entry.key;
                    var attribute = entry.value;

                    return Row(
                      children: [
                        Expanded(
                          child: InventoryAttributesDropdown(
                            onAttributeSelected: (attribute) {
                              print('Selected ID : ${attribute.id}');
                              print('Selected Name : ${attribute.name}');
                              print('Selected Slug : ${attribute.slug}');
                              print('Selected Type : ${attribute.type}');
                            },
                          ),
                        ),
                        SizedBox(width: 1),

                        // Expanded(
                        //   child:
                        //   // InventoryAttributesDropdown(
                        //   //   onAttributeSelected: (attribute) {
                        //   //     Navigator.push(
                        //   //       context,
                        //   //       MaterialPageRoute(
                        //   //         builder: (_) => BlocProvider(
                        //   //           create: (context) => InventoryAttributeItemsBloc(
                        //   //             getItemsUseCase: GetInventoryAttributeItemsUseCase(
                        //   //               repository: InventoryAttributeItemsRepositoryImpl(
                        //   //                 remoteDataSource: InventoryAttributeItemsRemoteDataSourceImpl(client: http.Client()),
                        //   //               ),
                        //   //             ),
                        //   //           ),
                        //   //           child: InventoryAttributeItemsDropdown(
                        //   //             attributeId: attribute.id,
                        //   //             onItemSelected: (item) {
                        //   //               print('Selected Item: ${item.name}');
                        //   //             },
                        //   //           ),
                        //   //         ),
                        //   //       ),
                        //   //     );
                        //   //   },
                        //   // ),
                        // ),

                        SizedBox(width: 1),
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(text: attribute['name']),
                            onChanged: (value) {
                              setState(() {
                                _currentAttributes[attrIndex]['name'] = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Unit Name',
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
                        ),
                        SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (attrIndex == _currentAttributes.length - 1) {
                                _currentAttributes.add({
                                  'id': (_currentAttributes.length + 1).toString(),
                                  'unit': 'units',
                                  'name': 'name'
                                });
                              } else {
                                _currentAttributes.removeAt(attrIndex);
                              }
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 40,
                            decoration: BoxDecoration(
                              color: attrIndex == _currentAttributes.length - 1
                                  ? Color(0xFF2196F3)
                                  : Color(0xFFEF5350),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              attrIndex == _currentAttributes.length - 1
                                  ? Icons.add
                                  : Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: isVariantsEnabled
                          ? () {
                        if (_currentVariantName.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter variant name'),
                              backgroundColor: Color(0xFFEF5350),
                            ),
                          );
                          return;
                        }

                        setState(() {
                          Map<String, dynamic> newVariant = {
                            'name': _currentVariantName,
                            'stock': _currentStock.isNotEmpty ? _currentStock : '0',
                            'regularPrice': _currentRegularPrice.isNotEmpty ? _currentRegularPrice : '0.00',
                            'salePrice': _currentSalePrice.isNotEmpty ? _currentSalePrice : '0.00',
                            'attributes': List<Map<String, dynamic>>.from(_currentAttributes),
                            'imageFile': _currentImageFile,
                          };

                          _variants.add(newVariant);

                          // Reset form
                          _currentVariantName = '';
                          _currentStock = '';
                          _currentRegularPrice = '';
                          _currentSalePrice = '';
                          _currentAttributes = [
                            {'id': '1', 'unit': 'units', 'name': 'name'}
                          ];
                          _currentImageFile = null;
                        });
                      }
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isVariantsEnabled ? Color(0xFF00BFA5) : Colors.grey,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Add New Variant',
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
          ],
        ),
      ),
    );
  }

  Widget _buildAuditListTab(bool isDark, bool isSmallScreen) {
    // This would show the list of added products
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

  Widget _buildToggleCard(String title, String subtitle, bool value, Function(bool) onChanged, bool isDark) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF252837) : Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Color(0xFF3B4259) : Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: Color(0xFF2196F3),
            side: BorderSide(color: isDark ? Colors.white38 : Colors.black38),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
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
}