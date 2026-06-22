import { OcrFields } from '../models/ocrFields';

/**
 * Ported from lib/services/ocr_parser.dart (verified against source on 2026-06-22).
 * Pure text-extraction logic — no Firebase/React dependency, callable directly from
 * podRepository.ts (on-device OCR via @react-native-ml-kit/text-recognition) and from
 * DocumentIntake.tsx (manual OCR-text paste).
 */
export class OcrParser {
  /** Mirrors OcrParser.parseText(). `confidence` is currently unused by the Dart source too. */
  parseText(text: string): OcrFields {
    const invoiceNo = this.extractInvoiceNumber(text);
    const supplier = this.extractSupplier(text);
    const customer = this.extractCustomer(text);

    const totalIncl = this.extractTotal(text, ['Total Due', 'Total\\s*Inc', 'Total']);
    const totalExcl = this.extractTotal(text, ['Total Excl', 'Subtotal', 'Goods Value']);
    const totalVat = this.extractVat(text);

    const documentDate = this.extractDate(text);
    const branch = this.extractBranch(text);
    const site = this.extractSite(text);
    const totalQty = this.extractQuantity(text);
    const totalMassKg = this.extractMass(text);
    const truckReg = this.extractTruckRegistration(text);
    const driverName = this.extractDriverName(text);
    const receivedBy = this.extractReceivedBy(text);
    const vatNo = this.extractVatNumber(text);

    return {
      supplier,
      customer,
      invoiceNo,
      documentDate,
      branch,
      site,
      vatNo,
      totalExcl,
      totalVat,
      totalIncl,
      totalMassKg,
      totalQty,
      truckReg,
      driverName,
      receivedBy,
      ocrRawText: text,
    };
  }

  /** Mirrors _extractInvoiceNumber(): patterns INV400098, INVOICE#400098, INV-400098. */
  private extractInvoiceNumber(text: string): string | undefined {
    const patterns = [
      /INV\s*#?\s*([A-Z0-9]{3,12})/i,
      /INVOICE\s*#?\s*([A-Z0-9]{3,12})/i,
      /Invoice No\.?\s*[:#]?\s*([A-Z0-9]{3,12})/i,
      /(?:^|\n)([A-Z0-9]{8,12})(?:\s|$)/m,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (match) return match[1];
    }
    return undefined;
  }

  /** Mirrors _extractSupplier(). */
  private extractSupplier(text: string): string | undefined {
    const patterns = [
      /(?:FROM|SUPPLIED BY|SUPPLIER)[\s:]*([A-Za-z\s().\-&,]+?)(?=\n|INVOICE|TO:)/i,
      /([A-Za-z\s().\-&,]*(?:Traders|Superstores|Group|Solutions|Distributors)[A-Za-z\s().\-&,]*?)(?=\n|INVOICE|Date)/i,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      const supplier = match?.[1]?.trim();
      if (supplier && supplier.length > 3) return supplier;
    }
    return undefined;
  }

  /** Mirrors _extractCustomer(). */
  private extractCustomer(text: string): string | undefined {
    const patterns = [
      /(?:TO:|DELIVERED TO|CUSTOMER)[\s:]*([A-Za-z\s().\-&,]+?)(?=\n|Branch|Store)/i,
      /(?:^|\n)(?:SHOPRITE|BOXER|CLICKS|TAKEALOT|SPAR|WOOLWORTHS)[A-Za-z\s().\-&,]*?(?=\n|Branch)/im,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      const customer = match?.[1]?.trim() ?? match?.[0]?.trim();
      if (customer && customer.length > 3) return customer;
    }
    return undefined;
  }

  /** Mirrors _extractTotal(): looks for "Total Due", "Total Inc", etc. */
  private extractTotal(text: string, keywords: string[]): number | undefined {
    for (const kw of keywords) {
      const pattern = new RegExp(`${kw}[\\s:]*(?:R\\s*)?([0-9]{1,3}(?:[,\\s]?[0-9]{3})*(?:\\.[0-9]{2})?)`, 'i');
      const match = pattern.exec(text);
      if (match) {
        const amountStr = (match[1] ?? '').replace(/[,\s]/g, '');
        const amount = parseFloat(amountStr);
        if (!Number.isNaN(amount)) return amount;
      }
    }
    return undefined;
  }

  /** Mirrors _extractVat(). */
  private extractVat(text: string): number | undefined {
    const pattern = /VAT[\s:]*(?:R\s*)?([0-9]{1,3}(?:[,\s]?[0-9]{3})*(?:\.[0-9]{2})?)/i;
    const match = pattern.exec(text);
    if (!match) return undefined;
    const amountStr = (match[1] ?? '').replace(/[,\s]/g, '');
    const amount = parseFloat(amountStr);
    return Number.isNaN(amount) ? undefined : amount;
  }

  /** Mirrors _extractVatNumber(): SA VAT is 10 digits starting with 4. */
  private extractVatNumber(text: string): string | undefined {
    const match = /\b(4\d{9})\b/.exec(text);
    return match?.[1];
  }

  /** Mirrors _extractDate(): supports dd/MM/yyyy, yyyy-MM-dd, etc. */
  private extractDate(text: string): Date | undefined {
    const patterns = [/(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})/, /(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})/];

    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (!match) continue;
      const part1 = parseInt(match[1], 10);
      const part2 = parseInt(match[2], 10);
      const part3 = parseInt(match[3], 10);

