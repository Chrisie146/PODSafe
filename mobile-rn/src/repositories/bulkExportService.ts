import functions, { FirebaseFunctionsTypes } from '@react-native-firebase/functions';

/**
 * RN-side wrappers for the bulk-export Cloud Functions
 * (functions/src/pdf/generateBulkClaimsPdf.ts + generateBulkPodZip.ts), which replace
 * lib/services/bulk_claims_pdf_service.dart + bulk_pod_download_service.dart's
 * client-side PDF+zip generation. Both callables do all fetching/rendering/zipping/
 * uploading server-side and return a ready-to-open Storage download URL, so these
 * wrappers are thin passthroughs.
 *
 * Not yet deployed (tracked in the vault's Backend Gap Fix Tracker) — calls will fail
 * with `not-found` / `unauthenticated` until the callables are deployed and the
 * per-function invoker grant is applied. The RN call sites are written against the
 * final contract so they work once-deployed with no further changes.
 */

export interface BulkExportResult {
  success: boolean;
  downloadUrl: string;
  included: number;
  skipped?: number;
  mode?: string;
}

export class BulkExportService {
  constructor(private functionsInstance: FirebaseFunctionsTypes.Module = functions()) {}

  /**
   * Generate a ZIP of one PDF report per claim. `claimIds` should be the selected
   * claims (or all filtered claims if none selected). Returns the ZIP download URL.
   */
  async exportClaimsAsPdfZip(claimIds: string[]): Promise<BulkExportResult> {
    if (claimIds.length === 0) {
      throw new Error('No claims selected for export.');
    }
    const callable = this.functionsInstance.httpsCallable('generateBulkClaimsPdf');
    const response = await callable({ claimIds });
    return response.data as BulkExportResult;
  }

  /**
   * Generate a ZIP of PODs. `mode: 'pdf'` (default) = one report PDF per POD;
   * `mode: 'images'` = raw photos/signature/stamp per POD. Returns the ZIP download URL.
   */
  async exportPodsAsZip(podIds: string[], mode: 'pdf' | 'images' = 'pdf'): Promise<BulkExportResult> {
    if (podIds.length === 0) {
      throw new Error('No PODs selected for export.');
    }
    const callable = this.functionsInstance.httpsCallable('generateBulkPodZip');
    const response = await callable({ podIds, mode });
    return response.data as BulkExportResult;
  }
}

export const bulkExportService = new BulkExportService();