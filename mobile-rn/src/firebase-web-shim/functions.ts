import {
  getFunctions,
  httpsCallable as fbHttpsCallable,
  connectFunctionsEmulator,
  type Functions,
} from 'firebase/functions';
import { getWebFirebaseApp } from '../config/firebase.web';

type Callable = (data?: unknown) => Promise<{ data: unknown }>;

export interface FunctionsModule {
  httpsCallable(name: string): Callable;
  useEmulator(host: string, port: number): void;
}

function makeModule(instance: Functions): FunctionsModule {
  return {
    httpsCallable: (name) => {
      const fn = fbHttpsCallable(instance, name);
      return (data?: unknown) => fn(data) as Promise<{ data: unknown }>;
    },
    useEmulator: (host, port) => connectFunctionsEmulator(instance, host, port),
  };
}

export default function functions(): FunctionsModule {
  return makeModule(getFunctions(getWebFirebaseApp()));
}

export namespace FirebaseFunctionsTypes {
  export type Module = FunctionsModule;
}
