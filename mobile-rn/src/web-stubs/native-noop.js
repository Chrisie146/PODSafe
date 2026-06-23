'use strict';

/**
 * Web build stub for native-only React Native libraries that have no web
 * implementation. Aliased in for the RNW target so the bundle resolves and the
 * admin/desktop screens can load. Any access returns a no-op React component;
 * any method call returns that component (never executes native code).
 *
 * This is a deliberate M1/M2 placeholder. Real per-screen web fallbacks
 * (maps, pickers, charts, OCR, signature, share) are M3 work — see
 * docs/superpowers/specs/2026-06-23-rnw-web-parity-design.md.
 */
const NoopComponent = function NoopComponent() {
  return null;
};

const handler = {
  get(_target, prop) {
    if (prop === '__esModule') {
      return true;
    }
    if (prop === 'default') {
      return proxy;
    }
    return NoopComponent;
  },
  apply() {
    return null;
  },
};

const proxy = new Proxy(NoopComponent, handler);

module.exports = proxy;
