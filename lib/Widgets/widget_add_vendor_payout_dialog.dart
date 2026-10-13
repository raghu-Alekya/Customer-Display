import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:provider/provider.dart';
import '../Blocs/Auth/vendor_payment_bloc.dart';
import '../Database/assets_db_helper.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Helper/api_response.dart';
import '../Models/Assets/asset_model.dart';
import '../Models/Auth/shift_summary_model.dart';
import '../Models/Auth/vendor_payment_model.dart';
import '../Repositories/Auth/vendor_payment_repository.dart';
import 'package:flutter/services.dart';



class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Keep only digits
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) digits = '0';

    // Convert last digits into decimal format
    double value = double.parse(digits) / 100;

    final newText = value.toStringAsFixed(2);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class AddVendorPayoutDialog extends StatefulWidget {
  final VendorPaymentBloc vendorPaymentBloc;
  final Function(VendorPaymentRequest) onAdd;
  final int shiftId;
  final List<Vendor> vendors; // List of vendors
  final List<String> paymentTypes; // Payment types list
  final List<String> purposes; // Purposes list
  final VendorPayout? payment;

  const AddVendorPayoutDialog({
    Key? key,
    required this.onAdd,
    required this.shiftId,
    required this.vendors,
    required this.paymentTypes,
    required this.purposes,
    this.payment,
    required this.vendorPaymentBloc,
  }) : super(key: key);

  @override
  State<AddVendorPayoutDialog> createState() => _AddVendorPayoutDialogState();
}

