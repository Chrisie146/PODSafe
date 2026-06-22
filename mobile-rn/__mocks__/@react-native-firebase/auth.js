const mockAuthModule = {
  currentUser: null,
  onAuthStateChanged: jest.fn(() => jest.fn()), // returns an unsubscribe fn
  signInWithEmailAndPassword: jest.fn(),
  createUserWithEmailAndPassword: jest.fn(),
  signOut: jest.fn(),
  sendPasswordResetEmail: jest.fn(),
};

const auth = jest.fn(() => mockAuthModule);

module.exports = auth;
module.exports.default = auth;
module.exports.FirebaseAuthTypes = {};
