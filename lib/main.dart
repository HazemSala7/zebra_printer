import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart' as flutterBlue;
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

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
  // Common Variables
  bool isProcessing = false;
  String platform = Platform.isIOS ? "iOS" : "Android";

  // iOS Variables
  flutterBlue.FlutterBlue flutterBlueInstance =
      flutterBlue.FlutterBlue.instance;
  flutterBlue.BluetoothDevice? connectedIOSDevice;

  // Android Variables
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  TextEditingController macController = TextEditingController();

  // Sample Invoice Data
  final List<InvoiceItem> items = [
    InvoiceItem(name: 'Product A', quantity: 2, price: 15.0, total: 30.0),
    InvoiceItem(name: 'Product B', quantity: 1, price: 25.0, total: 25.0),
    InvoiceItem(name: 'Product C', quantity: 3, price: 10.0, total: 30.0),
  ];

  final String invoiceNumber = 'INV123456';
  final String licensedOperator = '123456789';
  final String date = '2024-12-04';
  final String shopName = 'My Shop';
  final double discount = 10.0;
  final double finalTotal = 75.0;

  Future<void> _connectToDevice(String macAddress) async {
    if (platform == "iOS") {
      await _connectToIOSDevice(macAddress);
    } else {
      await _connectToAndroidDevice(macAddress);
    }
  }

  // Fetch iOS Devices and Connect
  Future<void> _connectToIOSDevice(String macAddress) async {
    setState(() {
      isProcessing = true;
    });

    try {
      flutterBlueInstance.startScan(timeout: Duration(seconds: 5));
      await for (var result in flutterBlueInstance.scanResults) {
        for (var device in result) {
          if (device.device.id.id == macAddress) {
            await device.device.connect();
            setState(() {
              connectedIOSDevice = device.device;
            });
            flutterBlueInstance.stopScan();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Connected to ${device.device.name}")),
            );
            return;
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Device with MAC address $macAddress not found")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error connecting to device: $e")),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _connectToAndroidDevice(String macAddress) async {
    setState(() {
      isProcessing = true;
    });
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      BluetoothDevice? targetDevice = devices.firstWhere(
        (d) => d.address == macAddress,
        orElse: () => null as BluetoothDevice,
      );
      if (targetDevice != null) {
        await bluetooth.connect(targetDevice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connected to ${targetDevice.name}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No device with MAC address $macAddress")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error connecting to device: $e")),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _printInvoice(String macAddress) async {
    if (platform == "iOS") {
      await _printInvoiceIOS(macAddress);
    } else {
      await _printInvoiceAndroid(macAddress);
    }
  }

  Future<void> _printInvoiceIOS(String macAddress) async {
    if (connectedIOSDevice == null) {
      await _connectToIOSDevice(macAddress);
      if (connectedIOSDevice == null) return; // Stop if still not connected
    }

    final invoiceZPL = generateInvoiceZPL(
      invoiceNumber: invoiceNumber,
      licensedOperator: licensedOperator,
      date: date,
      shopName: shopName,
      items: items,
      discount: discount,
      finalTotal: finalTotal,
    );

    try {
      List<flutterBlue.BluetoothService> services =
          await connectedIOSDevice!.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            for (String chunk in _chunkZPL(invoiceZPL, 200)) {
              await characteristic
                  .write(Uint8List.fromList(utf8.encode(chunk)));
              await Future.delayed(Duration(milliseconds: 200));
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

  Future<void> _printInvoiceAndroid(String macAddress) async {
    await _connectToAndroidDevice(macAddress);

    final invoiceZPL = generateInvoiceZPL(
      invoiceNumber: invoiceNumber,
      licensedOperator: licensedOperator,
      date: date,
      shopName: shopName,
      items: items,
      discount: discount,
      finalTotal: finalTotal,
    );

    try {
      bluetooth.write(invoiceZPL); // Pass the string directly
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invoice printed successfully!")),
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
        title: Text('Zebra Printer Invoice ($platform)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
              onPressed: isProcessing
                  ? null
                  : () {
                      // if (macController.text.isEmpty) {
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     SnackBar(
                      //         content: Text(
                      //             "Please enter the printer MAC address.")),
                      //   );
                      //   return;
                      // }
                      _printInvoice("C4:D3:6A:AF:6C:14");
                    },
              child: isProcessing
                  ? CircularProgressIndicator()
                  : Text("Print Invoice"),
            ),
          ],
        ),
      ),
    );
  }
}

// InvoiceItem class and ZPL generation function
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
  ^FO20,630^A1N,30,30^FD4-0555555555^FS
  ^XZ
  """);

  return zpl.toString();
}
