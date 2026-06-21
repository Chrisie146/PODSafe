export declare function getAccessToken(companyId: string): Promise<string>;
export declare function createBcClient(companyId: string): BcHttpClient;
export declare class BcHttpClient {
    private companyId;
    private client;
    constructor(companyId: string);
    private setupRetryInterceptor;
    private isRetryableError;
    private getRetryAfter;
    private enhanceError;
    private delay;
    get<T = any>(endpoint: string, params?: Record<string, any>): Promise<T>;
    post<T = any>(endpoint: string, data?: any): Promise<T>;
    patch<T = any>(endpoint: string, data: any, etag?: string): Promise<T>;
}
//# sourceMappingURL=client.d.ts.map