class _AddVendorPayoutDialogState extends State<AddVendorPayoutDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Vendor? _selectedVendor;
  String? _selectedPaymentType;
  String? _selectedPurpose;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with provided data
    if (widget.payment != null) {
      // Pre-fill fields for editing
      _amountController.text = widget.payment!.amount.toString();
      _notesController.text = widget.payment!.note;
      _selectedPaymentType = widget.payment!.paymentMethod;
      _selectedPurpose = widget.payment!.serviceType;
      // Set selected vendor based on vendor_id
      if (widget.payment != null) {
        try {
          if (widget.vendors.isNotEmpty) {
            _selectedVendor = widget.vendors.firstWhere(
                  (vendor) => vendor.id.toString() == widget.payment!.vendorId,
              orElse: () => widget.vendors.first,
            );
            if (_selectedVendor!.id == 0) {
              if (kDebugMode) print("AddVendorPayoutDialog: Selected vendor has ID 0, resetting to null");
              _selectedVendor = null;
            }
          }
        } catch (e) {
          if (kDebugMode) print("AddVendorPayoutDialog: Error setting selected vendor: $e");
        }
      }
    }
    if (kDebugMode) {
      print("AddVendorPayoutDialog: Initialized${widget.payment != null ? ' for editing payment ID ${widget.payment!.id}' : ''}");
      print("Available vendors: ${widget.vendors.map((v) => 'ID: ${v.id}, Name: ${v.vendorName}').toList()}");
    }
  }


  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleAdd() async { //Build #1.0.74
    // Validate inputs
    if (_amountController.text.isEmpty) {
      _showErrorSnackBar('Please enter an amount');
      return;
    }

    if (_selectedVendor == null) {
      _showErrorSnackBar('Please select a vendor');
      return;
    }

    if (_selectedPaymentType == null) {
      _showErrorSnackBar('Please select a payment type');
      return;
    }

    if (_selectedPurpose == null) {
      _showErrorSnackBar('Please select a purpose');
      return;
    }

    // Parse amount
    double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Create vendor payment request
    final request = VendorPaymentRequest( //Build #1.0.74
      title: 'Payment for vendor id #${_selectedVendor!.id}',
      vendorId: _selectedVendor!.id,
      amount: amount,
      paymentMethod: _selectedPaymentType!,
      shiftId: widget.shiftId,
      serviceType: _selectedPurpose!,
      notes: _notesController.text.isNotEmpty
          ? _notesController.text
          : 'Paid in full, $_selectedPurpose',
      vendorPaymentId: widget.payment?.id, // Include vendor_payment_id for updates
    );

    if (kDebugMode) {
      print("AddVendorPayoutDialog: Submitting request: ${request.toJson()}");
    }

    // Call the callback function
    await widget.onAdd(request);

    setState(() {
      _isLoading = false;
    });

    // Close dialog
    Navigator.of(context).pop();
  }

  void _showErrorSnackBar(String message) {
    if (kDebugMode) print("AddVendorPayoutDialog: Error - $message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return StreamBuilder<APIResponse<VendorPaymentResponse>>( //Build #1.0.74
      stream: widget.payment == null
          ? widget.vendorPaymentBloc.createVendorPaymentStream
          : widget.vendorPaymentBloc.updateVendorPaymentStream,
      builder: (context, snapshot) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: 	 themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.popUpsBackground : null,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Title with Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            widget.payment == null ? 'Add Vendor Payout' : 'Edit Vendor Payout',
                            style: TextStyle(
                              color: 	 themeHelper.themeMode == ThemeMode.dark
                                  ? ThemeNotifier.textDark : Colors.black87,
                              fontSize: MediaQuery.of(context).size.width * 0.018,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.025,
                        height: MediaQuery.of(context).size.width * 0.025,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (kDebugMode) print("AddVendorPayoutDialog: Dialog closed");
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: MediaQuery.of(context).size.width * 0.012,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  // Form Fields
                  Row(
                    children: [
                      // Left Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Enter Amount
                            _buildFieldLabel('Enter Amount'),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                            _buildAmountTextField(),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                            // Select Payment Type
                            _buildFieldLabel('Select Payment Type'),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                            _buildDropdownField(
                              value: _selectedPaymentType,
                              items: widget.paymentTypes,
                              hint: 'Note/Check',
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentType = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      // Right Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Select Vendor
                            _buildFieldLabel('Select Vendor'),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                            _buildVendorDropdownField(),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                            // Select Purpose
                            _buildFieldLabel('Select Purpose'),
                            SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                            _buildDropdownField(
                              value: _selectedPurpose,
                              items: widget.purposes,
                              hint: 'Purpose',
                              onChanged: (value) {
                                setState(() {
                                  _selectedPurpose = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  // Notes field spanning full width
                  _buildFieldLabel('Notes'),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.008),
                  _buildNotesTextField(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  // Action Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFE6464),
                        disabledBackgroundColor: Color(0xFFFE6464), // Prevent grey color
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.03,
                          vertical: MediaQuery.of(context).size.height * 0.0225,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        widget.payment == null ? 'Add' : 'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.012,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Text(
      label,
      style: TextStyle(
        color: themeHelper.themeMode == ThemeMode.dark
            ? Colors.white70 : Colors.grey.shade600,
        fontSize: MediaQuery.of(context).size.width * 0.011,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAmountTextField() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.065,
      decoration: BoxDecoration(
        border: Border.all(color:themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.borderColor : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color:themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.paymentEntryContainerColor : null
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          AmountInputFormatter(),
        ],
        decoration: InputDecoration(
          hintText: '0.00',
          hintStyle: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? Colors.white70
                : Colors.grey.shade400,
            fontSize: MediaQuery.of(context).size.width * 0.011,
          ),
          prefixText: '${TextConstants.currencySymbol} ',
          prefixStyle: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? ThemeNotifier.textDark
                : Colors.black87,
            fontSize: MediaQuery.of(context).size.width * 0.011,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.012,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
        ),
        style: TextStyle(
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark
              : Colors.black87,
          fontSize: MediaQuery.of(context).size.width * 0.011,
          fontWeight: FontWeight.w500,
        ),
      ),

    );
  }

  Widget _buildNotesTextField() {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.065,
      decoration: BoxDecoration(
        border: Border.all(color: themeHelper.themeMode == ThemeMode.dark
        ? ThemeNotifier.borderColor : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
          color:themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.paymentEntryContainerColor : null
      ),
      child: TextField(
        controller: _notesController,
        decoration: InputDecoration(
          hintText: 'Add notes...',
          hintStyle: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? Colors.white70 : Colors.grey.shade400,
            fontSize: MediaQuery.of(context).size.width * 0.011,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.012,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
        ),
        style: TextStyle(
          color:  themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark : Colors.black87,
          fontSize: MediaQuery.of(context).size.width * 0.011,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.065,
      decoration: BoxDecoration(
        border: Border.all(color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.borderColor :Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
          color:themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.paymentEntryContainerColor : null
      ),
      child: DropdownButtonFormField<String>(
        dropdownColor: themeHelper.themeMode == ThemeMode.dark
          ? ThemeNotifier.primaryBackground : null,
        value: value,
        hint: Text(
          hint,
          style: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? Colors.white70 : Colors.grey.shade400,
            fontSize: MediaQuery.of(context).size.width * 0.011,
          ),
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.012,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark : Colors.grey.shade600,
          size: MediaQuery.of(context).size.width * 0.015,
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                color:themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark :  Colors.black87,
                fontSize: MediaQuery.of(context).size.width * 0.011,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark : Colors.black87,
          fontSize: MediaQuery.of(context).size.width * 0.011,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildVendorDropdownField() {
    final themeHelper = Provider.of<ThemeNotifier>(context);//Build #1.0.74: updated
    return Container(
      height: MediaQuery.of(context).size.height * 0.065,
      decoration: BoxDecoration(
        border: Border.all(color: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.borderColor : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
          color:themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.paymentEntryContainerColor : null
      ),
      child: DropdownButtonFormField<Vendor>(
        dropdownColor: themeHelper.themeMode == ThemeMode.dark
            ? ThemeNotifier.primaryBackground : null,
        value: _selectedVendor,
        hint: Text(
          'Vendor',
          style: TextStyle(
            color: themeHelper.themeMode == ThemeMode.dark
                ? Colors.white70 : Colors.grey.shade400,
            fontSize: MediaQuery.of(context).size.width * 0.011,
          ),
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.012,
            vertical: MediaQuery.of(context).size.height * 0.015,
          ),
        ),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark : Colors.grey.shade600,
          size: MediaQuery.of(context).size.width * 0.015,
        ),
        items: widget.vendors
            .where((vendor) => vendor.id != 0)
            .map((Vendor vendor) {
          return DropdownMenuItem<Vendor>(
            value: vendor,
            child: Text(
              vendor.vendorName,
              style: TextStyle(
                color: themeHelper.themeMode == ThemeMode.dark
                    ? ThemeNotifier.textDark : Colors.black87,
                fontSize: MediaQuery.of(context).size.width * 0.011,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: (Vendor? value) {
          setState(() {
            _selectedVendor = value;
            if (kDebugMode) {
              print("Selected vendor: ID: ${value?.id}, Name: ${value?.vendorName}");
            }
          });
        },
        style: TextStyle(
          color: themeHelper.themeMode == ThemeMode.dark
              ? ThemeNotifier.textDark : Colors.black87,
          fontSize: MediaQuery.of(context).size.width * 0.011,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}