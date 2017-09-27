import Foundation
import JavaScriptCore

@objc(Response) class ConstructableFetchResponse: FetchResponseProxy, ConstructableFetchResponseJSExports {

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

        super.init(url: nil, headers: headers, status: status, statusText: statusText, redirected: false)

        if let errorEncountered = self.enqueueJSValue(val: body) {
            body.context.exception = errorEncountered
        }
        self._internal.dataStream.close()
    }

    fileprivate func enqueueJSValue(val: JSValue) -> JSValue? {
        do {
            if val.isString {

                guard let data = val.toString().data(using: String.Encoding.utf8) else {
                    throw ErrorMessage("Could not successfully parse string")
                }
                self._internal.dataStream.enqueue(data)
                return nil

            } else {

                var maybeError: JSValueRef?
                let arrType = JSValueGetTypedArrayType(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

                if let errorHappened = maybeError {
                    return JSValue(jsValueRef: errorHappened, in: val.context)
                }

                if arrType == kJSTypedArrayTypeArrayBuffer {
                    guard let bytes = JSObjectGetArrayBufferBytesPtr(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError) else {
                        throw ErrorMessage("Could not get bytes from ArrayBuffer")
                    }

                    if let errorHappened = maybeError {
                        return JSValue(jsValueRef: errorHappened, in: val.context)
                    }

                    let length = JSObjectGetArrayBufferByteLength(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

                    if let errorHappened = maybeError {
                        return JSValue(jsValueRef: errorHappened, in: val.context)
                    }

                    let data = Data(bytesNoCopy: bytes, count: length, deallocator: Data.Deallocator.none)
                    self._internal.dataStream.enqueue(data)
                    return nil
                }

                throw ErrorMessage("Do not know how to enqueue the response given to constructor")
            }
        } catch {
            let err = JSValue(newErrorFromMessage: "\(error)", in: val.context)
            return err
        }
    }
}
