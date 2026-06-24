/* eslint-disable no-console */
/**
 * Seed demo data into the LIVE podsafe-f4a47 Firestore + Auth so the desktop web UI
 * and the mobile app can be exercised end-to-end.
 *
 * Usage (from repo root, after `gcloud auth application-default login`):
 *   node scripts/seedLiveData.js          # create/overwrite the demo dataset
 *   node scripts/seedLiveData.js --wipe   # delete all seeded docs (keeps the 3 users + company)
 *
 * Everything is written against company `default-company` (the company the two existing
 * test users already reference). Non-user docs use deterministic `seed-*` IDs and carry a
 * `seeded: true` flag, so re-running is idempotent and cleanup is a single query.
 *
 * Field shapes mirror the *.converters.ts files exactly. The Admin SDK bypasses the
 * Firestore security rules, so this works regardless of the strict company/admin gating.
 */
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const PROJECT_ID = 'podsafe-f4a47';
const COMPANY_ID = 'default-company';
const DEMO_PASSWORD = 'PodSafe123!';

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();
const { Timestamp } = admin.firestore;
const TS = (d) => Timestamp.fromDate(d);

// ---------------------------------------------------------------------------
// Date helpers (relative to "now" so the dataset always looks fresh)
// ---------------------------------------------------------------------------
const now = new Date();
const day = 24 * 60 * 60 * 1000;
const daysAgo = (n) => new Date(now.getTime() - n * day);
const daysFromNow = (n) => new Date(now.getTime() + n * day);
const atHour = (date, h) => { const d = new Date(date); d.setHours(h, 0, 0, 0); return d; };

// Cape Town-ish coordinates for the map widgets
const CT = { lat: -33.9249, lng: 18.4241 };
const jitter = (base, spread) => base + (Math.random() - 0.5) * spread;

// ---------------------------------------------------------------------------
// Users (reuse the two existing accounts, add a second driver)
// ---------------------------------------------------------------------------
async function ensureAuthUser(email, displayName) {
  let user;
  try {
    user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, { password: DEMO_PASSWORD, displayName, emailVerified: true, disabled: false });
    console.log(`  · reused auth user ${email} (${user.uid}) — password reset to demo password`);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({ email, password: DEMO_PASSWORD, displayName, emailVerified: true });
    console.log(`  · created auth user ${email} (${user.uid})`);
  }
  return user.uid;
}

function userDoc({ email, fullName, role, uid }) {
  return {
    email,
    fullName,
    displayName: fullName,
    role,
    companyId: COMPANY_ID,
    phoneNumber: role === 'driver' ? '+27821234567' : '+27827654321',
    profileImageUrl: null,
    isActive: true,
    approvalStatus: 'approved',
    createdAt: TS(daysAgo(40)),
    lastLoginAt: TS(daysAgo(0)),
    ...(role === 'driver' ? { licenseNumber: `EC-${uid.slice(0, 6).toUpperCase()}`, vehicleInfo: 'CA 123-456' } : {}),
  };
}

// ---------------------------------------------------------------------------
// Static reference data
// ---------------------------------------------------------------------------
const VEHICLES = [
  { id: 'seed-veh-001', registration: 'CA 123-456', make: 'Toyota', model: 'Hilux', color: 'White', status: 'active', totalDeliveries: 142 },
  { id: 'seed-veh-002', registration: 'CA 789-012', make: 'Isuzu', model: 'NPR 400', color: 'White', status: 'active', totalDeliveries: 88 },
  { id: 'seed-veh-003', registration: 'CY 555-888', make: 'Ford', model: 'Transit', color: 'Silver', status: 'maintenance', totalDeliveries: 53 },
];

