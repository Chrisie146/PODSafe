function makeStorageRef() {
  return {
    putFile: jest.fn(() => Promise.resolve()),
    putData: jest.fn(() => Promise.resolve()),
    putString: jest.fn(() => Promise.resolve()),
    getDownloadURL: jest.fn(() => Promise.resolve('https://mock.storage/file')),
    delete: jest.fn(() => Promise.resolve()),
  };
}

const mockStorageModule = {
  ref: jest.fn(() => makeStorageRef()),
};

const storage = jest.fn(() => mockStorageModule);
module.exports = storage;
module.exports.default = storage;
