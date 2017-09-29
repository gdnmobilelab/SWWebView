import Foundation
import JavaScriptCore

class JSArrayBufferStream: InputStreamImplementation {

    // We don't really use this directly, but keeping a reference to it
    // ensures that the data backing the ArrayBuffer does not get garbage collected.
    fileprivate var jsValue: JSValue?

    let length: Int
    var pointer: UnsafeMutablePointer<UInt8>?
    var currentPosition: Int = 0

    fileprivate weak var _delegate: StreamDelegate?

    override var delegate: StreamDelegate? {
        get {
            return self._delegate
        }
        set(val) {
            self._delegate = val
        }
    }

    init?(val: JSValue) {
        var maybeError: JSValueRef?
        let arrType = JSValueGetTypedArrayType(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

        if arrType != kJSTypedArrayTypeArrayBuffer {
            // This isn't an ArrayBuffer, so we stop before we go any further.
            return nil
        }

        let length = JSObjectGetArrayBufferByteLength(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError)

        if maybeError != nil {
            return nil
        }

        self.length = length
        self.jsValue = val

        super.init(data: Data(count: 0))
    }

    override func open() {

        do {
            self.streamStatus = .opening
            guard let val = self.jsValue else {
                throw ErrorMessage("JSValue did not exist when trying to open stream")
            }

            var maybeError: JSValueRef?
            guard let bytes = JSObjectGetArrayBufferBytesPtr(val.context.jsGlobalContextRef, val.jsValueRef, &maybeError) else {
                throw ErrorMessage("Could not get bytes from ArrayBuffer")
            }

            if let error = maybeError {
                guard let jsError = JSValue(jsValueRef: error, in: val.context) else {
                    throw ErrorMessage("Error occurred, but could not extract message")
                }
                guard let message = jsError.objectForKeyedSubscript("message") else {
                    throw ErrorMessage("Error occurred, but could not extract message")
                }
                throw ErrorMessage(message.toString())
            }

            self.pointer = bytes.assumingMemoryBound(to: UInt8.self)

            self.streamStatus = .open
            self.emitEvent(event: .openCompleted)
            self.emitEvent(event: .hasBytesAvailable)

        } catch {
            self.throwError(error)
        }
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        self.streamStatus = .reading
        guard let pointer = self.pointer else {
            self.throwError(ErrorMessage("Pointer did not exist when trying to read"))
            return -1
        }

        let lengthLeft = self.length - self.currentPosition

        let lengthToRead = min(lengthLeft, len)

        buffer.assign(from: pointer, count: lengthToRead)
        self.pointer = pointer.advanced(by: lengthToRead)
        self.currentPosition += lengthToRead

        if self.currentPosition == self.length {
            self.emitEvent(event: .endEncountered)
        }

        self.streamStatus = .open
        return lengthToRead
    }

    override var hasBytesAvailable: Bool {
        return self.currentPosition < self.length
    }

    override func close() {
        self.streamStatus = .closed
        self.pointer = nil
        self.jsValue = nil
    }

    deinit {
        self.jsValue = nil
    }
}
