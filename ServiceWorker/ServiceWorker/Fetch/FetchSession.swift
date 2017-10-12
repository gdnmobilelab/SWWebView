import Foundation
import PromiseKit
import JavaScriptCore

/// An attempt at wrapping URLSession and it's various delegates into something that will allow us to fetch
/// a URL, grab headers and then a stream of the body being sent.
@objc public class FetchSession: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionStreamDelegate {

    /// This is what we use for almost all our fetch operations. But we could make individual sessions for
    /// each worker that tie to their threads. Not sure if that's necessary, haven't done it yet.
    public static let `default` = FetchSession(qos: DispatchQoS.utility)

    /// Everything we're doing here wraps around an original URLSession instance.
    fileprivate var session: URLSession!

    /// We keep all our fetch operations off the main thread by using this dispatch queue wherever possible.
    fileprivate let dispatchQueue: DispatchQueue

    /// Used in the fetch call below. Kind of messy - we lose the reference to a fetch task while it is waiting on headers
    /// which means nothing ever gets resolved. We temporarily put the tasks in this set to keep a reference to them
    /// while that happens.
    fileprivate var runningTasks = Set<FetchTask>()

    init(qos: DispatchQoS) {
        self.dispatchQueue = DispatchQueue(label: "FetchSession", qos: qos, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        super.init()
        self.dispatchQueue.sync {
            // ensure the operation queue is the right one. I think?
            self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        }
    }

    init(dispatchQueue: DispatchQueue) {
        self.dispatchQueue = dispatchQueue
        super.init()
        self.dispatchQueue.sync {
            // ensure the operation queue is the right one. I think?
            self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        }
    }

    /// A convenience function to quickly grab a URL. Doesn't deal with origin as it's intended to
    /// be used within internal APIs, not in worker environments.
    public func fetch(_ url: URL) -> Promise<FetchResponseProtocol> {
        let request = FetchRequest(url: url)
        return self.fetch(request)
    }

    /// The main function - actually runs a fetch task, returning a FetchResponseProxy to then chain
    /// on whatever piping/data transformation is needed.
    public func fetch(_ request: FetchRequest, fromOrigin: URL? = nil) -> Promise<FetchResponseProtocol> {
        return Promise(value: ())
            .then(on: self.dispatchQueue, execute: {
                self.performCORSCheck(for: request, inOrigin: fromOrigin)
            })

            .then(on: self.dispatchQueue, execute: { corsRestrictions -> Promise<FetchResponseProtocol> in

                var requestToUse = request

                if corsRestrictions.isCrossDomain {

                    // CORS requests are subject to allowed header restrictions - if the preflight response
                    // has limited the headers we can use, we need to clone our original response then
                    // overwrite which headers we're actually sending.

                    requestToUse = request.clone()
                    requestToUse.headers = requestToUse.headers.filteredBy(allowedKeys: corsRestrictions.allowedHeaders)
                }

                let nsRequest = requestToUse.toURLRequest()
                let task = self.session.dataTask(with: nsRequest)

                // We use the task wrapper to track which responses are attached to the task.
                // Most of the time there is a 1:1 relationship, but if we use response.clone()
                // then more than one will be attached.
                let fetchTask = FetchTask(for: task, with: request, on: self.dispatchQueue)

                // This could do with being revisited, but the reference to the fetchTask is lost
                // while the promise is evaluating (because there is no FetchResponse for it yet)
                // which we don't want. So we temporarily keep a strong reference

                self.runningTasks.insert(fetchTask)

                // .resume() is the call that actually starts the fetch task
                task.resume()

                return fetchTask.hasResponse
                    .then(on: self.dispatchQueue, execute: { response -> FetchResponseProtocol in

                        // Depending on the nature of the request, mode, cross-domain, etc., we
                        // want to return the correct response type.

                        if request.mode == .NoCORS && corsRestrictions.isCrossDomain == true {
                            return FetchResponseProxy(from: response, type: .Opaque)
                        } else if request.mode == .CORS && corsRestrictions.isCrossDomain == true {
                            return FetchResponseProxy(from: response, type: .CORS)
                        } else {
                            return FetchResponseProxy(from: response, type: .Basic)
                        }
                    })
                    .always(on: self.dispatchQueue, execute: { () -> Void in

                        // Now that we have a reference to the response below (which itself contains
                        // the task) we can remove the fetch task from our set.

                        self.runningTasks.remove(fetchTask)

                    })
            })
    }

    /// If we have a fetch operation that has an origin (as all worker-based ones do) we need to run a CORS
    /// OPTIONS request before running the actual HTTP Request itself for all requests sent to different origins.
    /// There's probably some work to be done on caching these calls, but in theory URLSession does that itself.
    fileprivate func performCORSCheck(for request: FetchRequest, inOrigin: URL?) -> Promise<FetchCORSRestrictions> {

        guard let origin = inOrigin else {
            // No origin - no CORS check to perform
            return Promise(value: FetchCORSRestrictions(isCrossDomain: false, allowedHeaders: []))
        }

        guard let host = origin.host, let scheme = origin.scheme else {
            return Promise(error: ErrorMessage("Origin must have a host and a scheme"))
        }

        let isCrossOrigin = host != request.url.host

        if request.mode != .CORS || isCrossOrigin == false {
            // This is not a CORS request, so we can skip all this.
            return Promise(value: FetchCORSRestrictions(isCrossDomain: isCrossOrigin, allowedHeaders: []))
        }

        let optionsRequest = FetchRequest(url: request.url)
        optionsRequest.method = "OPTIONS"

        // CORS requests have header filtering as an option. We need to send an Access-Control-Request-Headers
        // header with our OPTIONS request, and it will send back Access-Control-Allowed-Headers telling us
        // which headers we are actually allowed to send.

        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Request-Headers

        optionsRequest.headers.set("Access-Control-Request-Headers", request.headers.keys().joined(separator: ","))

        // We also need to indicate what method we intend to use:
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Request-Method

        optionsRequest.headers.set("Access-Control-Request-Method", request.method)

        return self.fetch(optionsRequest)
            .then(on: self.dispatchQueue, execute: { res -> FetchCORSRestrictions in

                // The OPTIONS response is required to specify which origins are allowed. A wildcard
                // response is valid: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Origin

                guard let allowedOrigin = res.headers.get("Access-Control-Allow-Origin") else {
                    throw ErrorMessage("OPTIONS request did not return a Access-Control-Allow-Origin header")
                }

                if allowedOrigin != "*" && allowedOrigin != scheme + "://" + host {
                    throw ErrorMessage("Access-Control-Allow-Origin does not match worker origin")
                }

                // It is also required to return a comma-separated list of methods allowed.
                // https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Methods

                guard let allowedMethods = res.headers.get("Access-Control-Allow-Methods") else {
                    throw ErrorMessage("CORS Preflight request did not return Access-Control-Allowed-Methods")
                }

                let allowedMethodsSplit = allowedMethods
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

                if allowedMethodsSplit.contains(request.method) == false {
                    throw ErrorMessage("Method not supported in CORS")
                }

                var allowedHeaders: [String] = []

                // Allow headers is optional (I think?) but specifies what request headers we are allowed
                // to send as part of our CORS request. This is then used to tailor our request, if applicable.

                if let allowedHeadersHeader = res.headers.get("Access-Control-Allow-Headers") {
                    allowedHeaders = allowedHeadersHeader
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                }

                return FetchCORSRestrictions(isCrossDomain: isCrossOrigin, allowedHeaders: allowedHeaders)
            })
    }

    /// This delegate method is called whenever a task encounters a redirect. Based on whatever our request's redirect
    /// attribute says, we'll either follow that redirect, ignore it and download the original request, or throw an error.
    public func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        guard let taskWrapper = self.runningTasks.first(where: { $0.dataTask == task }) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return completionHandler(nil)
        }

