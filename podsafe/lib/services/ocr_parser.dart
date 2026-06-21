import 'package:flutter/foundation.dart';
import '../models/ocr_fields_model.dart';

/// Service for parsing OCR text and extracting structured fields
class OcrParser {
  static const double confidenceThreshold = 0.7;

  /// Parse raw OCR text and extract structured fields
  /// This can be called with text from google_mlkit_text_recognition or other OCR services
  OcrFields parseText(String text, {double confidence = 0.5}) {
    if (kDebugMode) {
      print('OCR Confidence: $confidence');
      print('OCR Text:\n$text');
    }

    final fields = _parseText(text, confidence);
    return fields;
  }

  /// Parse OCR text and extract structured fields
  OcrFields _parseText(String text, double confidence) {
    final warnings = <String>[];

    // Extract invoice number
    final invoiceNo = _extractInvoiceNumber(text);

    // Extract company names
    final supplier = _extractSupplier(text);
    final customer = _extractCustomer(text);

    // Extract financial information
    final totalIncl = _extractTotal(text, ['Total Due', 'Total\\s*Inc', 'Total']);
    final totalExcl = _extractTotal(text, ['Total Excl', 'Subtotal', 'Goods Value']);
    final totalVat = _extractVat(text);

    // Validate totals
    if (totalExcl != null && totalVat != null && totalIncl != null) {
      if ((totalExcl + totalVat - totalIncl).abs() > 1.0) {
        warnings.add(
            'Totals mismatch: Excl(R$totalExcl) + VAT(R$totalVat) ≠ Incl(R$totalIncl)');
      }
    }

    // Extract date
    final documentDate = _extractDate(text);
    if (documentDate == null) {
      warnings.add('Document date not found or unreadable');
    } else if (documentDate.isAfter(DateTime.now().add(Duration(days: 1))) ||
        documentDate.isBefore(DateTime.now().subtract(Duration(days: 365)))) {
      warnings.add(
          'Document date ($documentDate) is outside expected range (today ±1 year)');
    }

    // Extract branch and site
    final branch = _extractBranch(text);
    final site = _extractSite(text);

    // Extract quantity and mass
    final totalQty = _extractQuantity(text);
    final totalMassKg = _extractMass(text);

    // Extract vehicle and driver info
    final truckReg = _extractTruckRegistration(text);
    final driverName = _extractDriverName(text);
    final receivedBy = _extractReceivedBy(text);

    // Extract VAT number
    final vatNo = _extractVatNumber(text);

    if (invoiceNo == null) {
      warnings.add('Invoice number not found - document needs manual review');
    }

    return OcrFields(
      supplier: supplier,
      customer: customer,
      invoiceNo: invoiceNo,
      documentDate: documentDate,
      branch: branch,
      site: site,
      vatNo: vatNo,
      totalExcl: totalExcl,
      totalVat: totalVat,
      totalIncl: totalIncl,
      totalMassKg: totalMassKg,
      totalQty: totalQty,
      truckReg: truckReg,
      driverName: driverName,
      receivedBy: receivedBy,
      ocrRawText: text,
    );
  }

