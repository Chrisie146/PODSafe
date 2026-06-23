export class WebUnsupportedError extends Error {
  constructor(method: string) {
    super(`${method} is not supported on the web (react-native-web) target.`);
    this.name = 'WebUnsupportedError';
  }
}

export class NotImplementedError extends Error {
  constructor(method: string) {
    super(`${method} is not implemented in the firebase-web-shim. Add it to the shim if a web screen needs it.`);
    this.name = 'NotImplementedError';
  }
}
