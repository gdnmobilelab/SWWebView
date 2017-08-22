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
graftedFetch.__bodyGrafted = true;
if (originalFetch.__bodyGrafted !== true) {
    window.fetch = graftedFetch;
    var originalSend_1 = XMLHttpRequest.prototype.send;
    var originalOpen_1 = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
        var resolvedURL = new URL(url, window.location.href);
        if (resolvedURL.protocol === swwebviewSettings.SW_PROTOCOL + ":") {
            this._graftBody = true;
        }
        originalOpen_1.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function (data) {
        if (data && this._graftBody === true) {
            this.setRequestHeader(swwebviewSettings.GRAFTED_REQUEST_HEADER, data);
        }
        originalSend_1.apply(this, arguments);
    };
}

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

var StreamingXHR = (function (_super) {
    __extends(StreamingXHR, _super);
    function StreamingXHR(url) {
        var _this = _super.call(this) || this;
        _this.seenBytes = 0;
        _this.isOpen = false;
        _this.url = url;
        return _this;
    }
    StreamingXHR.prototype.open = function () {
        if (this.isOpen === true) {
            throw new Error("Already open");
        }
        this.isOpen = true;
        this.xhr = new XMLHttpRequest();
        this.xhr.open(swwebviewSettings.API_REQUEST_METHOD, this.url);
        this.xhr.onreadystatechange = this.receiveData.bind(this);
        this.xhr.send();
    };
    StreamingXHR.prototype.addEventListener = function (type, func) {
        _super.prototype.addEventListener.call(this, type, func);
    };
    StreamingXHR.prototype.receiveData = function () {
        // try {
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
        // console.info("EVENT:", event, evt.data);
        this.dispatchEvent(evt);
        // } catch (err) {
        //     console.error(err);
        //     let errEvt = new ErrorEvent("error", {
        //         error: err
        //     });
        //     this.dispatchEvent(errEvt);
        // }
    };
    StreamingXHR.prototype.close = function () {
        this.xhr.abort();
    };
    return StreamingXHR;
}(index));

function getFullAPIURL(path) {
    return new URL(path, swwebviewSettings.SW_PROTOCOL + "://" + swwebviewSettings.SW_API_HOST).href;
}

