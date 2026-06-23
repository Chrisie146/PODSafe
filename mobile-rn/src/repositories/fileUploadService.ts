import storage from '@react-native-firebase/storage';
import { launchImageLibrary } from 'react-native-image-picker';

/**
 * Ported from lib/services/file_upload_service.dart (verified against source on
 * 2026-06-23) — only used by admin_settings_screen.dart for company/app logo uploads.
 * `deleteFile`/`getDownloadUrl`/`getFileMetadata` are dead code in the Dart source (no
 * call sites anywhere in lib/) and are not ported. Pure functions instead of a static
 * class, same convention as csvExportService.ts/bulkImportService.ts.
 */

/** Mirrors FileUploadService.pickImage(). */
export async function pickLogoImage(): Promise<string | undefined> {
  const response = await launchImageLibrary({ mediaType: 'photo', maxWidth: 1024, maxHeight: 1024, quality: 0.8 });
  if (response.didCancel) return undefined;
  return response.assets?.[0]?.uri;
}

async function uploadImage(storagePath: string, fileUri: string, customMetadata: Record<string, string>): Promise<string | undefined> {
  try {
    const ref = storage().ref(storagePath);
    await ref.putFile(fileUri, { contentType: 'image/jpeg', customMetadata });
    return await ref.getDownloadURL();
  } catch {
    return undefined;
  }
}

/** Mirrors FileUploadService.uploadCompanyLogo(). */
export async function uploadCompanyLogo(companyId: string, fileUri: string): Promise<string | undefined> {
  const fileName = `logo_${Date.now()}.jpg`;
  return uploadImage(`companies/${companyId}/branding/${fileName}`, fileUri, { uploadedBy: companyId });
}

/** Mirrors FileUploadService.uploadAppLogo(). */
export async function uploadAppLogo(companyId: string, fileUri: string): Promise<string | undefined> {
  const fileName = `app_logo_${Date.now()}.jpg`;
  return uploadImage(`companies/${companyId}/branding/${fileName}`, fileUri, { type: 'appLogo', uploadedBy: companyId });
}
