import 'package:flutter/material.dart';
import 'package:pinaka_pos/Constants/text.dart';
import 'package:pinaka_pos/Widgets/widget_filter.dart';
import 'package:quickalert/quickalert.dart';

import '../../Constants/text.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _selectedFilter = "All"; // Default filter value

  // Sample data
  final List<Map<String, String>> allData = [
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '₹350',
      'over_short': '-₹60',
    },
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '${TextConstants.currencySymbol}350',
      'over_short': '-${TextConstants.currencySymbol}60',
    },
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '${TextConstants.currencySymbol}350',
      'over_short': '-${TextConstants.currencySymbol}60',
    },
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '${TextConstants.currencySymbol}350',
      'over_short': '-${TextConstants.currencySymbol}60',
    },
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '${TextConstants.currencySymbol}350',
      'over_short': '-${TextConstants.currencySymbol}60',
    },
    {
      'date': '28/10/2023',
      'duration': '8:00:00',
      'start_time': '12:00:00',
      'end_time': '08:00:00',
      'sales_amount': '${TextConstants.currencySymbol}350',
      'over_short': '-${TextConstants.currencySymbol}60',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Filter the data based on the selected filter
    List<Map<String, String>> filteredData = allData.where((entry) {
      if (_selectedFilter == "All") return true;
      return entry['sales_amount']!.contains(_selectedFilter);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Dropdown (Reusable)
        FilterDropdown(
          items: ["All", "₹", "${TextConstants.currencySymbol}"], // Filtering by currency type
          selectedValue: _selectedFilter,
          onChanged: (value) {
            setState(() {
              _selectedFilter = value;
            });
          },
        ),
        const SizedBox(height: 10), // Space between filter and table

        // Sales Data Table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateColor.resolveWith((states) => Colors.grey.shade200),
              columns: const <DataColumn>[
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Duration')),
                DataColumn(label: Text('Start Time')),
                DataColumn(label: Text('End Time')),
                DataColumn(label: Text('Sales Amount')),
                DataColumn(label: Text('Over/Short')),
                DataColumn(label: Text('')),
              ],
              rows: filteredData.map((entry) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(entry['date']!)),
                    DataCell(Text(entry['duration']!)),
                    DataCell(Text(entry['start_time']!)),
                    DataCell(Text(entry['end_time']!)),
                    DataCell(Text(entry['sales_amount']!)),
                    DataCell(Text(entry['over_short']!)),
                    DataCell(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              QuickAlert.show(
                                context: context,
                                type: QuickAlertType.confirm,
                                title: "Are you sure?",
                                text: 'This action cannot be undone.',
                                confirmBtnText: 'Yes, Delete',
                                cancelBtnText: 'Cancel',
                                barrierDismissible: false,
                                confirmBtnColor: Colors.red,
                                confirmBtnTextStyle: TextStyle(fontSize: 14, color: Colors.white),
                                onConfirmBtnTap: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Item deleted successfully")),
                                  );
                                },
                                onCancelBtnTap: () {
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}