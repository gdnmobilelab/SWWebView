import Foundation
import PromiseKit

/// Another part of our bridge between FetchSession and URLSession. We use both a URLSessionDataTask AND a
/// URLSessionStreamTask as part of our download process, so we need a place where we can connect the two.
class FetchTask: NSObject {

    /// When we receive the headers etc., we are using a data task...
    let dataTask: URLSessionDataTask

    /// ...but when we start receiving data, we've transformed it into a session task.
    var streamTask: URLSessionStreamTask?

    /// We need to keep a reference to the original request in order to check things like the
    /// redirect property.
    let request: FetchRequest

    fileprivate unowned let dispatchQueue: DispatchQueue

    /// We wait until we've successfully transformed our download into a stream before we
    /// return the initial header, so that our FetchResponse object always
    /// comes with a stream to act on immediately. That means we need to
    /// store the initial response here while we wait for the stream to arrive.
    var initialResponse: HTTPURLResponse?

    /// This helps us mirror the fetch() behaviour on the web - our FetchSession.fetch() function
    /// returns this promise when our initial response and stream are ready.
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
        
        // Haven't explored this extensively, but if the task gets deallocated it's because the
        // code is no longer using it. For example, calling fetch() and never running a data transformer.
        // If that happens, we terminate the download, so we're not wasting bandwidth with content we
        // do not need.
        
        if self.dataTask.state == .running {
            Log.info?("Cancelling running fetch task because nothing is listening to it")
            self.dataTask.cancel()
        }
    }

    
    /// Because the redirect delegate function in FetchSession is run separately from the creation of our FetchResponse,
    /// we need to keep a reference to indicate whether a redirect happened or not.
    fileprivate var redirected = false

    func shouldFollowRedirect() -> Bool {
        
        // As specified by the Fetch API: https://developer.mozilla.org/en-US/docs/Web/API/Request/redirect
        // we need to change our behaviour based on what the user has specified.
        
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

        // The order should always go Redirect check -> initial response -> stream, but let's
        // not assume, we should check for the presence of the initial response:
     
        guard let initialResponse = self.initialResponse else {
            throw ErrorMessage("Received stream but no HTTP response")
        }

        guard let url = initialResponse.url else {
            throw ErrorMessage("HTTPURLResponse has no URL")
        }

        let headers = FetchHeaders()

        // Transfer the headers from HTTPURLResponse into our custom FetchHeaders class.
        
        try initialResponse.allHeaderFields.forEach { key, val in
            
            guard let keyString = key as? String, let valString = val as? String else {
                throw ErrorMessage("Could not parse HTTPURLResponse headers")
            }

            if keyString.lowercased() == "content-encoding" || keyString.lowercased() == "content-length" {
                
                // URLSession automatically decodes content (which we don't actually want it to do)
                // so if we pass along this response to a browser with the encoding header still set, it'll
                // fail because it will try to decode non-compressed content. The content-length header is also
                // based on compressed size:
                //
                // https://stackoverflow.com/a/3819303/470339
                //
                // so it'll now be incorrect. Since we now have no way of knowing what the uncompressed size
                // will be, we omit the header entirely.
                
                return
                
            }
            
            headers.append(keyString, valString)
        }
        
        // Now, at last, create our full FetchResponse class

        let fetchResponse = FetchResponse(url: url, headers: headers, status: initialResponse.statusCode, redirected: self.redirected, streamPipe: streamPipe)

        // And resolve our hasResponse promise with that response.
        
        self.hasResponsePromise.fulfill(fetchResponse)
    }
}
