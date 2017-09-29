import Foundation
import JavaScriptCore

@objc(Response) class ConstructableFetchResponse: FetchResponseProxy, ConstructableFetchResponseJSExports {

    override var responseType: ResponseType {
        return .Basic
    }

    class Arse: NSObject, StreamDelegate {
        func stream(_: Stream, handle _: Stream.Event) {
            NSLog("argh")
        }

        static let instance = Arse()
        static var blah: Any?
    }

    required init(body: JSValue, options: [String: Any]?) {

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

        let bodyData = ConstructableFetchResponse.convert(val: body)
        let inputStream = InputStream(data: bodyData)

        let streamPipe = StreamPipe(from: inputStream, bufferSize: 32768)

        super.init(url: nil, headers: headers, status: status, statusText: statusText, redirected: false, streamPipe: streamPipe)
    }

    fileprivate class JSValueError: Error {

        let jsVal: JSValueRef

        init(_ js: JSValueRef) {
            self.jsVal = js
        }
    }

    fileprivate static func convert(val: JSValue) -> Data {
        do {
            if val.isString {

                guard let data = val.toString().data(using: String.Encoding.utf8) else {
                    throw ErrorMessage("Could not successfully parse string")
                }

                return data

            } else {

                var maybeError: JSValueRef?
                let arrType = JSValueGetTypedArrayType(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

                if let errorHappened = maybeError {
                    throw JSValueError(errorHappened)
                }
                
                if arrType == kJSTypedArrayTypeArrayBuffer {
                    guard let bytes = JSObjectGetArrayBufferBytesPtr(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError) else {
                        throw ErrorMessage("Could not get bytes from ArrayBuffer")
                    }
                    
                    if let errorHappened = maybeError {
                        throw JSValueError(errorHappened)
                    }

                    let length = JSObjectGetArrayBufferByteLength(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

                    if let errorHappened = maybeError {
                        throw JSValueError(errorHappened)
                    }

                    return Data(bytesNoCopy: bytes, count: length, deallocator: Data.Deallocator.none)
                }

                throw ErrorMessage("Do not know how to enqueue the response given to constructor")
            }
        } catch {
            let err: JSValue

            if let jsError = error as? JSValueError {
                err = JSValue(jsValueRef: jsError.jsVal, in: val.context)
            } else {
                err = JSValue(newErrorFromMessage: "\(error)", in: val.context)
            }

            val.context.exception = err

            return Data(count: 0)
        }
    }
}
