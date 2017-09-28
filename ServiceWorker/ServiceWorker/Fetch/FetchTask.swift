import Foundation
import PromiseKit

class FetchTask: NSObject {

    let task: URLSessionDataTask
    let request: FetchRequest

    var responses = Set<FetchResponse>()

    fileprivate let hasResponsePromise = Promise<FetchResponse>.pending()

    fileprivate var completionHandler: ((URLSession.ResponseDisposition) -> Void)?

    var hasResponse: Promise<FetchResponse> {
        return self.hasResponsePromise.promise
    }

    init(for task: URLSessionDataTask, with request: FetchRequest) {
        self.task = task
        self.request = request
        super.init()
    }

    deinit {
        if self.task.state == .running {
            Log.info?("Cancelling running fetch task because nothing is listening to it")
            self.task.cancel()
        }
    }

    fileprivate var redirected = false

    func shouldFollowRedirect() -> Bool {
        self.redirected = true
        if self.request.redirect == .Follow {
            return true
        }

        if self.request.redirect == .Error {
            self.hasResponsePromise.reject(ErrorMessage("Received redirect, FetchRequest redirect set to 'error'"))
        }

        return false
    }

    func beginDownloadIfNotAlreadyStarted() {
        if let handler = self.completionHandler {
            handler(.allow)
            self.completionHandler = nil
        }
    }

    func receive(initialResponse: HTTPURLResponse, withCompletionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) throws {

        guard let url = initialResponse.url else {
            throw ErrorMessage("HTTPURLResponse has no URL")
        }

        self.completionHandler = handler

        let headers = FetchHeaders()

        try initialResponse.allHeaderFields.forEach { key, val in
            guard let keyString = key as? String, let valString = val as? String else {
                throw ErrorMessage("Could not parse HTTPURLResponse headers")
            }

            if keyString.lowercased() == "content-encoding" {
                // URLSession automatically decodes content (which we don't actually want it to do)
                // so the only way to continue to use this is to strip out the Content-Encoding
                // header, otherwise the browser will try to decode it again
                return
            } else if keyString.lowercased() == "content-length" {
                // Because of this same GZIP issue, the content length will be incorrect. It's actually
                // also normally incorrect, but because we're stripping out all encoding we should
                // update the content-length header to be accurate.
                headers.set("Content-Length", String(self.task.countOfBytesExpectedToReceive))
                return
            }

            headers.append(keyString, valString)
        }

        let fetchResponse = FetchResponse(url: url, headers: headers, status: initialResponse.statusCode, redirected: self.redirected)

        // Establish a strong reference between the response and task
        fetchResponse.fetchTask = self

        // Abstracting this out because custom responses still need a way to use
        // this without depending on FetchTask
        fetchResponse.startStream = { [weak self] in
            self?.beginDownloadIfNotAlreadyStarted()
        }
        self.add(response: fetchResponse)
        self.hasResponsePromise.fulfill(fetchResponse)
    }

    func receive(data: Data) {
        self.responses.forEach { $0.receiveData(data) }
    }

    func end(withError error: Error? = nil) {
        self.responses.forEach { response in
            response.streamEnded(withError: error)
            // break strong reference now that we don't need it any more
            response.fetchTask = nil
        }
        // Allow these FetchResponses to be garbage collected if the JS context
        // is done with them
        self.responses.removeAll()
    }

    func add(response: FetchResponse) {
        self.responses.insert(response)
    }
}
