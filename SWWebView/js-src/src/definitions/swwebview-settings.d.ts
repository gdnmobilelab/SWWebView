declare module "swwebview-settings" {
    interface SWWebViewSettings {
        API_REQUEST_METHOD: string;
        SW_PROTOCOL: string;
        GRAFTED_REQUEST_HEADER: string;
        EVENT_STREAM_PATH: string;
    }

    var settings: SWWebViewSettings;
    export = settings;
}
