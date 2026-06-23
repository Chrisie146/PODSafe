import functions, { FirebaseFunctionsTypes } from '@react-native-firebase/functions';

/**
 * RN-side wrapper for the `generatePodPdf` callable (functions/src/pdf/generatePodPdf.ts),
 * which replaces lib/services/pod_pdf_generator_service.dart's client-side `pdf`-package
 * builder. The callable does all the fetching/rendering/uploading server-side and returns
 * a ready-to-open download URL, so this wrapper is a thin passthrough.
 */
export class PodPdfService {
  constructor(private functionsInstance: FirebaseFunctionsTypes.Module = functions()) {}

  async generatePodPdf(deliveryId: string): Promise<string> {
    const callable = this.functionsInstance.httpsCallable('generatePodPdf');
    const response = await callable({ deliveryId });
    const data = response.data as { success: boolean; pdfUrl: string };
    return data.pdfUrl;
  }
}