const CUSTOMERS = [
  { id: 'seed-cust-001', customerNumber: 'CUST001', name: 'Pick n Pay Claremont', address: 'Stadium on Main, Claremont, Cape Town, 7708', contactPerson: 'Thandi Nkosi', phone: '+27214567890', email: 'receiving@pnp-claremont.co.za', customerType: 'business', isFavorite: true },
  { id: 'seed-cust-002', customerNumber: 'CUST002', name: 'Checkers Sea Point', address: 'Main Rd, Sea Point, Cape Town, 8005', contactPerson: 'Riaan Botha', phone: '+27214561111', email: 'deliveries@checkers-sp.co.za', customerType: 'business', isFavorite: false },
  { id: 'seed-cust-003', customerNumber: 'CUST003', name: 'Builders Warehouse Tokai', address: 'Vans Rd, Tokai, Cape Town, 7945', contactPerson: 'Grace Mahlangu', phone: '+27217012345', email: 'goods@builders-tokai.co.za', customerType: 'business', isFavorite: true },
  { id: 'seed-cust-004', customerNumber: 'CUST004', name: 'Dis-Chem Canal Walk', address: 'Century Blvd, Century City, 7441', contactPerson: 'Pieter van Wyk', phone: '+27215552020', email: 'stock@dischem-cw.co.za', customerType: 'business', isFavorite: false },
  { id: 'seed-cust-005', customerNumber: 'CUST005', name: 'Woolworths V&A', address: 'Victoria Wharf, V&A Waterfront, 8001', contactPerson: 'Lerato Dube', phone: '+27214184000', email: 'receiving@woolies-va.co.za', customerType: 'business', isFavorite: false },
  { id: 'seed-cust-006', customerNumber: 'CUST006', name: 'Game Kenilworth', address: 'Kenilworth Centre, Doncaster Rd, 7708', contactPerson: 'Sipho Khumalo', phone: '+27216831200', email: 'deliveries@game-ken.co.za', customerType: 'business', isFavorite: false },
  { id: 'seed-cust-007', customerNumber: 'CUST007', name: 'Clicks Bellville', address: 'Tyger Valley Centre, Bellville, 7530', contactPerson: 'Anita Pillay', phone: '+27219149000', email: 'goods@clicks-bv.co.za', customerType: 'business', isFavorite: false },
  { id: 'seed-cust-008', customerNumber: 'CUST008', name: 'Makro Ottery', address: 'Ottery Rd, Ottery, Cape Town, 7800', contactPerson: 'Johan Smit', phone: '+27217045000', email: 'receiving@makro-ottery.co.za', customerType: 'business', isFavorite: true },
];

const CATALOG = [
  { id: 'seed-cat-001', description: 'Bottled Water 500ml (24pk)', sku: 'BW-500-24', unit: 'case', unitPrice: 89.99, category: 'bulkGoods', usageCount: 210 },
  { id: 'seed-cat-002', description: 'A4 Copy Paper (Box of 5)', sku: 'PP-A4-5', unit: 'box', unitPrice: 249.0, category: 'officeSupplies', usageCount: 75 },
  { id: 'seed-cat-003', description: 'Office Chair - Ergonomic', sku: 'FU-CH-ERG', unit: 'unit', unitPrice: 1899.0, category: 'furniture', usageCount: 18 },
  { id: 'seed-cat-004', description: 'LED Monitor 24"', sku: 'EL-MON-24', unit: 'unit', unitPrice: 2399.0, category: 'electronics', usageCount: 42 },
  { id: 'seed-cat-005', description: 'Cleaning Detergent 5L', sku: 'CL-DET-5L', unit: 'unit', unitPrice: 119.5, category: 'general', usageCount: 130 },
  { id: 'seed-cat-006', description: 'Cardboard Boxes (Bundle of 25)', sku: 'PK-BOX-25', unit: 'bundle', unitPrice: 175.0, category: 'general', usageCount: 64 },
  { id: 'seed-cat-007', description: 'Steel Shelving Unit', sku: 'EQ-SHELF-01', unit: 'unit', unitPrice: 949.0, category: 'equipment', usageCount: 9 },
  { id: 'seed-cat-008', description: 'Delivery Note Pads (50s)', sku: 'DO-NOTE-50', unit: 'pad', unitPrice: 35.0, category: 'documents', usageCount: 12 },
  { id: 'seed-cat-009', description: 'Pallet Wrap 500m', sku: 'PK-WRAP-500', unit: 'roll', unitPrice: 145.0, category: 'bulkGoods', usageCount: 88 },
  { id: 'seed-cat-010', description: 'First Aid Kit - Regulation 7', sku: 'GN-FAK-R7', unit: 'unit', unitPrice: 425.0, category: 'other', usageCount: 5 },
];

