# SWWebView

## What is this?

First and foremost, it's an experiment. So it is in no way ready for production use. It's just a kernel of an idea slowly being fleshed out.

*That said*, it is a collection of modules that, when put together, provide an almost drop-in replacement for WKWebView that supports various Service Worker APIs. It's for apps only, it'll never work inside Safari, and even when it's complete I doubt it will be safe to use as a generic browser app, just with your own code. If you are thinking of using it, or if you think it's an abomination, I'd encourage you to read about [why you might or might not want to use it](https://github.com/gdnmobilelab/SWWebView/wiki/Why-use-SWWebView%3F).

 It's split into three modules, each depending on the previous one:

- **ServiceWorker**

  The core module that actually provides a JavaScript environment in which you can evaluate code and dispatch events. It provides the following APIs inside that environment:
   - [importScripts](https://developer.mozilla.org/en-US/docs/Web/API/WorkerGlobalScope/importScripts)
   - [indexedDB](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/indexedDB) (through [IndexedDBShim](https://github.com/axemclion/IndexedDBShim))
   - [Fetch](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
   - [MessageChannel](https://developer.mozilla.org/en-US/docs/Web/API/MessageChannel) and [MessagePort](https://developer.mozilla.org/en-US/docs/Web/API/MessagePort)
   - [Cache](https://developer.mozilla.org/en-US/docs/Web/API/Cache)
   - [Clients](https://developer.mozilla.org/en-US/docs/Web/API/Clients)

  However, the ServiceWorker module does not persist any data or information at all. So most of those APIs send requests out to delegate methods. Many of those delegate methods are provided by...

- **ServiceWorkerContainer**
 
  This module provides the data persistence and lifecycle methods that make ServiceWorkers usable between sessions. It stores workers, cached files and databases in SQLite format in a location specified by a delegate (it's delegates all the way down). In addition to delegates for ServiceWorker, it provides:
   - [ServiceWorkerContainer](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerContainer)
   - [ServiceWorkerRegistration](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration) (minus notification APIs for now)

- **SWWebView**

  A subclass of WKWebView that injects JavaScript to create a version of the Service Worker API you can access like you would the real thing in Chrome and Firefox. Allows you to register, unregister and postMessage to a worker. Sends fetch events through the worker when it is in control of an SWWebView. As you might imagine, there are [a lot of tradeoffs and caveats](https://github.com/gdnmobilelab/SWWebView/wiki/How-SWWebView-bridges-between-the-webview-and-native) involved in getting it working.

## Requirements
 - XCode 9 (and iOS 11 on devices)
 - Node 6 or above

## Installation

The project uses Carthage for iOS dependencies and NPM for JavaScript dependencies. So make sure you have both installed. Then:

 1. Clone this repo
 2. Go to the repo directory and type `carthage bootstrap` to install the iOS dependencies.
 3. Go to the `SWWebView/js-src` directory and type `npm install` to install the JavaScript dependencies

## Running

Right now the easiest way to take a look at the project running is to open `SWWebView/SWWebView.xcworkspace` and run the `SWWebView-JSTestSuite` target in the simulator, which is a very simple app that will create an SWWebView and point it at `localhost:4567`. In order to run the test suite, go to `SWWebView/js-src` in the terminal and type `npm run test-watch`, which will transpile the JS and start a web server. You can also load `localhost:4567` in Chrome or Firefox to verify that the tests pass in all environments.

## Contributing

If you're interested in the project and want to contribute: you are brilliant. But I'd hold off getting too excited just yet - I still need to go through and add a lot of comments to the `ServiceWorkerContainer` and `SWWebView` modules (I know, I know, I should do it as I go along) so that it's even possible to work out what's going on. Then identify which features are missing and how they might be implemented. *Then* we're good to go.

But for now, take it for a spin! If you see anything that behaves weirdly or if you have any thoughts on the project in general, please do [let me know](https://twitter.com/_alastair).
