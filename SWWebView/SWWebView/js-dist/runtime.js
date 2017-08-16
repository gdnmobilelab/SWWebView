(function (swwebviewSettings) {
'use strict';

function __extends(d, b) {
    for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p];
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
}

// We can't read POST bodies in native code, so we're doing the super-gross:
// putting it in a custom header. Hoping we can get rid of this nonsense soon.
var originalFetch = fetch;
function graftedFetch(request, opts) {
    if (!opts || !opts.body) {
        // no body, so none of this matters
        return originalFetch(request, opts);
    }
    var url = request instanceof Request ? request.url : request;
    var resolvedURL = new URL(url, window.location.href);
    if (resolvedURL.protocol !== swwebviewSettings.SW_PROTOCOL + ":") {
        // if we're not fetching on the SW protocol, then this
        // doesn't matter.
        return originalFetch(request, opts);
    }
    opts.headers = opts.headers || {};
    opts.headers[swwebviewSettings.GRAFTED_REQUEST_HEADER] = opts.body;
    return originalFetch(request, opts);
}
window.fetch = graftedFetch;
var originalSend = XMLHttpRequest.prototype.send;
var originalOpen = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function (method, url) {
    var resolvedURL = new URL(url, window.location.href);
    if (resolvedURL.protocol === swwebviewSettings.SW_PROTOCOL + ":") {
        this._graftBody = true;
    }
    originalOpen.apply(this, arguments);
};
XMLHttpRequest.prototype.send = function (data) {
    if (data && this._graftBody === true) {
        this.setRequestHeader(swwebviewSettings.GRAFTED_REQUEST_HEADER, data);
    }
    originalSend.apply(this, arguments);
};

function E() {
  // Keep this empty so it's easier to inherit from
  // (via https://github.com/lipsmack from https://github.com/scottcorgan/tiny-emitter/issues/3)
}

E.prototype = {
  on: function(name, callback, ctx) {
    var e = this.e || (this.e = {});

    (e[name] || (e[name] = [])).push({
      fn: callback,
      ctx: ctx
    });

    return this;
  },

  once: function(name, callback, ctx) {
    var self = this;
    function listener() {
      self.off(name, listener);
      callback.apply(ctx, arguments);
    }

    listener._ = callback;
    return this.on(name, listener, ctx);
  },

  emit: function(name) {
    var data = [].slice.call(arguments, 1);
    var evtArr = ((this.e || (this.e = {}))[name] || []).slice();
    var i = 0;
    var len = evtArr.length;

    for (i; i < len; i++) {
      evtArr[i].fn.apply(evtArr[i].ctx, data);
    }

    return this;
  },

  dispatchEvent: function(ev) {
    var name = ev.type;
    this.emit(name, ev);
  },

  off: function(name, callback) {
    var e = this.e || (this.e = {});
    var evts = e[name];
    var liveEvents = [];

    if (evts && callback) {
      for (var i = 0, len = evts.length; i < len; i++) {
        if (evts[i].fn !== callback && evts[i].fn._ !== callback)
          liveEvents.push(evts[i]);
      }
    }

    // Remove event from queue to prevent memory leak
    // Suggested by https://github.com/lazd
    // Ref: https://github.com/scottcorgan/tiny-emitter/commit/c6ebfaa9bc973b33d110a84a307742b7cf94c953#commitcomment-5024910

    liveEvents.length ? (e[name] = liveEvents) : delete e[name];

    return this;
  }
};

E.prototype.addEventListener = E.prototype.on;
E.prototype.removeEventListener = E.prototype.off;

var index = E;

var APIError = (function (_super) {
    __extends(APIError, _super);
    function APIError(message, response) {
        var _this = _super.call(this, message) || this;
        _this.response = response;
        return _this;
    }
    return APIError;
}(Error));
function apiRequest(path, body) {
    if (body === void 0) { body = undefined; }
    return fetch(path, {
        method: swwebviewSettings.API_REQUEST_METHOD,
        body: body === undefined ? undefined : JSON.stringify(body),
        headers: {
            "Content-Type": "application/json"
        }
    }).then(function (res) {
        if (res.ok === false) {
            if (res.status === 500) {
                return res.json().then(function (errorJSON) {
                    throw new Error(errorJSON.error);
                });
            }
            throw new APIError("Received a non-200 response to API request", res);
        }
        return res.json();
    });
}

var StreamingXHR = (function (_super) {
    __extends(StreamingXHR, _super);
    function StreamingXHR(url) {
        var _this = _super.call(this) || this;
        _this.seenBytes = 0;
        _this.xhr = new XMLHttpRequest();
        _this.xhr.open(swwebviewSettings.API_REQUEST_METHOD, url);
        _this.xhr.onreadystatechange = _this.receiveData.bind(_this);
        _this.xhr.send();
        return _this;
    }
    StreamingXHR.prototype.receiveData = function () {
        try {
            if (this.xhr.readyState !== 3) {
                return;
            }
            // This means the responseText keeps growing and growing. Perhaps
            // we should look into cutting this off and re-establishing a new
            // link if it gets too big.
            var newData = this.xhr.responseText.substr(this.seenBytes);
            this.seenBytes = this.xhr.responseText.length;
            var _a = /([\w\-]+):(.*)/.exec(newData), _ = _a[0], event = _a[1], data = _a[2];
            var evt = new MessageEvent(event, {
                data: JSON.parse(data)
            });
            this.dispatchEvent(evt);
        }
        catch (err) {
            var errEvt = new ErrorEvent("error", {
                error: err
            });
            this.dispatchEvent(errEvt);
        }
    };
    StreamingXHR.prototype.close = function () {
        this.xhr.abort();
    };
    return StreamingXHR;
}(index));

var eventStream = new StreamingXHR("/events");
eventStream.addEventListener("serviceworkerregistration", console.info);

var existingWorkers = [];
var ServiceWorkerImplementation = (function (_super) {
    __extends(ServiceWorkerImplementation, _super);
    function ServiceWorkerImplementation(opts) {
        var _this = _super.call(this) || this;
        _this.scriptURL = opts.url;
        _this.state = opts.state;
        _this.id = opts.id;
        return _this;
    }
    ServiceWorkerImplementation.prototype.postMessage = function () { };
    ServiceWorkerImplementation.getOrCreate = function (opts) {
        var worker = existingWorkers.find(function (worker) { return worker.id == opts.id; });
        if (!worker) {
            worker = new ServiceWorkerImplementation(opts);
            existingWorkers.push(worker);
        }
        return worker;
    };
    return ServiceWorkerImplementation;
}(index));

var existingRegistrations = [];
var ServiceWorkerRegistrationImplementation = (function (_super) {
    __extends(ServiceWorkerRegistrationImplementation, _super);
    function ServiceWorkerRegistrationImplementation(opts) {
        var _this = _super.call(this) || this;
        console.log(opts);
        _this.scope = opts.scope;
        _this.id = opts.id;
        _this.active = _this.createWorkerOrSetNull(opts.active);
        _this.installing = _this.createWorkerOrSetNull(opts.installing);
        _this.waiting = _this.createWorkerOrSetNull(opts.waiting);
        return _this;
    }
    ServiceWorkerRegistrationImplementation.prototype.createWorkerOrSetNull = function (workerResponse) {
        if (!workerResponse) {
            return null;
        }
        return ServiceWorkerImplementation.getOrCreate(workerResponse);
    };
    ServiceWorkerRegistrationImplementation.getOrCreate = function (opts) {
        var registration = existingRegistrations.find(function (reg) { return reg.id == opts.id; });
        if (!registration) {
            registration = new ServiceWorkerRegistrationImplementation(opts);
            existingRegistrations.push(registration);
        }
        return registration;
    };
    ServiceWorkerRegistrationImplementation.prototype.getNotifications = function () {
        throw new Error("not yet");
    };
    ServiceWorkerRegistrationImplementation.prototype.showNotification = function (title, options) {
        throw new Error("not yet");
    };
    ServiceWorkerRegistrationImplementation.prototype.unregister = function () {
        return apiRequest("/ServiceWorkerRegistration/unregister", {
            scope: this.scope,
            id: this.id
        }).then(function (response) {
            return response.success;
        });
    };
    ServiceWorkerRegistrationImplementation.prototype.update = function () {
        throw new Error("not yet");
    };
    return ServiceWorkerRegistrationImplementation;
}(index));
eventStream.addEventListener("serviceworkerregistration", console.info);

var ServiceWorkerContainerImplementation = (function (_super) {
    __extends(ServiceWorkerContainerImplementation, _super);
    function ServiceWorkerContainerImplementation() {
        var _this = _super.call(this) || this;
        _this.location = window.location;
        return _this;
    }
    ServiceWorkerContainerImplementation.prototype.controllerChangeMessage = function (evt) {
        console.log(evt);
    };
    ServiceWorkerContainerImplementation.prototype.getRegistration = function (scope) {
        return apiRequest("/ServiceWorkerContainer/getregistration", {
            scope: scope
        }).then(function (response) {
            if (response === null) {
                return undefined;
            }
            return ServiceWorkerRegistrationImplementation.getOrCreate(response);
        });
    };
    ServiceWorkerContainerImplementation.prototype.getRegistrations = function () {
        return apiRequest("/ServiceWorkerContainer/getregistrations").then(function (response) {
            var registrations = [];
            response.forEach(function (r) {
                if (r) {
                    registrations.push(ServiceWorkerRegistrationImplementation.getOrCreate(r));
                }
            });
            return registrations;
        });
    };
    ServiceWorkerContainerImplementation.prototype.register = function (url, opts) {
        return apiRequest("/ServiceWorkerContainer/register", {
            url: url,
            scope: opts ? opts.scope : undefined
        }).then(function (response) {
            return ServiceWorkerRegistrationImplementation.getOrCreate(response);
        });
    };
    return ServiceWorkerContainerImplementation;
}(index));
if ("serviceWorker" in navigator === false) {
    navigator.serviceWorker = new ServiceWorkerContainerImplementation();
}

}(swwebviewSettings));
