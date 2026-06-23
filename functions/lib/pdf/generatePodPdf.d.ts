import * as functions from 'firebase-functions';
export declare function normalizeRegistration(registration: string): string;
declare function fetchImageBytes(url: string | undefined | null): Promise<Buffer | null>;
export declare function formatTimestamp(value: unknown): string;
export { fetchImageBytes };
interface InfoRow {
    label: string;
    value: string;
}
export declare function drawSectionHeader(doc: PDFKit.PDFDocument, title: string): void;
export declare function drawInfoRows(doc: PDFKit.PDFDocument, rows: InfoRow[]): void;
export declare function drawImageCentered(doc: PDFKit.PDFDocument, bytes: Buffer, maxWidth: number, maxHeight: number): void;
export interface PodPdfInput {
    deliveryId: string;
    pod: Record<string, any>;
    delivery?: Record<string, any> | undefined;
    driver?: Record<string, any> | undefined;
    vehicle?: Record<string, any> | undefined;
    company?: Record<string, any> | undefined;
    photoBytesList: (Buffer | null)[];
    documentBytesList: (Buffer | null)[];
    documentMetadata: Array<{
        type?: string;
    }>;
    signatureBytes: Buffer | null;
    stampBytes: Buffer | null;
    logoBytes: Buffer | null;
}
export declare function buildPodPdfBuffer(input: PodPdfInput): Promise<Buffer>;
export declare const generatePodPdf: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=generatePodPdf.d.ts.map