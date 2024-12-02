import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

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
  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> discoveredDevices = [];
  BluetoothDevice? connectedDevice;
  bool isScanning = false;

  // Test Invoice Items
  List<InvoiceItem> items = [
    InvoiceItem(
        name: 'شرائح صدور دجاج', quantity: 5.0, price: 5.0, total: 25.0),
    InvoiceItem(name: 'شرائح بانيه', quantity: 10.0, price: 4.0, total: 40.0),
    InvoiceItem(name: 'شرائح صدر دجاج', quantity: 3.0, price: 4.0, total: 20.0),
  ];

  String generateInvoice() {
    return generateInvoiceZPL(
      invoiceNumber: '241001581',
      licensedOperator: '562156786',
      date: '2024-11-11',
      shopName: 'دورا، المواد الغذائية والتموينية',
      items: items,
      discount: 10.0,
      finalTotal: 148.0,
    );
  }

  @override
  void dispose() {
    if (connectedDevice != null) {
      connectedDevice!.disconnect();
    }
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      isScanning = true;
      discoveredDevices.clear();
    });

    flutterBlue.startScan(timeout: Duration(seconds: 5));
    flutterBlue.scanResults.listen((results) {
      setState(() {
        discoveredDevices = results.map((r) => r.device).toList();
      });
    }).onDone(() {
      setState(() {
        isScanning = false;
      });
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        isScanning = true;
      });
      await device.connect();
      setState(() {
        connectedDevice = device;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connected to ${device.name}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error connecting to device: $e")),
      );
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> _printInvoice() async {
    if (connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No connected printer")),
      );
      return;
    }

    String invoiceZPL = generateInvoice();
    List<String> zplChunks =
        _chunkZPL(invoiceZPL, 200); // Chunk size of 200 bytes

    try {
      List<BluetoothService> services =
          await connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.write) {
            print("Writing to characteristic: ${characteristic.uuid}");
            for (String chunk in zplChunks) {
              await characteristic
                  .write(Uint8List.fromList(utf8.encode(chunk)));
              await Future.delayed(
                  Duration(milliseconds: 200)); // Delay between chunks
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Invoice printed successfully!")),
            );
            return;
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No writable characteristic found")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error printing invoice: $e")),
      );
    }
  }

  List<String> _chunkZPL(String zpl, int chunkSize) {
    List<String> chunks = [];
    for (int i = 0; i < zpl.length; i += chunkSize) {
      chunks.add(zpl.substring(
          i, i + chunkSize > zpl.length ? zpl.length : i + chunkSize));
    }
    return chunks;
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
          children: [
            ElevatedButton(
              onPressed: isScanning ? null : _startScanning,
              child: isScanning
                  ? CircularProgressIndicator()
                  : Text("Search for Printers"),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = discoveredDevices[index];
                  return ListTile(
                    title: Text(
                        device.name.isEmpty ? "Unknown Device" : device.name),
                    subtitle: Text(device.id.toString()),
                    trailing: ElevatedButton(
                      onPressed: connectedDevice == device
                          ? null
                          : () => _connectToDevice(device),
                      child: Text(
                        connectedDevice == device ? "Connected" : "Connect",
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: connectedDevice == null ? null : _printInvoice,
              child: Text("Print Invoice"),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceItem {
  final String name;
  final double quantity;
  final double price;
  final double total;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

String generateInvoiceZPL({
  required String invoiceNumber,
  required String licensedOperator,
  required String date,
  required String shopName,
  required List<InvoiceItem> items,
  required double discount,
  required double finalTotal,
}) {
  // final int baseHeight = 380; // Starting height of the items
  // final int rowHeight = 30; // Height for each row
  // final int footerHeight = 160; // Space for footer
  // final int paperHeight = baseHeight +footerHeight;

  final StringBuffer zpl = StringBuffer();

  // Header with Company Name, Invoice Details, and Shop Name
  zpl.write("""
  ^XA
  ^CI28
  ^CW1,E:TT0003M_.FNT
  ^LL670 // Dynamic paper length

  // Company Logo and Name
  ^FO200,30^A1N,50,50^FDEighty Five^FS
  ^FO180,90^A1N,30,30^FDFOOD PRODUCT^FS
  ^FO160,130^A1N,30,30^FDMANUFACTURING CO.^FS
  ^FO20,170^A1N,30,30^FDشركة خمسة وثمانون لصناعة المواد الغذائية^FS
  ^FO160,210^A1N,30,30^FD0798585111^FS
  ^FO00,250^GB750,3,3^FS

  // Invoice Details
  ^FO100,270^A1N,30,30^FDسند قبض رقم: $invoiceNumber^FS
  ^FO20,320^A1N,30,30^FDOriginal^FS
  ^FO360,320^A1N,30,30^FDرقم الضريبة^FS
  ^FO360,360^A1N,30,30^FD$licensedOperator^FS
  ^FO20,360^A1N,30,30^FDالتاريخ: $date^FS
  ^FO360,400^A1N,30,30^FDالسيد^FS
  ^FO20,400^A1N,30,30^FDقهوة برهوم^FS
  """);

  // Footer with Totals
  zpl.write("""
  ^FO360,440^A1N,30,30^FDمجموع النقدي^FS
  ^FO200,440^A1N,30,30^FD15^FS
  ^FO360,480^A1N,30,30^FDمجموع الشيكات^FS
  ^FO200,480^A1N,30,30^FD0^FS
  ^FO360,520^A1N,30,30^FDخصم^FS
  ^FO200,520^A1N,30,30^FD${discount.toStringAsFixed(1)}^FS
  ^FO360,560^A1N,30,30^FDالمجموع النهائي^FS
  ^FO200,560^A1N,30,30^FD${finalTotal.toStringAsFixed(1)}^FS

  // Representative Number
  ^FO20,590^A1N,30,30^FDرقم المندوب^FS
  ^FO20,620^A1N,30,30^FD4-0555555555^FS
  ^XZ
  """);

  return zpl.toString();
}