function makeDocRef() {
  return {
    get: jest.fn(() => Promise.resolve({ exists: () => false, id: 'mock-id', data: () => ({}) })),
    set: jest.fn(() => Promise.resolve()),
    update: jest.fn(() => Promise.resolve()),
    delete: jest.fn(() => Promise.resolve()),
  };
}

function makeCollectionRef() {
  return {
    doc: jest.fn(() => makeDocRef()),
    where: jest.fn(() => makeCollectionRef()),
    orderBy: jest.fn(() => makeCollectionRef()),
    limit: jest.fn(() => makeCollectionRef()),
    get: jest.fn(() => Promise.resolve({ docs: [], size: 0, empty: true })),
  };
}

const mockFirestoreModule = {
  collection: jest.fn(() => makeCollectionRef()),
  collectionGroup: jest.fn(() => makeCollectionRef()),
};

const firestore = jest.fn(() => mockFirestoreModule);
firestore.Timestamp = {
  fromDate: jest.fn((date) => ({ toDate: () => date })),
  now: jest.fn(() => ({ toDate: () => new Date() })),
};
firestore.FieldValue = {
  serverTimestamp: jest.fn(() => 'mock-server-timestamp'),
};

module.exports = firestore;
module.exports.default = firestore;
module.exports.FirebaseFirestoreTypes = {};