// ---------------------------------------------------------------------------
// Deliveries — spread across statuses, dates, and both drivers
// ---------------------------------------------------------------------------
function buildDeliveries(driver1, driver2) {
  const c = (i) => CUSTOMERS[i];
  const item = (description, quantity, unitPrice) => ({ description, quantity, unit: 'unit', unitPrice, totalPrice: +(quantity * unitPrice).toFixed(2) });

  // [custIndex, status, scheduledDate, driverId, vehicle, items[], notes?]
  const rows = [
    [0, 'delivered', daysAgo(6), driver1, 'CA 123-456', [item('Bottled Water 500ml (24pk)', 20, 89.99), item('Cleaning Detergent 5L', 10, 119.5)]],
    [1, 'delivered', daysAgo(6), driver1, 'CA 123-456', [item('A4 Copy Paper (Box of 5)', 8, 249)]],
    [2, 'delivered', daysAgo(5), driver2, 'CA 789-012', [item('Steel Shelving Unit', 4, 949), item('Cardboard Boxes (Bundle of 25)', 6, 175)]],
    [3, 'delivered', daysAgo(5), driver1, 'CA 123-456', [item('LED Monitor 24"', 12, 2399)]],
    [4, 'delivered', daysAgo(4), driver1, 'CA 123-456', [item('Pallet Wrap 500m', 15, 145)]],
    [5, 'delivered', daysAgo(4), driver2, 'CA 789-012', [item('Office Chair - Ergonomic', 6, 1899)]],
    [6, 'delivered', daysAgo(3), driver1, 'CA 123-456', [item('Bottled Water 500ml (24pk)', 30, 89.99)]],
    [7, 'delivered', daysAgo(2), driver1, 'CA 123-456', [item('Cleaning Detergent 5L', 24, 119.5), item('First Aid Kit - Regulation 7', 2, 425)]],
    [0, 'failed', daysAgo(3), driver1, 'CA 123-456', [item('A4 Copy Paper (Box of 5)', 5, 249)], 'Customer closed on arrival — reschedule'],
    [4, 'failed', daysAgo(2), driver2, 'CA 789-012', [item('Steel Shelving Unit', 2, 949)], 'Damaged in transit, returned to depot'],
    [1, 'inTransit', atHour(now, 9), driver1, 'CA 123-456', [item('LED Monitor 24"', 6, 2399)]],
    [2, 'inTransit', atHour(now, 10), driver1, 'CA 123-456', [item('Pallet Wrap 500m', 10, 145), item('Cardboard Boxes (Bundle of 25)', 4, 175)]],
    [5, 'inTransit', atHour(now, 11), driver2, 'CA 789-012', [item('Bottled Water 500ml (24pk)', 18, 89.99)]],
    [3, 'pending', atHour(now, 14), driver1, 'CA 123-456', [item('Office Chair - Ergonomic', 3, 1899)]],
    [6, 'pending', atHour(now, 15), driver1, 'CA 123-456', [item('Cleaning Detergent 5L', 12, 119.5)]],
    [7, 'pending', atHour(daysFromNow(1), 9), driver1, 'CA 123-456', [item('Delivery Note Pads (50s)', 20, 35)]],
    [0, 'pending', atHour(daysFromNow(1), 11), driver2, 'CA 789-012', [item('Bottled Water 500ml (24pk)', 25, 89.99)]],
    [2, 'pending', atHour(daysFromNow(2), 10), driver1, 'CA 123-456', [item('First Aid Kit - Regulation 7', 4, 425)]],
    [4, 'pending', atHour(daysFromNow(2), 13), driver1, 'CA 123-456', [item('LED Monitor 24"', 8, 2399)]],
    [5, 'pending', atHour(daysFromNow(3), 9), driver2, 'CA 789-012', [item('Steel Shelving Unit', 5, 949)]],
  ];

  return rows.map((r, idx) => {
    const [ci, status, scheduled, driverId, vehicle, items, notes] = r;
    const cust = c(ci);
    const subtotal = items.reduce((s, it) => s + (it.totalPrice || 0), 0);
    const tax = +(subtotal * 0.15).toFixed(2);
    const id = `seed-del-${String(idx + 1).padStart(3, '0')}`;
    const createdAt = new Date(scheduled.getTime() - 1 * day);
    const delivered = status === 'delivered';
    return {
      id,
      data: {
        seeded: true,
        companyId: COMPANY_ID,
        driverId,
        customerName: cust.name,
        customerAddress: cust.address,
        customerPhone: cust.phone,
        customerId: cust.id,
        customerNumber: cust.customerNumber,
        orderNumber: `ORD-${1000 + idx}`,
        invoiceNumber: `INV-${5000 + idx}`,
        invoiceDate: TS(createdAt),
        items: items.map((it) => ({ description: it.description, quantity: it.quantity, unit: it.unit, unitPrice: it.unitPrice, totalPrice: it.totalPrice })),
        invoiceTotal: +(subtotal + tax).toFixed(2),
        taxAmount: tax,
        discountAmount: 0,
        currency: 'ZAR',
        vehicleUsed: vehicle,
        isThirdPartyTransport: false,
        thirdPartyProviderName: null,
        thirdPartyDriverName: null,
        thirdPartyDriverPhone: null,
        thirdPartyVehicleInfo: null,
        uploadToken: null,
        thirdPartyDocs: null,
        status,
        scheduledDate: TS(scheduled),
        createdAt: TS(createdAt),
        deliveredAt: delivered ? TS(scheduled) : null,
        notes: notes || null,
        podId: delivered ? id : null, // pods/{deliveryId}
      },
      // carry context for POD/claim generation
      _ctx: { status, driverId, cust, scheduled, invoiceNumber: `INV-${5000 + idx}` },
    };
  });
}