        if taskWrapper.shouldFollowRedirect() {
            completionHandler(newRequest)
        } else {
            completionHandler(nil)
        }
    }

    /// This is one of the first delegate methods called, and happens when our initial response has been received,
    /// complete with status, headers, etc. This is the point at which we first create our FetchResponse. Then
    /// we tell URLSession to turn the remainder into a stream.
    public func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        guard let httpResponse = response as? HTTPURLResponse else {
            Log.error?("URLResponse was not an HTTPURLResponse")
            return completionHandler(.cancel)
        }

        guard let taskWrapper = self.runningTasks.first(where: { $0.dataTask == dataTask }) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return completionHandler(.cancel)
        }

        taskWrapper.initialResponse = httpResponse
        completionHandler(.becomeStream)
    }

    /// After we call completionHandler(.becomeStream), *this* delegate method is called. Here, we tell URLSession
    /// to convert our SessionStreamTask to an actual pair of Input and Output streams.
    public func urlSession(_: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {

        guard let taskWrapper = self.runningTasks.first(where: { $0.dataTask == dataTask }) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return dataTask.cancel()
        }

        // We don't want to interact with the stream directly, we just want to turn it into an
        // InputStream.
        taskWrapper.streamTask = streamTask
        streamTask.captureStreams()
    }

    /// Now that we actually have our streams, we can send them to our FetchTask. This is where the URLSession's involvement
    /// in the download stops, essentially. We're not currently using the OutputStream, but in the future we could, in order
    /// to allow us to upload streams.
    public func urlSession(_: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream _: OutputStream) {

        guard let taskWrapper = self.runningTasks.first(where: { $0.streamTask == streamTask }) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return
        }

        do {
            try taskWrapper.receiveStream(stream: inputStream)
        } catch {
            Log.error?("Failed to set URL task up with stream")
            streamTask.cancel()
        }
    }

    // These next two functions should never be called, but I'd be lying if I said I understood every facet of this
    // URLSession process. So we're logging any errors that may come through.

    public func urlSession(_: URLSession, didBecomeInvalidWithError error: Error?) {
        Log.error?("FetchSession experienced an error in a place we weren't expecting it: \(String(describing: error))")
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        Log.error?("FetchSession experienced an error in a place we weren't expecting it:  \(String(describing: error))")
    }
}
