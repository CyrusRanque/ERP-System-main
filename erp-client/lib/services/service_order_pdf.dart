import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'document_pdf_layout.dart';
import '../widgets/field_ui.dart';

/// Printable service order — matches web service-order print layout.
class ServiceOrderPdf {
  ServiceOrderPdf._();

  static final _longDate = DateFormat('MMMM d, yyyy', 'en_US');

  static Future<void> share(
    Map<String, dynamic> order, {
    Map<String, dynamic>? customer,
  }) async {
    final bytes = await build(order, customer: customer);
    final invoice = order['invoiceNo']?.toString() ?? order['id']?.toString() ?? 'service-order';
    await Printing.sharePdf(bytes: bytes, filename: '$invoice.pdf');
  }

  static Future<Uint8List> build(
    Map<String, dynamic> order, {
    Map<String, dynamic>? customer,
  }) async {
    final logoData = await rootBundle.load('assets/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    final qty = (order['quantity'] as num?)?.toDouble() ?? 0;
    final unitCost = (order['unitCost'] as num?)?.toDouble() ?? 0;
    final amount = (order['amount'] as num?)?.toDouble() ?? fieldRoundMoney(qty * unitCost);
    final description = order['description']?.toString() ?? '';
    final projectName = order['projectName']?.toString();
    final customerName = customer?['name']?.toString() ?? order['customerName']?.toString();
    final customerAddress = customer?['address']?.toString() ?? '';
    final serviceOrderNo = order['invoiceNo']?.toString() ?? order['id']?.toString();
    final displayDate = _formatLongDate(order['displayDate'] ?? order['date']);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: DocumentPdfLayout.pageFormat,
        margin: DocumentPdfLayout.margin,
        build: (context) => [
          DocumentPdfLayout.letterhead(logo),
          pw.SizedBox(height: 8),
          DocumentPdfLayout.doubleRule(),
          pw.SizedBox(height: 8),
          DocumentPdfLayout.centeredTitle('SERVICE ORDER'),
          pw.SizedBox(height: 8),
          DocumentPdfLayout.doubleRule(),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To:', style: DocumentPdfLayout.bodyBold),
                    pw.SizedBox(height: 4),
                    pw.Text(customerName?.trim().isNotEmpty == true ? customerName! : ' ', style: DocumentPdfLayout.body),
                    if (customerAddress.trim().isNotEmpty)
                      pw.Text(customerAddress.trim(), style: DocumentPdfLayout.body),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    DocumentPdfLayout.fieldLine('Date:', displayDate, labelWidth: 118),
                    DocumentPdfLayout.fieldLine('Service Order No.:', serviceOrderNo, labelWidth: 118),
                  ],
                ),
              ),
            ],
          ),
          DocumentPdfLayout.serviceOrderProjectBar(projectName),
          DocumentPdfLayout.buildServiceOrderTable(
            description: description,
            quantity: qty,
            unitPrice: unitCost,
            total: amount,
          ),
          DocumentPdfLayout.soaFooter(),
        ],
      ),
    );
    return doc.save();
  }

  static String _formatLongDate(dynamic raw) {
    if (raw == null) return ' ';
    final parsed = DateTime.tryParse(raw.toString().split(RegExp(r'\s')).first);
    if (parsed == null) return raw.toString();
    return _longDate.format(parsed);
  }
}