// ---------------------------------------------------------------------------
// PODs (for delivered deliveries) — top-level pods/{deliveryId}
// ---------------------------------------------------------------------------
function buildPod(delivery, driverName) {
  const { _ctx, id } = delivery;
  return {
    id,
    data: {
      seeded: true,
      companyId: COMPANY_ID,
      driverId: _ctx.driverId,
      deliveryId: id,
      customerName: _ctx.cust.name,
      invoiceNumber: _ctx.invoiceNumber,
      status: 'signed',
      timestamp: TS(_ctx.scheduled),
      location: {
        latitude: jitter(CT.lat, 0.15),
        longitude: jitter(CT.lng, 0.15),
        address: _ctx.cust.address,
        accuracy: 8,
      },
      signedBy: _ctx.cust.contactPerson || _ctx.cust.name,
      signatureUrl: null,
      photoUrl: null,
      photoUrls: null,
      documentUrls: null,
      documentMetadata: null,
      pdfUrl: null,
      metadata: { capturedVia: 'seed', deviceModel: 'Demo' },
      createdAt: TS(_ctx.scheduled),
      updatedAt: TS(_ctx.scheduled),
      ocrRawText: null,
      ocrFields: null,
      ocrConfidence: 0.92,
      detectionFlags: { hasSignature: true, hasStamp: false, ocrConfident: true, warnings: [], ocrConfidenceScore: 0.92 },
    },
  };
}

