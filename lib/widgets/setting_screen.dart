import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double brightness = 0.9;
  bool isDark = false;

  bool dineIn = true;
  bool takeAway = true;

  bool clickSound = false;
  bool confirmSound = false;

  bool cash = true;
  bool card = true;
  bool upi = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            /// 🔙 HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 10),

                  /// 🔥 TITLE WITH HIGHLIGHT
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Settin",
                        ),
                        TextSpan(
                          text: "gs",
                          style: TextStyle(
                            backgroundColor: Colors.yellow,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _generalCard(),
                    const SizedBox(height: 16),
                    _systemCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            _bottomButtons(),
          ],
        ),
      ),
    );
  }

  /// 🔙 BACK BUTTON
  Widget _backButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.arrow_back_ios, size: 14, color: Colors.orange),
          SizedBox(width: 4),
          Text("Back", style: TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }
  Widget _row(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }

  /// 🔶 GENERAL CARD
  Widget _generalCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _highlightTitle("General settings"),
          const SizedBox(height: 14),

          _row("Default Language", _dropdown()),
          const SizedBox(height: 12),

          _brightness(),
          const SizedBox(height: 12),

          _theme(),
          const SizedBox(height: 12),

          _orderType(),
          const SizedBox(height: 12),

          _switch("Button click sound", clickSound,
                  (v) => setState(() => clickSound = v)),

          _switch("Order confirmation sound", confirmSound,
                  (v) => setState(() => confirmSound = v)),

          const SizedBox(height: 12),

          _payment(),
          const SizedBox(height: 12),

          _printer(),
        ],
      ),
    );
  }

  /// 🔧 SYSTEM CARD
  Widget _systemCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _highlightTitle("System Settings"),
          const SizedBox(height: 12),

          _infoRow("WiFi :", "Unknown"),
          _infoRow("Kiosk ID :", "K7022"),
          _infoRow("Version :", "1.0.0"),
        ],
      ),
    );
  }

  /// 🔤 HIGHLIGHT TITLE
  Widget _highlightTitle(String text) {
    final parts = text.split(" ");
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black),
        children: [
          TextSpan(text: parts[0] + " "),
          TextSpan(
            text: parts[1],
            style: const TextStyle(backgroundColor: Colors.yellow),
          ),
        ],
      ),
    );
  }

  /// 🔽 DROPDOWN
  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton(
        underline: const SizedBox(),
        value: "English",
        items: ["English", "Hindi"]
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (_) {},
      ),
    );
  }

  /// 🎚 BRIGHTNESS
  Widget _brightness() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Brightness"),
        Slider(
          value: brightness,
          activeColor: Colors.orange,
          onChanged: (v) => setState(() => brightness = v),
        ),
      ],
    );
  }

  /// 🌙 THEME
  Widget _theme() {
    return Row(
      children: [
        const Text("Theme"),
        const Spacer(),
        _radio("Dark", true),
        _radio("Light", false),
      ],
    );
  }

  Widget _radio(String text, bool value) {
    return Row(
      children: [
        Radio(
          value: value,
          groupValue: isDark,
          onChanged: (_) => setState(() => isDark = value),
        ),
        Text(text),
      ],
    );
  }

  /// 🍽 ORDER TYPE
  Widget _orderType() {
    return Row(
      children: [
        const Text("Order type"),
        const Spacer(),
        _check("Dine In", dineIn, (v) => setState(() => dineIn = v)),
        _check("Take Away", takeAway, (v) => setState(() => takeAway = v)),
      ],
    );
  }

  /// 🔘 CHECKBOX
  Widget _check(String text, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          activeColor: Colors.orange,
          onChanged: (v) => onChanged(v!),
        ),
        Text(text),
      ],
    );
  }

  /// 🔊 SWITCH
  Widget _switch(String title, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Text(title),
        const Spacer(),
        Switch(
          value: value,
          activeColor: Colors.orange,
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 💳 PAYMENT
  Widget _payment() {
    return Row(
      children: [
        const Text("Payment Methods"),
        const Spacer(),
        _check("Cash", cash, (v) => setState(() => cash = v)),
        _check("Card", card, (v) => setState(() => card = v)),
        _check("UPI", upi, (v) => setState(() => upi = v)),
      ],
    );
  }

  /// 🖨 PRINTER
  Widget _printer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Printer Type"),
        const SizedBox(height: 8),

        Row(
          children: [
            const Text("USB Printer"),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {},
              child: const Text("Add"),
            ),
          ],
        ),
      ],
    );
  }

  /// ℹ INFO ROW
  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(title),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  /// 🔴 BOTTOM BUTTONS
  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
              ),
              onPressed: () {},
              child:
              const Text("Restart",
              style: TextStyle(color: Color(0xFFFF6900)),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {},
              child: const Text("Shutdown",
    style: TextStyle(color: Colors.white),
            )),
          ),
        ],
      ),
    );
  }
}