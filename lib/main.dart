import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Printer Invoice',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ZebraPrinterPage(),
    );
  }
}

class ZebraPrinterPage extends StatefulWidget {
  @override
  _ZebraPrinterPageState createState() => _ZebraPrinterPageState();
}

class _ZebraPrinterPageState extends State<ZebraPrinterPage> {
  TextEditingController macController = TextEditingController();
  bool isConnecting = false;

  // Invoice data formatted for Zebra receipt printers
  final String invoiceZPL = """
^XA
^CI28
^FO50,50^A0N,40,40^FD2e232INVoooCE^FS
^FO50,100^GB500,3,3^FS
^FO50,150^A0N,30,30^FDItem                الكمبة    السعر    Total^FS
^FO50,200^A0N,28,28^FDItem A               2      10.00    20.00^FS
^FO50,250^A0N,28,28^FDItem B               1      15.00    15.00^FS
^FO50,300^A0N,28,28^FDItem C               3      7.50     22.50^FS
^LL300
^XZ
""";

  Future<void> _printInvoice(String macAddress) async {
    final macAddressPattern =
        r'^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$'; // MAC address regex
    if (!RegExp(macAddressPattern).hasMatch(macAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid MAC address format.")),
      );
      return;
    }

    setState(() {
      isConnecting = true;
    });

    try {
      // Connect to the printer
      final connection = await BluetoothConnection.toAddress(macAddress);

      // Send ZPL data (invoice)
      connection.output.add(Uint8List.fromList(invoiceZPL.codeUnits));
      await connection.output.allSent;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invoice printed successfully!")),
      );

      // Close connection
      connection.finish();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zebra Printer Invoice'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: macController,
              decoration: InputDecoration(
                labelText: 'Enter Printer MAC Address',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isConnecting
                  ? null
                  : () {
                      if (macController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  "Please enter the printer MAC address.")),
                        );
                        return;
                      }
                      _printInvoice(macController.text);
                    },
              child: isConnecting
                  ? CircularProgressIndicator()
                  : Text("Print Invoice"),
            ),
          ],
        ),
      ),
    );
  }
}
