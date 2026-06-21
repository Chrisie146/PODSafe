import { PushPodRequest, PushPodResponse } from '../../types';
export declare function pushPod(request: PushPodRequest): Promise<PushPodResponse>;
export declare function validatePushPodRequest(request: any): request is PushPodRequest;
export declare function uploadPodAttachment(companyId: string, sourceId: string, file: {
    fileName: string;
    fileType: string;
    content: string;
}): Promise<void>;
//# sourceMappingURL=push.d.ts.map