var absoluteURL = getFullAPIURL("/events");
var eventsURL = new URL(absoluteURL);
eventsURL.searchParams.append("path", window.location.pathname);
var eventStream = new StreamingXHR(eventsURL.href);

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
    return fetch(getFullAPIURL(path), {
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

var existingWorkers = [];
var ServiceWorkerImplementation = (function (_super) {
    __extends(ServiceWorkerImplementation, _super);
    function ServiceWorkerImplementation(opts) {
        var _this = _super.call(this) || this;
        _this.scriptURL = opts.scriptURL;
        _this.id = opts.id;
        _this.state = opts.installState;
        return _this;
    }
    ServiceWorkerImplementation.prototype.postMessage = function () { };
    ServiceWorkerImplementation.getOrCreate = function (opts) {
        var existing = existingWorkers.find(function (w) { return w.id === opts.id; });
        if (existing) {
            return existing;
        }
        else {
            var newWorker = new ServiceWorkerImplementation(opts);
            existingWorkers.push(newWorker);
            return newWorker;
        }
    };
    return ServiceWorkerImplementation;
}(index));
eventStream.addEventListener("workerinstallerror", function (e) {
    console.error(e.data);
});

var existingRegistrations = [];
var ServiceWorkerRegistrationImplementation = (function (_super) {
    __extends(ServiceWorkerRegistrationImplementation, _super);
    function ServiceWorkerRegistrationImplementation(opts) {
        var _this = _super.call(this) || this;
        _this.scope = opts.scope;
        _this.id = opts.id;
        _this.updateFromResponse(opts);
        return _this;
    }
    ServiceWorkerRegistrationImplementation.getOrCreate = function (opts) {
        var registration = existingRegistrations.find(function (reg) { return reg.id == opts.id; });
        if (!registration) {
            if (opts.unregistered === true) {
                throw new Error("Trying to create an unregistered registration");
            }
            console.info("Creating new registration:", opts.id, opts);
            registration = new ServiceWorkerRegistrationImplementation(opts);
            existingRegistrations.push(registration);
        }
        return registration;
    };
    ServiceWorkerRegistrationImplementation.prototype.updateFromResponse = function (opts) {
        if (opts.unregistered === true) {
            console.info("Removing inactive registration:", opts.id);
            // Remove from our array of existing registrations, as we don't
            // want to refer to this again.
            var idx = existingRegistrations.indexOf(this);
            existingRegistrations.splice(idx, 1);
            return;
        }
        this.active = opts.active
            ? ServiceWorkerImplementation.getOrCreate(opts.active)
            : null;
        this.installing = opts.installing
            ? ServiceWorkerImplementation.getOrCreate(opts.installing)
            : null;
        this.waiting = opts.waiting
            ? ServiceWorkerImplementation.getOrCreate(opts.waiting)
            : null;
    };
    ServiceWorkerRegistrationImplementation.prototype.getNotifications = function () {
        throw new Error("not yet");
    };
    ServiceWorkerRegistrationImplementation.prototype.showNotification = function (title, options) {
        throw new Error("not yet");
    };
    ServiceWorkerRegistrationImplementation.prototype.unregister = function () {
        return apiRequest("/ServiceWorkerRegistration/unregister", {
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
eventStream.addEventListener("serviceworkerregistration", function (e) {
    console.log(e);
    var reg = existingRegistrations.find(function (r) { return r.id == e.data.id; });
    if (reg) {
        reg.updateFromResponse(e.data);
    }
    else {
        console.info("Received update for non-existent registration", e.data.id);
    }
});

var ServiceWorkerContainerImplementation = (function (_super) {
    __extends(ServiceWorkerContainerImplementation, _super);
    function ServiceWorkerContainerImplementation() {
        var _this = this;
        console.info("Created new ServiceWorkerContainer for", window.location.pathname);
        _this = _super.call(this) || this;
        _this.location = window.location;
        _this.controller = null;
        var readyFulfill;
        _this.ready = new Promise(function (fulfill, reject) {
            readyFulfill = fulfill;
        });
        _this.addEventListener("controllerchange", function (e) {
            if (_this.oncontrollerchange) {
                _this.oncontrollerchange(e);
            }
        });
        eventStream.addEventListener("serviceworkercontainer", function (e) {
            console.info("container change", e.data);
            var reg = e.data.readyRegistration
                ? ServiceWorkerRegistrationImplementation.getOrCreate(e.data.readyRegistration)
                : undefined;
            console.log("container response", e.data, reg);
            if (reg && readyFulfill) {
                console.log("fulfill existing pending");
                readyFulfill(reg);
                readyFulfill = undefined;
            }
            else if (reg) {
                console.log("set new resolved promise");
                _this.ready = Promise.resolve(reg);
            }
            else if (!readyFulfill) {
                console.log("set empty promise");
                _this.ready = new Promise(function (fulfill, reject) {
                    readyFulfill = fulfill;
                });
            }
            var newControllerInstance;
            if (e.data.controller) {
                newControllerInstance = ServiceWorkerImplementation.getOrCreate(e.data.controller);
            }
            else {
                newControllerInstance = null;
            }
            if (newControllerInstance !== _this.controller) {
                console.info("Set new controller from", _this.controller, "to", newControllerInstance);
                // Have to do 'as any' because TypeScript definition doesn't
                // allow null service workers
                _this.controller = newControllerInstance;
                var evt = new CustomEvent("controllerchange");
                _this.dispatchEvent(evt);
            }
        });
        eventStream.open();
        return _this;
    }
    ServiceWorkerContainerImplementation.prototype.controllerChangeMessage = function (evt) {
        console.log(evt);
    };
    ServiceWorkerContainerImplementation.prototype.getRegistration = function (scope) {
        return apiRequest("/ServiceWorkerContainer/getregistration", {
            path: window.location.pathname,
            scope: scope
        }).then(function (response) {
            if (response === null) {
                return undefined;
            }
            return ServiceWorkerRegistrationImplementation.getOrCreate(response);
        });
    };
    ServiceWorkerContainerImplementation.prototype.getRegistrations = function () {
        return apiRequest("/ServiceWorkerContainer/getregistrations", {
            path: window.location.pathname
        }).then(function (response) {
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
        console.info("Registering new worker at:", url);
        return apiRequest("/ServiceWorkerContainer/register", {
            path: window.location.pathname,
            url: url,
            scope: opts ? opts.scope : undefined
        }).then(function (response) {
            return ServiceWorkerRegistrationImplementation.getOrCreate(response);
        });
    };
    // used for detection
    ServiceWorkerContainerImplementation.__isSWWebViewImplementation = true;
    return ServiceWorkerContainerImplementation;
}(index));
if ("ServiceWorkerContainer" in self === false) {
    // We lazily initialize this when the client code requests it.
    var container_1 = undefined;
    Object.defineProperty(navigator, "serviceWorker", {
        configurable: true,
        get: function () {
            if (container_1) {
                return container_1;
            }
            return (container_1 = new ServiceWorkerContainerImplementation());
        }
    });
}

}(swwebviewSettings));
//# sourceMappingURL=runtime.js.map
