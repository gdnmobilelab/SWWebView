import Foundation
import JavaScriptCore
import PromiseKit

@objc class OpaqueResponse: FetchResponseProxy {

    override var responseType: ResponseType {
        return .Opaque
    }

    let emptyHeaders = FetchHeaders()
    var _streamPipe: StreamPipe?
    override var streamPipe: StreamPipe? {
        return self._streamPipe
    }

    override var headers: FetchHeaders {
        return self.emptyHeaders
    }

    override init(from response: FetchResponse) throws {
        let dummyStream = InputStream(data: Data(count: 0))

        guard let originalPipe = response.streamPipe else {
            throw ErrorMessage("Could not get original response stream")
        }

        self._streamPipe = StreamPipe(from: dummyStream, bufferSize: 1, dispatchQueue: originalPipe.dispatchQueue)

        try super.init(from: response)
    }
}