// ---------------------------------------------------------------------------
// Claims (company subcollection) — dates as ISO strings per claim.converters.ts
// ---------------------------------------------------------------------------
function buildClaims(deliveries, driver1, driver1Name, adminUid) {
  const delivered = deliveries.filter((d) => d._ctx.status === 'delivered');
  const ISO = (d) => d.toISOString();
  const pick = (i) => delivered[i % delivered.length];

  const defs = [
    { type: 'damaged', status: 'submitted', priority: 'high', title: 'Damaged stock on arrival', desc: '3 monitors arrived with cracked screens.', amount: 7197 },
    { type: 'shortage', status: 'investigating', priority: 'medium', title: 'Short delivered — 4 cases missing', desc: 'Invoice shows 30 cases, only 26 received.', amount: 359.96 },
    { type: 'lateDelivery', status: 'resolved', priority: 'low', title: 'Delivery arrived after cut-off', desc: 'Goods received 2 hours after the agreed window.', amount: 0, resolution: 'noAction' },
    { type: 'returns', status: 'pendingApproval', priority: 'medium', title: 'Customer return — wrong size', desc: 'Customer returned 6 shelving units, wrong dimensions.', amount: 5694 },
  ];

  return defs.map((def, i) => {
    const del = pick(i);
    const created = daysAgo(delivered.length - i);
    const id = `seed-claim-${String(i + 1).padStart(3, '0')}`;
    const resolved = def.status === 'resolved';
    return {
      id,
      data: {
        seeded: true,
        id,
        companyId: COMPANY_ID,
        claimNumber: `CLM-2026-${String(i + 1).padStart(4, '0')}`,
        type: def.type,
        status: def.status,
        priority: def.priority,
        filingContext: 'afterDelivery',
        title: def.title,
        description: def.desc,
        deliveryId: del.id,
        podId: del.id,
        customerId: del._ctx.cust.id,
        customerName: del._ctx.cust.name,
        customerNumber: del._ctx.cust.customerNumber,
        customerAccountNumber: null,
        driverId: del._ctx.driverId,
        driverName: driver1Name,
        invoiceNumber: del._ctx.invoiceNumber,
        claimAmount: def.amount,
        creditNoteNumber: null,
        debitNoteNumber: null,
        createdAt: ISO(created),
        updatedAt: ISO(created),
        resolvedAt: resolved ? ISO(daysAgo(1)) : null,
        dueDate: ISO(daysFromNow(5 - i)),
        deliveryDate: ISO(del._ctx.scheduled),
        filedBy: adminUid,
        filedByName: 'Admin User',
        filedByRole: 'admin',
        photoUrls: [],
        customerSignatureUrl: null,
        driverSignatureUrl: null,
        gpsLocation: {},
        metadata: {},
        documentUrls: [],
        documentMetadata: [],
        approvalChain: [],
        currentApprovalLevel: 0,
        customerAcknowledged: null,
        filedAtDelivery: null,
        driverNotified: true,
        driverResponded: i % 2 === 0,
        driverResponse: i % 2 === 0 ? 'Acknowledged — was sealed when it left the depot.' : null,
        driverEvidenceUrls: [],
        daysAfterDelivery: 1,
        affectedItems: [],
        investigatedBy: null,
        investigatorName: null,
        investigationNotes: null,
        investigationDate: null,
        resolution: def.resolution || null,
        resolutionNotes: resolved ? 'Closed — within SLA, no credit due.' : null,
        resolvedBy: resolved ? adminUid : null,
        resolvedByName: resolved ? 'Admin User' : null,
        evidenceQualityScore: 6,
        hasAllRequiredEvidence: false,
        comments: [],
        statusHistory: [
          { status: 'submitted', timestamp: ISO(created), userId: adminUid, userName: 'Admin User', notes: 'Filed', metadata: null },
        ],
        customFields: [],
        externalSystemId: null,
        externalSystemData: null,
        isFraudulent: false,
        isEscalated: false,
        isRecurring: false,
        recurringClaimGroupId: null,
        evidenceStatus: 'pending',
        evidenceReceivedAt: null,
        photoCount: 0,
        hasSignature: false,
        hasDocuments: false,
      },
    };
  });
}

// ---------------------------------------------------------------------------
// Batch commit helper (Firestore caps batches at 500 writes)
// ---------------------------------------------------------------------------
async function commitAll(writes) {
  for (let i = 0; i < writes.length; i += 450) {
    const batch = db.batch();
    for (const w of writes.slice(i, i + 450)) batch.set(w.ref, w.data, { merge: false });
    await batch.commit();
  }
}

