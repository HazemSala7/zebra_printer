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

  final String invoiceZPL = """
^XA
^CI28
^CW1,E:TT0003M_.FNT  // Replace with the correct Arabic-supporting font
^FO50,50^A1N,40,40^FD2e232INVoooCE^FS
^FO50,100^GB500,3,3^FS
^FO50,150^A1N,30,30^FDItem                الكمية    السعر     Total^FS
^FO50,200^A1N,28,28^FDItem A               2       10.00      20.00^FS
^FO50,250^A1N,28,28^FDItem B               1       15.00      15.00^FS
^FO50,300^A1N,28,28^FDItem C               3       7.50       22.50^FS
^LL300
^XZ
""";

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

    try {
      List<BluetoothService> services =
          await connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic
                .write(Uint8List.fromList(utf8.encode(invoiceZPL)));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Invoice printed successfully!")),
            );
            return;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error printing invoice: $e")),
      );
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