      if (part1 <= 31 && part2 <= 12 && part3 > 2000) {
        return new Date(part3, part2 - 1, part1);
      }
      if (part1 > 2000 && part2 <= 12 && part3 <= 31) {
        return new Date(part1, part2 - 1, part3);
      }
    }
    return undefined;
  }

  /** Mirrors _extractBranch(): patterns X319, 1250, Branch 1250, Store X319. */
  private extractBranch(text: string): string | undefined {
    const patterns = [/(?:Branch|Store|Outlet)[\s:]*([X]?\d{3,4})/i, /\b([X]\d{3}|1[0-2]\d{2})\b/];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (match) return match[1];
    }
    return undefined;
  }

  /** Mirrors _extractSite(): delivery site/location name. */
  private extractSite(text: string): string | undefined {
    const patterns = [
      /(?:Branch|Store|Location|Site|Outlet)[\s:]*([A-Za-z\s-]+?)(?=\n|Branch|Store)/i,
      /(?:CLEARY|CLAREMONT|MENLYN|SANDTON|HYDE PARK|CRESTA|EASTGATE)[\s\w]*/i,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      const site = match?.[0]?.trim();
      if (site && site.length > 2) return site;
    }
    return undefined;
  }

  /** Mirrors _extractQuantity(). */
  private extractQuantity(text: string): number | undefined {
    const patterns = [
      /Total\s+Qty[\s:]*(\d+)/i,
      /(?:Qty|Quantity|Items)\s*(?:Total)?[\s:]*(\d+)/i,
      /(\d+)\s+(?:boxes|crates|items|pieces)/i,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (match) {
        const qty = parseInt(match[1], 10);
        if (!Number.isNaN(qty)) return qty;
      }
    }
    return undefined;
  }

  /** Mirrors _extractMass(): total mass/weight in kg. */
  private extractMass(text: string): number | undefined {
    const patterns = [/Total\s+(?:Weight|Mass|Kg)[\s:]*([0-9]{1,5}(?:\.[0-9]{2})?)/i, /([0-9]{1,5}(?:\.[0-9]{2})?)\s*(?:kg|kgs|KG)/i];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (match) {
        const mass = parseFloat(match[1]);
        if (!Number.isNaN(mass)) return mass;
      }
    }
    return undefined;
  }

  /** Mirrors _extractTruckRegistration(): KFM 567 CC, KFM567CC, ABC-123-XY. */
  private extractTruckRegistration(text: string): string | undefined {
    const patterns = [
      /(?:Truck|Vehicle|Car|Reg|Registration)[\s:]*([A-Z]{2,3}\s?\d{2,3}\s?[A-Z]{2})/i,
      /\b([A-Z]{2,3}\s?\d{2,3}\s?[A-Z]{2})\b/,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      if (match) return match[1]?.replace(/\s+/g, ' ').trim();
    }
    return undefined;
  }

  /** Mirrors _extractDriverName(). */
  private extractDriverName(text: string): string | undefined {
    const patterns = [/Driver[\s:]*([A-Za-z\s-]+?)(?=\n|Phone|Cell|Signature)/i, /Driven by[\s:]*([A-Za-z\s-]+?)(?=\n|Phone)/i];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      const name = match?.[1]?.trim();
      if (name && name.length > 2 && !/\d/.test(name)) return name;
    }
    return undefined;
  }

  /** Mirrors _extractReceivedBy(): who received the delivery. */
  private extractReceivedBy(text: string): string | undefined {
    const patterns = [
      /Received by[\s:]*([A-Za-z\s-]+?)(?=\n|Signature|Date)/i,
      /(?:Signed by|Signed|Recipient)[\s:]*([A-Za-z\s-]+?)(?=\n|Date|Time)/i,
    ];
    for (const pattern of patterns) {
      const match = pattern.exec(text);
      const name = match?.[1]?.trim();
      if (name && name.length > 2 && !/\d/.test(name)) return name;
    }
    return undefined;
  }
}
