import Foundation
import PromiseKit

class FetchTask: NSObject {

    let dataTask: URLSessionDataTask
    var streamTask: URLSessionStreamTask?
    let request: FetchRequest
    fileprivate unowned let dispatchQueue: DispatchQueue

    var responses = Set<FetchResponse>()
    var initialResponse: HTTPURLResponse?
    var streamPipe: StreamPipe?

    fileprivate let hasResponsePromise = Promise<FetchResponse>.pending()

    var hasResponse: Promise<FetchResponse> {
        return self.hasResponsePromise.promise
    }

    init(for task: URLSessionDataTask, with request: FetchRequest, on queue: DispatchQueue) {
        self.dataTask = task
        self.request = request
        self.dispatchQueue = queue
        super.init()
    }

    deinit {
        if self.dataTask.state == .running {
            Log.info?("Cancelling running fetch task because nothing is listening to it")
            self.dataTask.cancel()
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

    func receiveStream(stream: InputStream) throws {
        let streamPipe = StreamPipe(from: stream, bufferSize: 1024)

        guard let initialResponse = self.initialResponse else {
            throw ErrorMessage("Received stream but no HTTP response")
        }

        guard let url = initialResponse.url else {
            throw ErrorMessage("HTTPURLResponse has no URL")
        }

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
                headers.set("Content-Length", String(self.dataTask.countOfBytesExpectedToReceive))
                return
            }

            headers.append(keyString, valString)
        }

        let fetchResponse = FetchResponse(url: url, headers: headers, status: initialResponse.statusCode, redirected: self.redirected, streamPipe: streamPipe)

        self.hasResponsePromise.fulfill(fetchResponse)
    }
}