  /// Extract invoice number - patterns: INV400098, INVOICE#400098, INV-400098
  String? _extractInvoiceNumber(String text) {
    final patterns = [
      RegExp(r'INV\s*#?\s*([A-Z0-9]{3,12})', caseSensitive: false),
      RegExp(r'INVOICE\s*#?\s*([A-Z0-9]{3,12})', caseSensitive: false),
      RegExp(r'Invoice No\.?\s*[:#]?\s*([A-Z0-9]{3,12})', caseSensitive: false),
      RegExp(r'(?:^|\n)([A-Z0-9]{8,12})(?:\s|$)', multiLine: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Extract supplier/from company name
  String? _extractSupplier(String text) {
    final patterns = [
      RegExp(
        r'(?:FROM|SUPPLIED BY|SUPPLIER)[\s:]*([A-Za-z\s\(\)\.\-&,]+?)(?=\n|INVOICE|TO:)',
        caseSensitive: false,
      ),
      RegExp(
        r'([A-Za-z\s\(\)\.\-&,]*(?:Traders|Superstores|Group|Solutions|Distributors)[A-Za-z\s\(\)\.\-&,]*?)(?=\n|INVOICE|Date)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final supplier = match.group(1)?.trim();
        if (supplier != null && supplier.length > 3) {
          return supplier;
        }
      }
    }
    return null;
  }

  /// Extract customer/to company name
  String? _extractCustomer(String text) {
    final patterns = [
      RegExp(
        r'(?:TO:|DELIVERED TO|CUSTOMER)[\s:]*([A-Za-z\s\(\)\.\-&,]+?)(?=\n|Branch|Store)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:^|\n)(?:SHOPRITE|BOXER|CLICKS|TAKEALOT|SPAR|WOOLWORTHS)[A-Za-z\s\(\)\.\-&,]*?(?=\n|Branch)',
        caseSensitive: false,
        multiLine: true,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final customer = match.group(1)?.trim() ?? match.group(0)?.trim();
        if (customer != null && customer.length > 3) {
          return customer;
        }
      }
    }
    return null;
  }

  /// Extract total amount - looks for "Total Due", "Total Inc", etc.
  double? _extractTotal(String text, List<String> keywords) {
    for (final kw in keywords) {
      final pattern = RegExp(
        '${RegExp.escape(kw)}[\\s:]*(?:R\\s*)?([0-9]{1,3}(?:[,\\s]?[0-9]{3})*(?:\\.[0-9]{2})?)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(RegExp(r'[,\s]'), '') ?? '';
        return double.tryParse(amountStr);
      }
    }
    return null;
  }

  /// Extract VAT amount
  double? _extractVat(String text) {
    final pattern = RegExp(
      r'VAT[\s:]*(?:R\s*)?([0-9]{1,3}(?:[,\s]?[0-9]{3})*(?:\.[0-9]{2})?)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(RegExp(r'[,\s]'), '') ?? '';
      return double.tryParse(amountStr);
    }
    return null;
  }

  /// Extract VAT registration number (SA VAT: 10 digits starting with 4)
  String? _extractVatNumber(String text) {
    final pattern = RegExp(r'\b(4\d{9})\b');
    final match = pattern.firstMatch(text);
    return match?.group(1);
  }

  /// Extract delivery date - supports dd/MM/yyyy, yyyy-MM-dd, etc.
  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(
        r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})',
      ), // dd/mm/yyyy or yyyy/mm/dd
      RegExp(r'(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final part1 = int.parse(match.group(1)!);
          final part2 = int.parse(match.group(2)!);
          final part3 = int.parse(match.group(3)!);

          // Try dd/mm/yyyy format first
          if (part1 <= 31 && part2 <= 12 && part3 > 2000) {
            return DateTime(part3, part2, part1);
          }
          // Try yyyy/mm/dd
          if (part1 > 2000 && part2 <= 12 && part3 <= 31) {
            return DateTime(part1, part2, part3);
          }
        } catch (e) {
          // Continue to next pattern
        }
      }
    }
    return null;
  }

  /// Extract branch code - patterns: X319, 1250, Branch 1250, Store X319
  String? _extractBranch(String text) {
    final patterns = [
      RegExp(r'(?:Branch|Store|Outlet)[\s:]*([X]?\d{3,4})', caseSensitive: false),
      RegExp(r'\b([X]\d{3}|1[0-2]\d{2})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Extract delivery site/location name
  String? _extractSite(String text) {
    final patterns = [
      RegExp(
        r'(?:Branch|Store|Location|Site|Outlet)[\s:]*([A-Za-z\s\-]+?)(?=\n|Branch|Store)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:CLEARY|CLAREMONT|MENLYN|SANDTON|HYDE PARK|CRESTA|EASTGATE)[\s\w]*',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final site = match.group(0)?.trim();
        if (site != null && site.length > 2) {
          return site;
        }
      }
    }
    return null;
  }

  /// Extract total quantity
  int? _extractQuantity(String text) {
    final patterns = [
      RegExp(r'Total\s+Qty[\s:]*(\d+)', caseSensitive: false),
      RegExp(r'(?:Qty|Quantity|Items)\s*(?:Total)?[\s:]*(\d+)', caseSensitive: false),
      RegExp(r'(\d+)\s+(?:boxes|crates|items|pieces)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  /// Extract total mass/weight in kg
  double? _extractMass(String text) {
    final patterns = [
      RegExp(r'Total\s+(?:Weight|Mass|Kg)[\s:]*([0-9]{1,5}(?:\.[0-9]{2})?)',
          caseSensitive: false),
      RegExp(r'([0-9]{1,5}(?:\.[0-9]{2})?)\s*(?:kg|kgs|KG)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  /// Extract truck/vehicle registration - patterns: KFM 567 CC, KFM567CC, ABC-123-XY
  String? _extractTruckRegistration(String text) {
    final patterns = [
      RegExp(r'(?:Truck|Vehicle|Car|Reg|Registration)[\s:]*([A-Z]{2,3}\s?\d{2,3}\s?[A-Z]{2})',
          caseSensitive: false),
      RegExp(r'\b([A-Z]{2,3}\s?\d{2,3}\s?[A-Z]{2})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return null;
  }

  /// Extract driver name
  String? _extractDriverName(String text) {
    final patterns = [
      RegExp(r'Driver[\s:]*([A-Za-z\s\-]+?)(?=\n|Phone|Cell|Signature)',
          caseSensitive: false),
      RegExp(r'Driven by[\s:]*([A-Za-z\s\-]+?)(?=\n|Phone)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.length > 2 && !name.contains(RegExp(r'\d'))) {
          return name;
        }
      }
    }
    return null;
  }

  /// Extract who received the delivery
  String? _extractReceivedBy(String text) {
    final patterns = [
      RegExp(r'Received by[\s:]*([A-Za-z\s\-]+?)(?=\n|Signature|Date)',
          caseSensitive: false),
      RegExp(
        r'(?:Signed by|Signed|Recipient)[\s:]*([A-Za-z\s\-]+?)(?=\n|Date|Time)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null && name.length > 2 && !name.contains(RegExp(r'\d'))) {
          return name;
        }
      }
    }
    return null;
  }
}
