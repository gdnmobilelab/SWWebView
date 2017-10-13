import Foundation
import JavaScriptCore

// An additional initialiser for InputStream that handles ArrayBuffers created inside
// a JS Context.
extension InputStream {

    /// To ensure the memory does not get overwritten, we keep a reference to any byte pointer currently in use.
    /// In the data deallocator we remove this reference and free up the memory.
    fileprivate static var inUseArrayBufferPointers = Set<UnsafeMutableRawPointer>()

    convenience init?(arrayBuffer val: JSValue) {

        // The JS methods used here store any errors they encounter in this variable...
        var maybeError: JSValueRef?

        // ...so we have this function to throw an error back into the JS context, if it exists.
        let makeExceptionIfNeeded = {
            guard let error = maybeError else {
                // There is no error, so we're OK
                return
            }

            let jsError = JSValue(jsValueRef: maybeError, in: val.context)
            val.context.exception = jsError
            throw ErrorMessage("Creation of ArrayBufferStream failed \(error)")
        }

        do {
            let arrType = JSValueGetTypedArrayType(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

            if arrType != kJSTypedArrayTypeArrayBuffer {
                // This isn't an ArrayBuffer, so we stop before we go any further.
                return nil
            }

            try makeExceptionIfNeeded()

            let length = JSObjectGetArrayBufferByteLength(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

            try makeExceptionIfNeeded()

            guard let bytes = JSObjectGetArrayBufferBytesPtr(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError) else {
                throw ErrorMessage("Could not get bytes from ArrayBuffer")
            }

            try makeExceptionIfNeeded()

            // At this point we store the pointer to our data...
            InputStream.inUseArrayBufferPointers.insert(bytes)

            let data = Data(bytesNoCopy: bytes, count: length, deallocator: Data.Deallocator.custom({ releasedBytes, _ in

                // ...and then release it again when the Data object is deallocated.

                InputStream.inUseArrayBufferPointers.remove(releasedBytes)

            }))

            // Now we can just use the standard InputStream constructor.

            self.init(data: data)

        } catch {
            Log.error?("\(error)")
            return nil
        }
    }
}