// ---------------------------------------------------------------------------
// Wipe (delete seeded docs only)
// ---------------------------------------------------------------------------
async function wipe() {
  console.log('Wiping seeded docs (seeded == true)…');
  const targets = [
    db.collection('deliveries'),
    db.collection('customers'),
    db.collection('pods'),
    db.collection('companies').doc(COMPANY_ID).collection('vehicles'),
    db.collection('companies').doc(COMPANY_ID).collection('itemCatalog'),
    db.collection('companies').doc(COMPANY_ID).collection('claims'),
  ];
  let total = 0;
  for (const col of targets) {
    const snap = await col.where('seeded', '==', true).get();
    for (let i = 0; i < snap.docs.length; i += 450) {
      const batch = db.batch();
      snap.docs.slice(i, i + 450).forEach((d) => batch.delete(d.ref));
      await batch.commit();
    }
    total += snap.size;
    console.log(`  · deleted ${snap.size} from ${col.path}`);
  }
  console.log(`Done. Deleted ${total} seeded docs. (Users + company doc left intact.)`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  if (process.argv.includes('--wipe')) { await wipe(); return; }

  console.log(`Seeding demo data into ${PROJECT_ID} / company ${COMPANY_ID}\n`);

  console.log('Users:');
  const adminUid = await ensureAuthUser('admin@podsafe.com', 'Admin User');
  const driver1 = await ensureAuthUser('driver@podsafe.com', 'Driver User');
  const driver2 = await ensureAuthUser('driver2@podsafe.com', 'Sam Adams');

  const writes = [];

  // Company
  writes.push({
    ref: db.collection('companies').doc(COMPANY_ID),
    data: {
      name: 'PODSafe Logistics',
      address: '14 Marine Drive, Paarden Eiland, Cape Town, 7405',
      email: 'ops@podsafe.com',
      phone: '+27215105000',
      registrationNumber: '2021/123456/07',
      logoUrl: null,
      plan: 'premium',
      settings: { autoApproveDrivers: false, requireDriverApproval: true },
      isActive: true,
      createdAt: TS(daysAgo(60)),
    },
  });

  // Users (Firestore docs)
  writes.push({ ref: db.collection('users').doc(adminUid), data: userDoc({ email: 'admin@podsafe.com', fullName: 'Admin User', role: 'admin', uid: adminUid }) });
  writes.push({ ref: db.collection('users').doc(driver1), data: userDoc({ email: 'driver@podsafe.com', fullName: 'Driver User', role: 'driver', uid: driver1 }) });
  writes.push({ ref: db.collection('users').doc(driver2), data: userDoc({ email: 'driver2@podsafe.com', fullName: 'Sam Adams', role: 'driver', uid: driver2 }) });

  // Vehicles
  for (const v of VEHICLES) {
    writes.push({
      ref: db.collection('companies').doc(COMPANY_ID).collection('vehicles').doc(v.id),
      data: { seeded: true, companyId: COMPANY_ID, registration: v.registration, make: v.make, model: v.model, color: v.color, licensePlate: v.registration, status: v.status, totalDeliveries: v.totalDeliveries, createdAt: TS(daysAgo(50)), lastUsedAt: TS(daysAgo(1)), notes: null, documents: null },
    });
  }

  // Customers
  for (const cu of CUSTOMERS) {
    writes.push({
      ref: db.collection('customers').doc(cu.id),
      data: { seeded: true, companyId: COMPANY_ID, customerNumber: cu.customerNumber, name: cu.name, address: cu.address, contactPerson: cu.contactPerson, phone: cu.phone, email: cu.email, deliveryInstructions: null, accountNumber: cu.customerNumber, customerType: cu.customerType, stats: { totalDeliveries: 0, lastDelivery: null, firstDelivery: null }, isActive: true, isFavorite: !!cu.isFavorite, tags: [], createdAt: TS(daysAgo(45)), updatedAt: TS(daysAgo(2)) },
    });
  }

  // Catalog items
  for (const it of CATALOG) {
    writes.push({
      ref: db.collection('companies').doc(COMPANY_ID).collection('itemCatalog').doc(it.id),
      data: { seeded: true, companyId: COMPANY_ID, description: it.description, sku: it.sku, unit: it.unit, defaultQuantity: 1, unitPrice: it.unitPrice, category: it.category, categoryId: null, isActive: true, usageCount: it.usageCount, lastUsed: TS(daysAgo(3)), createdAt: TS(daysAgo(40)), createdBy: adminUid, updatedAt: TS(daysAgo(3)), updatedBy: adminUid },
    });
  }

  // Deliveries
  const deliveries = buildDeliveries(driver1, driver2);
  for (const d of deliveries) writes.push({ ref: db.collection('deliveries').doc(d.id), data: d.data });

  // PODs for delivered deliveries
  const pods = deliveries.filter((d) => d._ctx.status === 'delivered').map((d) => buildPod(d, 'Driver User'));
  for (const p of pods) writes.push({ ref: db.collection('pods').doc(p.id), data: p.data });

  // Claims
  const claims = buildClaims(deliveries, driver1, 'Driver User', adminUid);
  for (const cl of claims) writes.push({ ref: db.collection('companies').doc(COMPANY_ID).collection('claims').doc(cl.id), data: cl.data });

  await commitAll(writes);

  console.log('\nFirestore writes:');
  console.log(`  · 1 company, 3 users`);
  console.log(`  · ${VEHICLES.length} vehicles, ${CUSTOMERS.length} customers, ${CATALOG.length} catalog items`);
  console.log(`  · ${deliveries.length} deliveries (${pods.length} delivered w/ POD), ${claims.length} claims`);
  console.log('\nLogins (password for all = ' + DEMO_PASSWORD + '):');
  console.log('  admin@podsafe.com    (admin  — desktop web)');
  console.log('  driver@podsafe.com   (driver — mobile)');
  console.log('  driver2@podsafe.com  (driver — second route)');
  console.log('\nDone.');
}

main().then(() => process.exit(0)).catch((e) => { console.error('\nSEED FAILED:', e); process.exit(1); });
