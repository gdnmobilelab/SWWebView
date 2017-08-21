import { SW_PROTOCOL, GRAFTED_REQUEST_HEADER } from "swwebview-settings";

// We can't read POST bodies in native code, so we're doing the super-gross:
// putting it in a custom header. Hoping we can get rid of this nonsense soon.

const originalFetch = fetch;

function graftedFetch(request: RequestInfo, opts?: RequestInit) {
    if (!opts || !opts.body) {
        // no body, so none of this matters
        return originalFetch(request, opts);
    }

    let url = request instanceof Request ? request.url : request;
    let resolvedURL = new URL(url, window.location.href);

    if (resolvedURL.protocol !== SW_PROTOCOL + ":") {
        // if we're not fetching on the SW protocol, then this
        // doesn't matter.
        return originalFetch(request, opts);
    }

    opts.headers = opts.headers || {};
    opts.headers[GRAFTED_REQUEST_HEADER] = opts.body;

    return originalFetch(request, opts);
}

(graftedFetch as any).__bodyGrafted = true;

if ((originalFetch as any).__bodyGrafted !== true) {
    (window as any).fetch = graftedFetch;

    const originalSend = XMLHttpRequest.prototype.send;
    const originalOpen = XMLHttpRequest.prototype.open;

    XMLHttpRequest.prototype.open = function(method, url) {
        let resolvedURL = new URL(url, window.location.href);
        if (resolvedURL.protocol === SW_PROTOCOL + ":") {
            this._graftBody = true;
        }
        originalOpen.apply(this, arguments);
    };

    XMLHttpRequest.prototype.send = function(data) {
        if (data && this._graftBody === true) {
            this.setRequestHeader(GRAFTED_REQUEST_HEADER, data);
        }
        originalSend.apply(this, arguments);
    };
}
