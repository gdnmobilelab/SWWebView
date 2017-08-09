(function (swwebviewSettings) {
'use strict';

/*! *****************************************************************************
Copyright (c) Microsoft Corporation. All rights reserved.
Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at http://www.apache.org/licenses/LICENSE-2.0

THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
MERCHANTABLITY OR NON-INFRINGEMENT.

See the Apache Version 2.0 License for specific language governing permissions
and limitations under the License.
***************************************************************************** */
/* global Reflect, Promise */

var extendStatics = Object.setPrototypeOf ||
    ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
    function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };

function __extends(d, b) {
    extendStatics(d, b);
    function __() { this.constructor = d; }
    d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
}

function createCommonjsModule(fn, module) {
	return module = { exports: {} }, fn(module, module.exports), module.exports;
}

var EventTarget_1 = createCommonjsModule(function (module) {
/**
 * @author mrdoob / http://mrdoob.com
 * @author Jesús Leganés Combarro "Piranna" <piranna@gmail.com>
 */


function EventTarget()
{
  var listeners = {};

  this.addEventListener = function(type, listener)
  {
    if(!listener) return

    var listeners_type = listeners[type];
    if(listeners_type === undefined)
      listeners[type] = listeners_type = [];

    for(var i=0,l; l=listeners_type[i]; i++)
      if(l === listener) return;

    listeners_type.push(listener);
  };

  this.dispatchEvent = function(event)
  {
    if(event._dispatched) throw 'InvalidStateError'
    event._dispatched = true;

    var type = event.type;
    if(type == undefined || type == '') throw 'UNSPECIFIED_EVENT_TYPE_ERR'

    var listenerArray = (listeners[type] || []);

    var dummyListener = this['on' + type];
    if(typeof dummyListener == 'function')
      listenerArray = listenerArray.concat(dummyListener);

    var stopImmediatePropagation = false;

    // [ToDo] Use read-only properties instead of attributes when availables
    event.cancelable = true;
    event.defaultPrevented = false;
    event.isTrusted = false;
    event.preventDefault = function()
    {
      if(this.cancelable)
        this.defaultPrevented = true;
    };
    event.stopImmediatePropagation = function()
    {
      stopImmediatePropagation = true;
    };
    event.target = this;
    event.timeStamp = new Date().getTime();

    for(var i=0,listener; listener=listenerArray[i]; i++)
    {
      if(stopImmediatePropagation) break

      listener.call(this, event);
    }

    return !event.defaultPrevented
  };

  this.removeEventListener = function(type, listener)
  {
    if(!listener) return

    var listeners_type = listeners[type];
    if(listeners_type === undefined) return

    for(var i=0,l; l=listeners_type[i]; i++)
      if(l === listener)
      {
        listeners_type.splice(i, 1);
        break;
      }

    if(!listeners_type.length)
      delete listeners[type];
  };
}


if('object' !== 'undefined' && module.exports)
  module.exports = EventTarget;
});

var StreamingXHR = (function (_super) {
    __extends(StreamingXHR, _super);
    function StreamingXHR(url) {
        var _this = _super.call(this) || this;
        _this.seenBytes = 0;
        _this.xhr = new XMLHttpRequest();
        _this.xhr.open(swwebviewSettings.API_REQUEST_METHOD, url);
        _this.xhr.onreadystatechange = _this.receiveData;
        _this.xhr.send();
        return _this;
    }
    StreamingXHR.prototype.receiveData = function () {
        if (this.xhr.readyState !== 3) {
            return;
        }
        var newData = this.xhr.response.substr(this.seenBytes);
        var _a = /(\w+):(.*)/.exec(newData), _ = _a[0], event = _a[1], data = _a[2];
        var evt = new MessageEvent(event, JSON.parse(data));
        this.dispatchEvent(evt);
    };
    return StreamingXHR;
}(EventTarget_1));

var ServiceWorkerContainerImplementation = (function (_super) {
    __extends(ServiceWorkerContainerImplementation, _super);
    function ServiceWorkerContainerImplementation() {
        var _this = _super.call(this) || this;
        _this.dataFeed = new StreamingXHR("/service");
        _this.dataFeed.addEventListener("controllerchange", _this.controllerChangeMessage);
        return _this;
    }
    ServiceWorkerContainerImplementation.prototype.controllerChangeMessage = function (evt) {
        console.log(evt);
    };
    ServiceWorkerContainerImplementation.prototype.getRegistration = function (scope) {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration>(undefined);
    };
    ServiceWorkerContainerImplementation.prototype.getRegistrations = function () {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration[]>([]);
    };
    ServiceWorkerContainerImplementation.prototype.register = function (url, opts) {
        throw new Error("not yet");
        // return new Promise<ServiceWorkerRegistration>(undefined);
    };
    return ServiceWorkerContainerImplementation;
}(EventTarget_1));
navigator.serviceWorker = new ServiceWorkerContainerImplementation();

}(swwebviewSettings));
