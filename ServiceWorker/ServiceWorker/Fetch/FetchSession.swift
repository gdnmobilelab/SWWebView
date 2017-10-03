import Foundation
import PromiseKit
import JavaScriptCore

@objc public class FetchSession: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionStreamDelegate {

    public static let `default` = FetchSession()

    fileprivate var session: URLSession!

    fileprivate var runningTasks = Set<FetchTask>()

    override init() {
        super.init()
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }

    public func fetch(_ url: URL) -> Promise<FetchResponseProtocol> {
        let request = FetchRequest(url: url)
        return self.fetch(request)
    }

    public func fetch(_ request: FetchRequest, fromOrigin: URL? = nil) -> Promise<FetchResponseProtocol> {

        return self.performCORSCheck(for: request, inOrigin: fromOrigin)
            .then { corsRestrictions in

                let nsRequest = request.toURLRequest()
                let task = self.session.dataTask(with: nsRequest)

                // We use the task wrapper to track which responsea are attached to the task.
                // Most of the time there is a 1:1 relationship, but if we use response.clone()
                // then more than one will be attached.
                let fetchTask = FetchTask(for: task, with: request)

                self.runningTasks.insert(fetchTask)

                // This could do with being revisited, but the reference to the fetchTask is lost
                // while the promise is evaluating (because there is no FetchResponse for it yet)
                // which we don't want. So we temporarily keep a strong reference

                task.resume()
                return fetchTask.hasResponse
                    .always {
                        // just make sure we don't hold references unnecessarily
                        self.runningTasks.remove(fetchTask)
                    }
                    .then { response -> FetchResponseProtocol in

                        if request.mode == .NoCORS && corsRestrictions.isCrossDomain == true {
                            return try OpaqueResponse(from: response)
                        } else if request.mode == .CORS && corsRestrictions.isCrossDomain == true {
                            return try CORSResponse(from: response, allowedHeaders: corsRestrictions.allowedHeaders)
                        } else {
                            return try BasicResponse(from: response)
                        }
                    }
            }
    }

    internal func fetch(_ requestOrURL: JSValue, fromOrigin origin: URL) -> JSValue? {

        return firstly { () -> Promise<FetchResponseProtocol> in

            var request: FetchRequest

            if let fetchInstance = requestOrURL.toObjectOf(FetchRequest.self) as? FetchRequest {
                request = fetchInstance
            } else if requestOrURL.isString {

                guard let requestString = requestOrURL.toString() else {
                    throw ErrorMessage("Could not convert request to string")
                }

                guard let parsedURL = URL(string: requestString) else {
                    throw ErrorMessage("Could not parse URL string")
                }

                request = FetchRequest(url: parsedURL)
            } else {
                throw ErrorMessage("Did not understand first argument passed in")
            }

            return self.fetch(request, fromOrigin: origin)

        }.toJSPromise(in: requestOrURL.context)
    }

    fileprivate func performCORSCheck(for request: FetchRequest, inOrigin: URL?) -> Promise<FetchCORSRestrictions> {

        guard let origin = inOrigin else {
            // No origin - no CORS check to perform
            return Promise(value: FetchCORSRestrictions(isCrossDomain: false, allowedHeaders: []))
        }

        guard let host = origin.host, let scheme = origin.scheme else {
            return Promise(error: ErrorMessage("Origin must have a host and a scheme"))
        }

        let isCrossOrigin = host != request.url.host

        if request.mode != .CORS || origin.host == request.url.host {
            // This is not a CORS request, so we can skip all this.
            return Promise(value: FetchCORSRestrictions(isCrossDomain: isCrossOrigin, allowedHeaders: []))
        }

        let optionsRequest = FetchRequest(url: request.url)
        optionsRequest.method = "OPTIONS"

        return self.fetch(optionsRequest)
            .then { res -> FetchCORSRestrictions in

                let allowedOrigin = res.headers.get("Access-Control-Allow-Origin")

                if allowedOrigin != "*" && allowedOrigin != scheme + "://" + host {
                    throw ErrorMessage("Access-Control-Allow-Origin does not match or does not exist")
                }

                if let allowedMethods = res.headers.get("Access-Control-Allow-Methods") {
                    let allowedMethodsSplit = allowedMethods
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

                    if allowedMethodsSplit.contains(request.method) == false {
                        throw ErrorMessage("Method not supported in CORS")
                    }
                } else {
                    throw ErrorMessage("CORS Preflight request did not return Access-Control-Allowed-Methods")
                }

                var exposedHeaders: [String] = []

                if let exposedHeadersHeader = res.headers.get("Access-Control-Expose-Headers") {
                    exposedHeaders = exposedHeadersHeader
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                }

                return FetchCORSRestrictions(isCrossDomain: isCrossOrigin, allowedHeaders: exposedHeaders)
            }
    }

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

    public func urlSession(_: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream _: OutputStream) {

        guard let taskWrapper = self.runningTasks.first(where: { $0.streamTask == streamTask }) else {
            Log.error?("Could not find a wrapper for an active fetch task")
            return
        }

        do {
            try taskWrapper.receiveStream(stream: inputStream)
            // Although the task is still running, we base everything on the input stream from here on
            // so we can safely remove this strong reference
            self.runningTasks.remove(taskWrapper)
        } catch {
            Log.error?("Failed to set URL task up with stream")
            streamTask.cancel()
        }
    }

    public func urlSession(_: URLSession, didBecomeInvalidWithError _: Error?) {
        NSLog("invalid error?")
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
        NSLog("complete with error?")
    }
}
