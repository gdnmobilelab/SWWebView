declare module "swwebview-settings" {
    interface SWWebViewSettings {
        API_REQUEST_METHOD: string;
        SW_PROTOCOL: string;
        GRAFTED_REQUEST_HEADER: string;
        SW_API_HOST: string;
    }

    var settings: SWWebViewSettings;
    export = settings;
}
