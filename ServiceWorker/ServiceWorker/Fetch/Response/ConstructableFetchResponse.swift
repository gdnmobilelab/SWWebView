import Foundation
import JavaScriptCore

@objc(Response) class ConstructableFetchResponse: FetchResponseProxy, ConstructableFetchResponseJSExports {

    override var responseType: ResponseType {
        return .Basic
    }

    required init?(body: JSValue, options: [String: Any]?) {

        let headers = FetchHeaders()
        var status = 200
        var statusText = HttpStatusCodes[200] ?? "Unknown"

        if let specifiedOptions = options {

            if let specifiedStatus = specifiedOptions["status"] as? Int {
                status = specifiedStatus
            }

            if let specifiedStatusText = specifiedOptions["statusText"] as? String {
                statusText = specifiedStatusText
            }

            if let specifiedHeaders = specifiedOptions["headers"] as? [String: String] {
                specifiedHeaders.forEach({ key, val in
                    headers.set(key, val)
                })
            }
        }

        if headers.get("Content-Type") == nil {
            headers.set("Content-Type", "text/plain")
        }

        let inputStream = ConstructableFetchResponse.convert(val: body)

        guard let dispatchQueue = ServiceWorkerExecutionEnvironment.contextDispatchQueues.object(forKey: body.context) else {
            return nil
        }

        let streamPipe = StreamPipe(from: inputStream, bufferSize: 32768, dispatchQueue: dispatchQueue)

        super.init(url: nil, headers: headers, status: status, statusText: statusText, redirected: false, streamPipe: streamPipe)
    }

    fileprivate static func convert(val: JSValue) -> InputStream {
        do {
            if val.isString {

                guard let data = val.toString().data(using: String.Encoding.utf8) else {
                    throw ErrorMessage("Could not successfully parse string")
                }

                return InputStream(data: data)

            } else if let arrayBufferStream = JSArrayBufferStream(val: val) {

                return arrayBufferStream
            }

            throw ErrorMessage("Cannot convert input object")
        } catch {

            let err = JSValue(newErrorFromMessage: "\(error)", in: val.context)
            val.context.exception = err

            // Have to return something, although it'll never be used
            return InputStream(data: Data(count: 0))
        }
    }
}
