import Foundation
import PromiseKit
import CommonCrypto

public class StreamPipe: NSObject, StreamDelegate {

    let from: InputStream
    fileprivate var to = Set<OutputStream>()
    var buffer: UnsafeMutablePointer<UInt8>
    let bufferSize: Int
    var finished: Bool = false
    let dispatchQueue = DispatchQueue(label: "StreamPipe", qos: DispatchQoS.background, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
    let runLoop = RunLoop()
    var hashListener: ((UnsafePointer<UInt8>, Int) -> Void)?

    public fileprivate(set) var started: Bool = false

    public init(from: InputStream, bufferSize: Int) {
        self.from = from
        self.bufferSize = bufferSize
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        super.init()
        from.delegate = self
    }

    func add(stream: OutputStream) throws {
        if self.started {
            throw ErrorMessage("Cannot add streams once piping has started")
        }
        self.to.insert(stream)
        stream.delegate = self
    }

    func start() {

        if self.started == true {
            return
        }
        self.started = true

        self.dispatchQueue.async {

            self.from.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            self.from.open()
            self.to.forEach { to in
                to.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                to.open()
            }

            while self.finished == false {
                let date = Date()
                //                                self.runLoop.acceptInput(forMode: RunLoopMode.commonModes, before: Date())
                RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: date)
            }
        }

        //        CFReadStreamSetDispatchQueue(self.from, self.dispatchQueue)
        //        self.from.open()
        //        self.to.forEach { to in
        //            CFWriteStreamSetDispatchQueue(to, self.dispatchQueue)
        //            to.open()
        //        }
    }

    fileprivate let completePromise = Promise<Void>.pending()

    public var complete: Promise<Void> {
        return self.completePromise.promise
    }

    public func pipe() -> Promise<Void> {
        StreamPipe.currentlyRunning.insert(self)
        self.start()
        return self.complete
            .always {
                StreamPipe.currentlyRunning.remove(self)
            }
    }

    /// This is really dumb, but it loses the reference to the StreamPipe if I do this
    /// any other way
    fileprivate static var currentlyRunning = Set<StreamPipe>()

    public static func pipe(from: InputStream, to: OutputStream, bufferSize: Int) -> Promise<Void> {

        let pipe = StreamPipe(from: from, bufferSize: bufferSize)

        return firstly {
            try pipe.add(stream: to)

            return pipe.pipe()
        }
    }

    public static func pipeSHA256(from: InputStream, to: OutputStream, bufferSize: Int) -> Promise<Data> {

        var hashToUse = CC_SHA256_CTX()
        CC_SHA256_Init(&hashToUse)

        let pipe = StreamPipe(from: from, bufferSize: bufferSize)

        pipe.hashListener = { bytes, count in
            CC_SHA256_Update(&hashToUse, bytes, CC_LONG(count))
        }

        return firstly {
            try pipe.add(stream: to)
            return pipe.pipe()
        }.then { () -> Data in
            var hashData: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256_Final(&hashData, &hashToUse)
            return Data(bytes: hashData)
        }
    }

    func doReadWrite() {
        let readLength = self.from.read(self.buffer, maxLength: self.bufferSize)
        if readLength == 0 {
            // end of file
            self.finish()
            return
        }

        if let hashListener = self.hashListener {
            hashListener(self.buffer, readLength)
        }

        self.to.forEach { toStream in
            let lengthWritten = toStream.write(self.buffer, maxLength: readLength)
            if lengthWritten != readLength {
                Log.error?("Stream could not accept all the data given to it. Removing it from target array")
                self.to.remove(toStream)
            }
        }
    }

    deinit {
        self.buffer.deallocate(capacity: self.bufferSize)
        if self.completePromise.promise.isPending {

            // This isn't strictly necessary, but PromiseKit logs a warning about
            // an unresolved promise if we don't do this. For our purposes, it's entirely
            // expected that a StreamPipe might not be resolved - for instance when we use
            // a FetchResponse without also downloading the body.

            self.completePromise.fulfill(())
        }
    }

    fileprivate func finish() {
        if self.finished {
            return
        }

        self.finished = true

        self.dispatchQueue.async {
            self.to.forEach { $0.close() }
            self.from.close()
            self.from.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            self.to.forEach { $0.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode) }
        }

        //        CFReadStreamSetDispatchQueue(self.from, nil)
        //        self.from.close()
        //
        //        self.to.forEach { to in
        //            CFWriteStreamSetDispatchQueue(to, nil)
        //            to.close()
        //        }

        //        let doStop = {
        //            self.to.forEach { $0.close() }
        //            self.from.close()
        //            self.from.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        //            self.to.forEach { $0.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode) }
        //        }
        //
        //        if Thread.isMainThread == false {
        //            DispatchQueue.main.async(execute: doStop)
        //        } else {
        //            doStop()
        //        }

        //        doStop()

        if self.completePromise.promise.isPending {
            self.completePromise.fulfill(())
        }
    }

    public func stream(_ source: Stream, handle eventCode: Stream.Event) {
        if source == self.from && eventCode == .hasBytesAvailable {
            while self.from.hasBytesAvailable {
                self.doReadWrite()
            }
            if self.from.hasBytesAvailable {
                NSLog("Stopped while still have bytes to write?")
            }
        }

        if eventCode == .errorOccurred {
            guard let error = source.streamError else {
                self.completePromise.reject(ErrorMessage("Stream failed but does not have an error"))
                return
            }
            self.completePromise.reject(error)
        }

        if source == self.from && eventCode == .endEncountered {
            self.finish()
        }
    }
}
