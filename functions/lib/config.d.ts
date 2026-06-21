export declare const config: {
    readonly bcOAuthAuthority: any;
    readonly bcClientId: any;
    readonly bcClientSecret: any;
    readonly bcRedirectUri: any;
    readonly bcScope: any;
    readonly bcApiBaseUrl: "https://api.businesscentral.dynamics.com/v2.0";
    readonly gcpProjectId: string;
    readonly sessionSecret: string;
    readonly maxRetries: 3;
    readonly retryDelay: 1000;
    readonly backoffMultiplier: 2;
};
export declare function validateConfig(): void;
export declare function getTokenEndpoint(tenantId?: string): string;
export declare function getBcApiUrl(tenantId: string, environment?: 'Production' | 'Sandbox'): string;
//# sourceMappingURL=config.d.ts.map