import { Linking } from 'react-native';

/**
 * Ported from lib/services/pod_image_download_service.dart (verified against source
 * on 2026-06-23). Scoped to downloadImage/downloadMultipleImages — the only members
 * pod_details_screen.dart's behavior actually depends on. `createDownloadLink()` had
 * zero call sites in the Dart source (confirmed via grep) and is not ported.
 * `generateFilename()` is not ported either: in the Dart source it's only meaningful
 * on the kIsWeb branch (sets the browser download's suggested filename); on the native
 * branch — the one RN's `downloadImage()` actually matches — Dart's own `downloadImage`
 * ignores the filename argument too (it just logs it), so there's nothing for an RN
 * equivalent to do with it.
 *
 * Deviation: the Dart version branches on kIsWeb (direct browser download vs.
 * launchUrl to an external app). RN has no equivalent in-app download; Linking.openURL
 * is used unconditionally, same as the native (non-web) Dart branch — the browser
 * download tab's ?alt=media trick doesn't apply outside Flutter Web.
 */
export async function downloadImage(imageUrl: string): Promise<void> {
  const canOpen = await Linking.canOpenURL(imageUrl);
  if (!canOpen) {
    throw new Error(`Could not open URL: ${imageUrl}`);
  }
  await Linking.openURL(imageUrl);
}

export async function downloadMultipleImages(images: Record<string, string>, podId: string): Promise<void> {
  for (const [name, url] of Object.entries(images)) {
    try {
      await downloadImage(url);
      await new Promise((resolve) => setTimeout(resolve, 500));
    } catch (e) {
      console.warn(`Failed to download ${name} for POD ${podId}`, e);
    }
  }
}
