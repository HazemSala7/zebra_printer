// String generateInvoiceZPL({
//   required String invoiceNumber,
//   required String licensedOperator,
//   required String date,
//   required String shopName,
//   required List<InvoiceItem> items,
//   required double discount,
//   required double finalTotal,
// }) {
//   final int baseHeight = 380; // Starting height of the items
//   final int rowHeight = 30; // Height for each row
//   final int footerHeight = 160; // Space for footer
//   final int itemSectionHeight = items.length * rowHeight;
//   final int paperHeight = baseHeight + itemSectionHeight + footerHeight;

//   final StringBuffer zpl = StringBuffer();

//   // Header with Company Name, Invoice Details, and Shop Name
//   zpl.write("""
//   ^XA
//   ^CI28
//   ^CW1,E:TT0003M_.FNT
//   ^LL${paperHeight} // Dynamic paper length

//   // Company Name
//   ^FO200,30^A1N,40,40^FDSara شركة التجارة^FS
//   ^FO20,70^GB550,3,3^FS

//   // Invoice Details
//   ^FO160,100^A1N,30,30^FDفاتورة ضريبية رقم: $invoiceNumber^FS
//   ^FO20,140^A1N,30,30^FDOriginal^FS
//   ^FO360,140^A1N,30,30^FDمشغل مرخص^FS
//   ^FO360,180^A1N,30,30^FD$licensedOperator^FS
//   ^FO20,180^A1N,30,30^FDالتاريخ: $date^FS
//   ^FO160,220^A1N,30,30^FDجاهليموال الغذائية والتموينية دورا^FS
//   """);

//   // Table Header
//   zpl.write("""
//   ^FO5,280^GB500,3,3^FS
//   ^FO5,280^A1N,30,30^FDالاسم              السعر    الكمية     المجموع^FS
//   ^FO5,310^GB500,3,3^FS
//   """);

//   // Dynamic Vertical Lines for Columns
//   int tableStartY = 340;
//   zpl.write("""
//   ^FO100,${tableStartY}^GB3,${itemSectionHeight},3^FS // Vertical line for 'السعر'
//   ^FO200,${tableStartY}^GB3,${itemSectionHeight},3^FS // Vertical line for 'الكمية'
//   ^FO320,${tableStartY}^GB3,${itemSectionHeight},3^FS // Vertical line for 'الاسم'
//   """);

//   // Items Rows
//   int yPosition = tableStartY;
//   for (var item in items) {
//     // Truncate name to 14 characters and align each column
//     String name = item.name.length > 20
//         ? item.name.substring(0, 20)
//         : item.name.padLeft(14);
//     String quantity = item.quantity.toStringAsFixed(1).padLeft(6);
//     String price = item.price.toStringAsFixed(1).padLeft(6);
//     String total = item.total.toStringAsFixed(1).padLeft(6);

//     zpl.write("""
//     ^FO360,$yPosition^A1N,28,28^FD$name^FS   // Aligned under 'الاسم'
//     ^FO210,$yPosition^A1N,28,28^FD$quantity^FS // Aligned under 'الكمية'
//     ^FO110,$yPosition^A1N,28,28^FD$price^FS   // Aligned under 'السعر'
//     ^FO10,$yPosition^A1N,28,28^FD$total^FS    // Aligned under 'المجموع'
//     """);
//     yPosition += rowHeight; // Adjust yPosition for the next item row
//   }

//   // Footer with Total, Discount, and Final Total
// zpl.write("""
//   ^FO20,$yPosition^GB550,3,3^FS
//   ^FO20,${yPosition + 20}^A1N,30,30^FDالمجموع:        ${items.fold<double>(0, (sum, item) => sum + item.total).toStringAsFixed(1)}^FS
//   ^FO330,${yPosition + 20}^A1N,30,30^FDرقم المندوب^FS
//   ^FO20,${yPosition + 60}^A1N,30,30^FDالخصم:          ${discount.toStringAsFixed(1)}^FS
//   ^FO330,${yPosition + 60}^A1N,30,30^FD10^FS
//   ^FO20,${yPosition + 100}^GB550,3,3^FS
//   ^FO20,${yPosition + 130}^A1N,30,30^FDالمجموع النهائي:       ${finalTotal.toStringAsFixed(1)}^FS
//   ^XZ
//   """);

//   return zpl.toString();
// }