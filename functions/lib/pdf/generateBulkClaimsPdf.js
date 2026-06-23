"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateBulkClaimsPdf = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const jszip_1 = __importDefault(require("jszip"));
const crypto_1 = require("crypto");
const generatePodPdf_1 = require("./generatePodPdf");
const db = admin.firestore();
const MAX_CLAIMS = 50;
function sanitizeName(raw, fallback) {
    const cleaned = String(raw ?? '').replace(/[^A-Za-z0-9_-]/g, '').trim();
    return cleaned.length > 0 ? cleaned : fallback;
}
function enumLabel(value) {
    if (value === null || value === undefined)
        return 'N/A';
    const str = String(value);
    const dot = str.lastIndexOf('.');
    return dot >= 0 ? str.slice(dot + 1) : str;
}
async function buildClaimPdfBuffer(input) {
    const { claimId, claim, delivery, driver, vehicle, company, photoBytesList, documentBytesList, documentMetadata, customerSignatureBytes, approvalSignatureBytes, logoBytes, } = input;
    const doc = new pdfkit_1.default({ size: 'A4', margin: 40, bufferPages: true });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    const donePromise = new Promise((resolve, reject) => {
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);
    });
    const pageWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
    const generatedAt = new Date();
    if (logoBytes) {
        try {
            doc.image(logoBytes, doc.page.margins.left, doc.y, { fit: [60, 60] });
        }
        catch {
        }
    }
    const headerTextX = logoBytes ? doc.page.margins.left + 75 : doc.page.margins.left;
    const headerTextWidth = pageWidth - (logoBytes ? 75 : 0);
    let headerY = doc.y;
    if (company?.name) {
        doc.font('Helvetica-Bold').fontSize(16).fillColor('#1565C0').text(company.name, headerTextX, headerY, { width: headerTextWidth });
        headerY = doc.y + 4;
    }
    doc.font('Helvetica-Bold').fontSize(14).fillColor('#212121').text('CLAIM REPORT', headerTextX, headerY, { width: headerTextWidth });
    doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text('Official Claim Documentation', headerTextX, doc.y + 2, { width: headerTextWidth });
    doc.y = Math.max(doc.y, doc.page.margins.top + 70);
    doc.x = doc.page.margins.left;
    doc.moveDown(0.5);
    doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(2).strokeColor('#1565C0').stroke();
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(11).fillColor('#000000').text(`Claim ID: ${claimId}`, doc.page.margins.left, doc.y, { continued: false, width: pageWidth / 2 });
    doc.font('Helvetica').fontSize(10).fillColor('#000000').text(`Generated: ${(0, generatePodPdf_1.formatTimestamp)(generatedAt)}`, doc.page.margins.left + pageWidth / 2, doc.y - doc.currentLineHeight(), { align: 'right', width: pageWidth / 2 });
    doc.moveDown(1);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Claim Information');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Invoice Number', value: claim.invoiceNumber ?? 'N/A' },
        { label: 'Claim Type', value: enumLabel(claim.type) },
        { label: 'Status', value: enumLabel(claim.status) },
        { label: 'Claim Amount', value: `ZAR ${claim.claimAmount ?? '0.00'}` },
    ]);
    doc.moveDown(0.5);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Customer Information');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Customer Name', value: claim.customerName ?? 'N/A' },
        { label: 'Customer Number', value: claim.customerAccountNumber ?? 'N/A' },
        { label: 'Customer Address', value: delivery?.customerAddress ?? 'N/A' },
        { label: 'Customer Phone', value: delivery?.customerPhone ?? 'N/A' },
    ]);
    doc.moveDown(0.5);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Driver Information');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Driver Name', value: driver?.displayName ?? driver?.fullName ?? claim.driverName ?? 'N/A' },
        { label: 'Driver Phone', value: driver?.phoneNumber ?? 'N/A' },
        { label: 'License Number', value: driver?.licenseNumber ?? 'N/A' },
    ]);
    doc.moveDown(0.5);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Order Details');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Order Number', value: delivery?.orderNumber ?? 'N/A' },
        { label: 'Invoice Total', value: `${delivery?.currency ?? 'ZAR'} ${delivery?.invoiceTotal ?? 'N/A'}` },
        { label: 'Delivery Date', value: (0, generatePodPdf_1.formatTimestamp)(delivery?.scheduledDate) },
    ]);
    doc.moveDown(0.5);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Vehicle Information');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Vehicle Registration', value: delivery?.vehicleUsed ?? 'N/A' },
        { label: 'Make', value: vehicle?.make ?? 'N/A' },
        { label: 'Model', value: vehicle?.model ?? 'N/A' },
    ]);
    doc.moveDown(0.5);
    if (claim.gpsLocation && typeof claim.gpsLocation === 'object') {
        const gps = claim.gpsLocation;
        (0, generatePodPdf_1.drawSectionHeader)(doc, 'GPS Location');
        (0, generatePodPdf_1.drawInfoRows)(doc, [
            { label: 'Latitude', value: String(gps.latitude ?? 'N/A') },
            { label: 'Longitude', value: String(gps.longitude ?? 'N/A') },
            { label: 'Accuracy', value: `${typeof gps.accuracy === 'number' ? gps.accuracy.toFixed(1) : 'N/A'} meters` },
        ]);
        doc.moveDown(0.5);
    }
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Claim Description');
    doc.font('Helvetica').fontSize(12).fillColor('#000000').text(claim.description ?? 'No description provided', { width: pageWidth });
    doc.moveDown(0.8);
    (0, generatePodPdf_1.drawSectionHeader)(doc, 'Timeline');
    (0, generatePodPdf_1.drawInfoRows)(doc, [
        { label: 'Created', value: (0, generatePodPdf_1.formatTimestamp)(claim.createdAt) },
        { label: 'Last Updated', value: (0, generatePodPdf_1.formatTimestamp)(claim.updatedAt) },
    ]);
    doc.moveDown(0.5);
    if (typeof claim.resolutionNotes === 'string' && claim.resolutionNotes.length > 0) {
        (0, generatePodPdf_1.drawSectionHeader)(doc, 'Resolution Notes');
        doc.font('Helvetica').fontSize(12).fillColor('#000000').text(claim.resolutionNotes, { width: pageWidth });
        doc.moveDown(0.5);
    }
    if (customerSignatureBytes) {
        (0, generatePodPdf_1.drawSectionHeader)(doc, 'Customer Signature');
        (0, generatePodPdf_1.drawImageCentered)(doc, customerSignatureBytes, 300, 150);
    }
    if (approvalSignatureBytes) {
        (0, generatePodPdf_1.drawSectionHeader)(doc, 'Approval Signature');
        (0, generatePodPdf_1.drawImageCentered)(doc, approvalSignatureBytes, 300, 150);
    }
    doc.moveDown(0.5);
    doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(1).strokeColor('#E0E0E0').stroke();
    doc.moveDown(0.5);
    doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text(`This is an official Claim document. Document ID: ${claimId}`, { align: 'center' });
    const validPhotos = photoBytesList.filter((b) => b !== null);
    validPhotos.forEach((bytes, index) => {
        doc.addPage();
        doc.rect(doc.page.margins.left, doc.y, pageWidth, 30).fill('#E3F2FD');
        doc.fillColor('#0D47A1').font('Helvetica-Bold').fontSize(14).text(`Claim Photo ${index + 1} of ${validPhotos.length}`, doc.page.margins.left, doc.y - 22, { width: pageWidth, align: 'center' });
        doc.moveDown(1.5);
        try {
            doc.image(bytes, doc.page.margins.left, doc.y, { fit: [pageWidth, doc.page.height - doc.y - doc.page.margins.bottom], align: 'center' });
        }
        catch (error) {
            console.warn('generateBulkClaimsPdf: skipping unrenderable photo', error.message);
        }
    });
    const validDocuments = documentBytesList.filter((b) => b !== null);
    validDocuments.forEach((bytes, index) => {
        doc.addPage();
        doc.rect(doc.page.margins.left, doc.y, pageWidth, 30).fill('#E8F5E9');
        const docType = documentMetadata[index]?.type;
        doc.fillColor('#1B5E20').font('Helvetica-Bold').fontSize(14).text(`Scanned Document ${index + 1} of ${validDocuments.length}${docType ? ` — ${docType}` : ''}`, doc.page.margins.left, doc.y - 22, { width: pageWidth, align: 'center' });
        doc.moveDown(1.5);
        try {
            doc.image(bytes, doc.page.margins.left, doc.y, { fit: [pageWidth, doc.page.height - doc.y - doc.page.margins.bottom], align: 'center' });
        }
        catch (error) {
            console.warn('generateBulkClaimsPdf: skipping unrenderable document', error.message);
        }
    });
    doc.end();
    return donePromise;
}
exports.generateBulkClaimsPdf = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to export claims.');
    }
    const claimIds = Array.isArray(data?.claimIds) ? data.claimIds.filter((id) => typeof id === 'string' && id.trim().length > 0) : [];
    if (claimIds.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'claimIds must be a non-empty array.');
    }
    if (claimIds.length > MAX_CLAIMS) {
        throw new functions.https.HttpsError('invalid-argument', `Too many claims requested (${claimIds.length}); limit is ${MAX_CLAIMS} per export.`);
    }
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const caller = callerDoc.data();
    if (!callerDoc.exists || !caller || caller.isActive !== true) {
        throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
    }
    if (caller.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Administrator role required to bulk-export claims.');
    }
    const companyId = caller.companyId;
    if (typeof companyId !== 'string' || companyId.length === 0) {
        throw new functions.https.HttpsError('permission-denied', 'Caller is not associated with a company.');
    }
    const companyDoc = await db.collection('companies').doc(companyId).get();
    const company = companyDoc.data();
    const zip = new jszip_1.default();
    let included = 0;
    let skipped = 0;
    for (const claimId of claimIds) {
        try {
            const claimDoc = await db.collection('companies').doc(companyId).collection('claims').doc(claimId).get();
            if (!claimDoc.exists) {
                skipped++;
                continue;
            }
            const claim = claimDoc.data();
            let delivery;
            if (typeof claim.deliveryId === 'string' && claim.deliveryId.length > 0) {
                const deliveryDoc = await db.collection('deliveries').doc(claim.deliveryId).get();
                delivery = deliveryDoc.data();
            }
            let driver;
            if (typeof claim.driverId === 'string' && claim.driverId.length > 0) {
                const driverDoc = await db.collection('users').doc(claim.driverId).get();
                driver = driverDoc.data();
            }
            let vehicle;
            if (delivery?.vehicleUsed) {
                const vehicleSnapshot = await db
                    .collection('companies').doc(companyId).collection('vehicles')
                    .where('registration', '==', (0, generatePodPdf_1.normalizeRegistration)(delivery.vehicleUsed))
                    .limit(1)
                    .get();
                vehicle = vehicleSnapshot.empty ? undefined : vehicleSnapshot.docs[0].data();
            }
            const photoUrls = Array.isArray(claim.photoUrls) ? claim.photoUrls.filter((u) => typeof u === 'string' && u.length > 0) : [];
            const documentUrls = Array.isArray(claim.documentUrls) ? claim.documentUrls.filter((u) => typeof u === 'string' && u.length > 0) : [];
            const documentMetadata = Array.isArray(claim.documentMetadata) ? claim.documentMetadata : [];
            const [photoBytesList, documentBytesList, customerSignatureBytes, approvalSignatureBytes, logoBytes] = await Promise.all([
                Promise.all(photoUrls.map(generatePodPdf_1.fetchImageBytes)),
                Promise.all(documentUrls.map(generatePodPdf_1.fetchImageBytes)),
                (0, generatePodPdf_1.fetchImageBytes)(claim.customerSignatureUrl),
                (0, generatePodPdf_1.fetchImageBytes)(claim.signatureUrl),
                (0, generatePodPdf_1.fetchImageBytes)(company?.logoUrl),
            ]);
            const pdfBuffer = await buildClaimPdfBuffer({
                claimId, claim, delivery, driver, vehicle, company,
                photoBytesList, documentBytesList, documentMetadata,
                customerSignatureBytes, approvalSignatureBytes, logoBytes,
            });
            const baseName = sanitizeName(claim.invoiceNumber ?? claimId, claimId);
            zip.file(`Claim_${baseName}.pdf`, pdfBuffer);
            included++;
        }
        catch (error) {
            console.warn('generateBulkClaimsPdf: skipping claim due to error', claimId, error.message);
            skipped++;
        }
    }
    if (included === 0) {
        throw new functions.https.HttpsError('not-found', 'No claims could be exported (none found in your company, or all fetches failed).');
    }
    const zipBuffer = await zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
    const bucket = admin.storage().bucket();
    const filePath = `companies/${companyId}/exports/claims_${Date.now()}.zip`;
    const file = bucket.file(filePath);
    const downloadToken = (0, crypto_1.randomUUID)();
    await file.save(zipBuffer, {
        metadata: {
            contentType: 'application/zip',
            metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
    });
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${downloadToken}`;
    return { success: true, downloadUrl, included, skipped };
});
//# sourceMappingURL=generateBulkClaimsPdf.js.map