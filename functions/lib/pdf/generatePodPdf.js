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
exports.generatePodPdf = void 0;
exports.normalizeRegistration = normalizeRegistration;
exports.formatTimestamp = formatTimestamp;
exports.fetchImageBytes = fetchImageBytes;
exports.drawSectionHeader = drawSectionHeader;
exports.drawInfoRows = drawInfoRows;
exports.drawImageCentered = drawImageCentered;
exports.buildPodPdfBuffer = buildPodPdfBuffer;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const crypto_1 = require("crypto");
const db = admin.firestore();
function normalizeRegistration(registration) {
    if (registration.trim().length === 0)
        return '';
    return registration.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
}
async function fetchImageBytes(url) {
    if (!url)
        return null;
    try {
        const response = await axios_1.default.get(url, { responseType: 'arraybuffer', timeout: 15000 });
        return Buffer.from(response.data);
    }
    catch (error) {
        console.warn('generatePodPdf: failed to fetch image, omitting from report', url, error.message);
        return null;
    }
}
function formatDateTime(date) {
    return date.toLocaleString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit',
    });
}
function formatTimestamp(value) {
    if (!value)
        return 'N/A';
    try {
        if (value instanceof Date)
            return formatDateTime(value);
        if (typeof value === 'number')
            return formatDateTime(new Date(value));
        if (typeof value === 'string') {
            const parsed = new Date(value);
            return isNaN(parsed.getTime()) ? 'N/A' : formatDateTime(parsed);
        }
        if (typeof value === 'object' && value !== null) {
            const v = value;
            if (typeof v.toDate === 'function')
                return formatDateTime(v.toDate());
            const secs = v.seconds ?? v._seconds;
            if (typeof secs === 'number')
                return formatDateTime(new Date(secs * 1000));
        }
    }
    catch {
    }
    return 'N/A';
}
function formatGeneratedAt(date) {
    return date.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' });
}
function drawSectionHeader(doc, title) {
    doc.font('Helvetica-Bold').fontSize(13).fillColor('#1565C0').text(title);
    doc.moveDown(0.3);
}
function drawInfoRows(doc, rows) {
    const left = doc.x;
    const indented = left + 10;
    const labelWidth = 110;
    for (const row of rows) {
        const y = doc.y;
        doc.font('Helvetica-Bold').fontSize(11).fillColor('#616161').text(row.label, indented, y, { width: labelWidth, continued: false });
        doc.font('Helvetica').fontSize(11).fillColor('#000000').text(row.value, indented + labelWidth, y, { width: doc.page.width - indented - labelWidth - 40 });
        doc.moveDown(0.15);
    }
    doc.x = left;
    doc.moveDown(0.5);
}
function drawImageCentered(doc, bytes, maxWidth, maxHeight) {
    try {
        doc.image(bytes, { fit: [maxWidth, maxHeight], align: 'center' });
    }
    catch (error) {
        console.warn('generatePodPdf: skipping unrenderable image', error.message);
    }
    doc.moveDown(0.5);
}
async function buildPodPdfBuffer(input) {
    const { deliveryId, pod, delivery, driver, vehicle, company, photoBytesList, documentBytesList, documentMetadata, signatureBytes, stampBytes, logoBytes, } = input;
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
            doc.image(logoBytes, doc.page.margins.left, doc.y, { fit: [80, 80] });
        }
        catch {
        }
    }
    const headerTextX = logoBytes ? doc.page.margins.left + 95 : doc.page.margins.left;
    const headerTextWidth = pageWidth - (logoBytes ? 95 : 0);
    let headerY = doc.y;
    if (company?.name) {
        doc.font('Helvetica-Bold').fontSize(16).fillColor('#1565C0').text(company.name, headerTextX, headerY, { width: headerTextWidth });
        headerY = doc.y + 4;
    }
    doc.font('Helvetica-Bold').fontSize(14).fillColor('#212121').text('PROOF OF DELIVERY (POD) REPORT', headerTextX, headerY, { width: headerTextWidth });
    doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text('Official Delivery Documentation', headerTextX, doc.y + 2, { width: headerTextWidth });
    doc.y = Math.max(doc.y, doc.page.margins.top + 90);
    doc.x = doc.page.margins.left;
    doc.moveDown(0.5);
    doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(2).strokeColor('#1565C0').stroke();
    doc.moveDown(0.5);
    doc.font('Helvetica-Bold').fontSize(11).fillColor('#000000').text(`POD ID: ${deliveryId}`, doc.page.margins.left, doc.y, { continued: false, width: pageWidth / 2 });
    doc.font('Helvetica').fontSize(10).fillColor('#000000').text(`Generated: ${formatGeneratedAt(generatedAt)}`, doc.page.margins.left + pageWidth / 2, doc.y - doc.currentLineHeight(), { align: 'right', width: pageWidth / 2 });
    doc.moveDown(1);
    drawSectionHeader(doc, 'Customer Information');
    drawInfoRows(doc, [
        { label: 'Customer Name', value: delivery?.customerName ?? 'N/A' },
        { label: 'Customer Number', value: delivery?.customerNumber ?? 'N/A' },
        { label: 'Address', value: delivery?.customerAddress ?? 'N/A' },
        { label: 'Phone', value: delivery?.customerPhone ?? 'N/A' },
        { label: 'Receiver Name', value: pod.receiverName ?? 'Not specified' },
    ]);
    drawSectionHeader(doc, 'Order & Invoice Details');
    drawInfoRows(doc, [
        { label: 'Order Number', value: delivery?.orderNumber ?? 'N/A' },
        { label: 'Invoice Number', value: delivery?.invoiceNumber ?? 'N/A' },
        { label: 'Invoice Total', value: `${delivery?.currency ?? 'ZAR'} ${delivery?.invoiceTotal ?? 'N/A'}` },
    ]);
    drawSectionHeader(doc, 'Driver Information');
    drawInfoRows(doc, [
        { label: 'Driver Name', value: driver?.fullName ?? driver?.displayName ?? 'N/A' },
        { label: 'Driver Phone', value: driver?.phoneNumber ?? 'N/A' },
        { label: 'License Number', value: driver?.licenseNumber ?? 'N/A' },
    ]);
    drawSectionHeader(doc, 'Vehicle Information');
    drawInfoRows(doc, [
        { label: 'Vehicle Registration', value: delivery?.vehicleUsed ?? 'N/A' },
        { label: 'Make', value: vehicle?.make ?? 'N/A' },
        { label: 'Model', value: vehicle?.model ?? 'N/A' },
    ]);
    if (pod.timestamp) {
        drawSectionHeader(doc, 'Delivery Time');
        drawInfoRows(doc, [{ label: 'Completed At', value: formatDateTime(pod.timestamp.toDate()) }]);
    }
    if (pod.location) {
        drawSectionHeader(doc, 'GPS Location');
        drawInfoRows(doc, [
            { label: 'Latitude', value: String(pod.location.latitude ?? 'N/A') },
            { label: 'Longitude', value: String(pod.location.longitude ?? 'N/A') },
            { label: 'Accuracy', value: `${pod.location.accuracy?.toFixed?.(1) ?? pod.location.accuracy ?? 'N/A'} meters` },
        ]);
    }
    if (signatureBytes) {
        drawSectionHeader(doc, 'Customer Signature');
        if (pod.receiverName) {
            doc.font('Helvetica-Bold').fontSize(12).fillColor('#424242').text(`Received by: ${pod.receiverName}`, { align: 'center' });
            doc.moveDown(0.3);
        }
        drawImageCentered(doc, signatureBytes, 300, 150);
    }
    if (stampBytes) {
        drawSectionHeader(doc, 'Corporate Store Receipt Stamp');
        drawImageCentered(doc, stampBytes, 300, 200);
    }
    if (pod.notes) {
        drawSectionHeader(doc, 'Delivery Notes');
        doc.font('Helvetica').fontSize(11).fillColor('#000000').text(pod.notes, { width: pageWidth });
        doc.moveDown(0.5);
    }
    doc.moveDown(0.5);
    doc.moveTo(doc.page.margins.left, doc.y).lineTo(doc.page.width - doc.page.margins.right, doc.y).lineWidth(1).strokeColor('#E0E0E0').stroke();
    doc.moveDown(0.5);
    doc.font('Helvetica-Oblique').fontSize(10).fillColor('#9E9E9E').text(`This is an official Proof of Delivery document. Document ID: ${deliveryId}`, { align: 'center' });
    const validPhotos = photoBytesList.filter((b) => b !== null);
    validPhotos.forEach((bytes, index) => {
        doc.addPage();
        doc.rect(doc.page.margins.left, doc.y, pageWidth, 30).fill('#E3F2FD');
        doc.fillColor('#0D47A1').font('Helvetica-Bold').fontSize(14).text(`Delivery Photo ${index + 1} of ${validPhotos.length}`, doc.page.margins.left, doc.y - 22, { width: pageWidth, align: 'center' });
        doc.moveDown(1.5);
        try {
            doc.image(bytes, doc.page.margins.left, doc.y, { fit: [pageWidth, doc.page.height - doc.y - doc.page.margins.bottom], align: 'center' });
        }
        catch (error) {
            console.warn('generatePodPdf: skipping unrenderable photo', error.message);
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
            console.warn('generatePodPdf: skipping unrenderable document', error.message);
        }
    });
    doc.end();
    return donePromise;
}
exports.generatePodPdf = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to generate a POD PDF.');
    }
    const deliveryId = typeof data?.deliveryId === 'string' ? data.deliveryId.trim() : '';
    if (!deliveryId) {
        throw new functions.https.HttpsError('invalid-argument', 'deliveryId is required.');
    }
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    const caller = callerDoc.data();
    if (!callerDoc.exists || !caller || caller.isActive !== true) {
        throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
    }
    const podDoc = await db.collection('pods').doc(deliveryId).get();
    if (!podDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'POD record not found.');
    }
    const pod = podDoc.data();
    if (pod.companyId !== caller.companyId) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot access a POD from another company.');
    }
    const deliveryDoc = await db.collection('deliveries').doc(deliveryId).get();
    const delivery = deliveryDoc.data();
    const [driverDoc, companyDoc] = await Promise.all([
        delivery?.driverId ? db.collection('users').doc(delivery.driverId).get() : Promise.resolve(null),
        db.collection('companies').doc(pod.companyId).get(),
    ]);
    const driver = driverDoc?.data();
    const company = companyDoc.data();
    let vehicle;
    if (delivery?.vehicleUsed) {
        const vehicleSnapshot = await db
            .collection('companies').doc(pod.companyId).collection('vehicles')
            .where('registration', '==', normalizeRegistration(delivery.vehicleUsed))
            .limit(1)
            .get();
        vehicle = vehicleSnapshot.empty ? undefined : vehicleSnapshot.docs[0].data();
    }
    const photoUrls = Array.isArray(pod.photoUrls) && pod.photoUrls.length > 0
        ? pod.photoUrls
        : (pod.photoUrl ? [pod.photoUrl] : []);
    const documentUrls = Array.isArray(pod.documentUrls) ? pod.documentUrls : [];
    const documentMetadata = Array.isArray(pod.documentMetadata) ? pod.documentMetadata : [];
    const [photoBytesList, documentBytesList, signatureBytes, stampBytes, logoBytes] = await Promise.all([
        Promise.all(photoUrls.map(fetchImageBytes)),
        Promise.all(documentUrls.map(fetchImageBytes)),
        fetchImageBytes(pod.signatureUrl),
        fetchImageBytes(pod.stampPhotoUrl),
        fetchImageBytes(company?.logoUrl),
    ]);
    const pdfBuffer = await buildPodPdfBuffer({
        deliveryId, pod, delivery, driver, vehicle, company,
        photoBytesList, documentBytesList, documentMetadata,
        signatureBytes, stampBytes, logoBytes,
    });
    const bucket = admin.storage().bucket();
    const filePath = `pods/${deliveryId}/report_${Date.now()}.pdf`;
    const file = bucket.file(filePath);
    const downloadToken = (0, crypto_1.randomUUID)();
    await file.save(pdfBuffer, {
        metadata: {
            contentType: 'application/pdf',
            metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
    });
    const pdfUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${downloadToken}`;
    await db.collection('pods').doc(deliveryId).update({ pdfUrl, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    return { success: true, pdfUrl };
});
//# sourceMappingURL=generatePodPdf.js.map