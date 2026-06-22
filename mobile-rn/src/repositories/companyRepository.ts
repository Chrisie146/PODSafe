import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import functions, { FirebaseFunctionsTypes } from '@react-native-firebase/functions';
import { Company } from '../models/company';
import { companyFromFirestore } from '../models/company.converters';

/**
 * Ported from lib/services/company_service.dart (verified against source on
 * 2026-06-22), following the constructor-injected repository pattern from
 * deliveryRepository.ts/claimRepository.ts.
 */
export class CompanyRepository {
  constructor(
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private authInstance: FirebaseAuthTypes.Module = auth(),
    private functionsInstance: FirebaseFunctionsTypes.Module = functions(),
  ) {}

  /** Mirrors registerCompany(). */
  async registerCompany(params: {
    companyName: string;
    companyEmail: string;
    companyPhone: string;
    companyAddress: string;
    adminName: string;
    adminEmail: string;
    adminPassword: string;
  }): Promise<string> {
    const { companyName, companyEmail, companyPhone, companyAddress, adminName, adminEmail, adminPassword } = params;

    const userCredential = await this.authInstance.createUserWithEmailAndPassword(adminEmail, adminPassword);
    const adminUid = userCredential.user.uid;

    const companyRef = await this.firestoreInstance.collection('companies').add({
      name: companyName,
      email: companyEmail,
      phone: companyPhone,
      address: companyAddress,
      createdAt: firestore.FieldValue.serverTimestamp(),
      plan: 'free',
      isActive: true,
      settings: { autoApproveDrivers: false, requireDriverApproval: true },
    });

    const companyId = companyRef.id;

    await this.firestoreInstance.collection('users').doc(adminUid).set({
      id: adminUid,
      email: adminEmail,
      displayName: adminName,
      role: 'admin',
      companyId,
      isActive: true,
      createdAt: firestore.FieldValue.serverTimestamp(),
      updatedAt: firestore.FieldValue.serverTimestamp(),
      lastLoginAt: firestore.FieldValue.serverTimestamp(),
    });

    await userCredential.user.updateProfile({ displayName: adminName });

    return companyId;
  }

  /** Mirrors getCompany(). */
  async getCompany(companyId: string): Promise<Company | null> {
    const doc = await this.firestoreInstance.collection('companies').doc(companyId).get();
    return doc.exists() ? companyFromFirestore(doc) : null;
  }

  /** Mirrors getCompanyStream(). Returns an unsubscribe function. */
  subscribeToCompany(companyId: string, onChange: (company: Company | null) => void, onError?: (error: Error) => void): () => void {
    return this.firestoreInstance
      .collection('companies')
      .doc(companyId)
      .onSnapshot(
        (doc) => onChange(doc.exists() ? companyFromFirestore(doc) : null),
        (error) => onError?.(error as unknown as Error),
      );
  }

  /** Mirrors updateCompany(). */
  async updateCompany(companyId: string, data: Record<string, unknown>): Promise<void> {
    await this.firestoreInstance
      .collection('companies')
      .doc(companyId)
      .update({ ...data, updatedAt: firestore.FieldValue.serverTimestamp() });
  }

  /** Mirrors verifyCompanyCode(): calls the verifyCompanyCode Cloud Function. */
  async verifyCompanyCode(companyCode: string): Promise<boolean> {
    try {
      const callable = this.functionsInstance.httpsCallable('verifyCompanyCode');
      const result = await callable({ code: companyCode.trim() });
      const data = result.data as { valid?: boolean };
      return data.valid === true;
    } catch {
      return false;
    }
  }

  /** Mirrors getCompanyName(): same Cloud Function call, reads the companyName field. */
  async getCompanyName(companyCode: string): Promise<string | null> {
    try {
      const callable = this.functionsInstance.httpsCallable('verifyCompanyCode');
      const result = await callable({ code: companyCode.trim() });
      const data = result.data as { valid?: boolean; companyName?: string };
      return data.valid === true && data.companyName ? data.companyName : null;
    } catch {
      return null;
    }
  }
}
