import Foundation
import JavaScriptCore

/// We need a little help with ArrayBuffers because they require us to maintain
/// a reference to the Data contained within them, otherwise the reference is
/// lost and the data overwritten.
class JSArrayBuffer: NSObject {

    /// We keep track of all the JSArrayBuffer instances that have been made
    /// and not yet deallocated. This means we never lose references to the data
    /// an array buffer is using.
    fileprivate static var currentInstances = Set<JSArrayBuffer>()

    // The actual mutable the array buffer stores data in
    var data: Data

    /// This is called by the ArrayBuffer deallocator - set in make()
    static func unassign(bytes _: UnsafeMutableRawPointer?, reference: UnsafeMutableRawPointer?) {

        guard let existingReference = reference else {
            Log.error?("Received deallocate message from a JSArrayBuffer with no native reference")
            return
        }

        let jsb = Unmanaged<JSArrayBuffer>.fromOpaque(existingReference).takeUnretainedValue()
        JSArrayBuffer.currentInstances.remove(jsb)
        Log.info?("Unassigning JSArrayBuffer memory: \(jsb.data.count) bytes")
    }

    // fileprivate becuase we don't ever want to make one of these without wrapping it
    // in the JSContext ArrayBuffer, as done in make()
    fileprivate init(from data: Data) {
        self.data = data
        super.init()
    }

    static func make(from data: Data, in context: JSContext) -> JSValue {

        let instance = JSArrayBuffer(from: data)

        // create a strong reference to this data
        JSArrayBuffer.currentInstances.insert(instance)

        // the deallocator can't store a reference to the instance directly, instead
        // we pass a pointer into the Array Buffer constructor which is then passed back
        // when the deallocator is run.
        let instancePointer = Unmanaged.passUnretained(instance).toOpaque()

        // Now we make our actual array buffer JSValue using the data and deallocation callback
        let jsInstance = instance.data.withUnsafeMutableBytes { pointer -> JSObjectRef in

            return JSObjectMakeArrayBufferWithBytesNoCopy(context.jsGlobalContextRef, pointer, data.count, { bytes, reference in
                JSArrayBuffer.unassign(bytes: bytes, reference: reference)
            }, instancePointer, nil)
        }

        return JSValue(jsValueRef: jsInstance, in: context)
    }
}
