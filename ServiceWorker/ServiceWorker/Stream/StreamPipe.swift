import Foundation
import PromiseKit
import CommonCrypto

public class StreamPipe: NSObject, StreamDelegate {

    typealias ReadPosition = (start: Int, length: Int)

    let from: InputStream
    fileprivate var to = Set<OutputStream>()
    var buffer: UnsafeMutablePointer<UInt8>
    let bufferSize: Int
    var finished: Bool = false
    let runLoop = RunLoop()
    var hashListener: ((UnsafePointer<UInt8>, Int) -> Void)?

    public fileprivate(set) var started: Bool = false

    fileprivate var outputStreamLeftovers: [OutputStream: ReadPosition] = [:]

    public init(from: InputStream, bufferSize: Int) {
        self.from = from
        self.bufferSize = bufferSize
        self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        super.init()
        from.delegate = self
    }

    public func add(stream: OutputStream) throws {
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

        self.from.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        self.from.open()
        self.to.forEach { to in
            to.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            to.open()
        }
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

        return Promise(value: ())
            .then {
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
                .then { () -> Data in
                    var hashData: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                    CC_SHA256_Final(&hashData, &hashToUse)
                    return Data(bytes: hashData)
                }
        }
    }

    func doRead() {

        // OK. Having multiple streams really confuses this. Because different output streams can accept
        // bytes at different points, we need to make sure ALL streams have consumed the currently
        // read data before continuing.

        // SO. If our set of leftover data is empty, we're good to read in a new set of bytes, and set
        // each output to have a pending write of that data:

        let newReadPosition: ReadPosition = (0, self.from.read(self.buffer, maxLength: self.bufferSize))

        if newReadPosition.length == 0 {

            // Special case here - if we went to get new data, and there is none, then the stream
            // has ended. In which case we need to do no writes, and just do an early return.

            return self.finish()
        }

        // If we do have data, we now add a read position for each of our output streams.

        self.to.forEach { stream in
            self.outputStreamLeftovers[stream] = newReadPosition
        }

        // Special case here, but if we have hashing set up it doesn't really care about
        // throttling (at least, not the way we're using it) so we can just throw that
        // through immediately.

        if let hashListener = self.hashListener {
            hashListener(self.buffer.advanced(by: newReadPosition.start), newReadPosition.length)
        }
    }

    func doWrite(to stream: OutputStream, with position: ReadPosition) {

        // So now we have either a collection of leftover data or a new read. Either way, we now go
        // through and write to each destination.

        if stream.hasSpaceAvailable == false {

            // If we can't write at all then we'll just immediately return, leaving the leftover
            // position stored for the next time doReadWrite() is called.

            return
        }

        let lengthWritten = stream.write(buffer.advanced(by: position.start), maxLength: position.length)

        if lengthWritten == position.length {

            // If we've written all the data in the read, we can just remove this position
            // entirely from our store

            self.outputStreamLeftovers.removeValue(forKey: stream)

        } else {

            // Otherwise, we now record our new position.

            self.outputStreamLeftovers[stream] = (start: position.start + lengthWritten, length: position.length - lengthWritten)
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

        self.to.forEach { $0.close() }
        self.from.close()
        self.from.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        self.to.forEach { $0.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode) }

        if self.completePromise.promise.isPending {
            self.completePromise.fulfill(())
        }
    }

    public func stream(_ source: Stream, handle eventCode: Stream.Event) {
        if eventCode == .openCompleted {
            NSLog("Open complete")
        }

        NSLog("Stream event! \(eventCode)")
        if source == self.from && eventCode == .hasBytesAvailable {
            NSLog("has bytes")

            while self.from.hasBytesAvailable && self.finished == false && self.outputStreamLeftovers.count == 0 {
                self.doRead()
                self.outputStreamLeftovers.forEach({ stream, position in
                    self.doWrite(to: stream, with: position)
                })
            }
        }

        if eventCode == .hasSpaceAvailable, let output = source as? OutputStream {

            if let position = self.outputStreamLeftovers[output] {
                self.doWrite(to: output, with: position)
                NSLog("HAS SPACE: \(position.start) \(position.length)")
            }
        }

        if eventCode == .errorOccurred {
            NSLog("error")
            guard let error = source.streamError else {
                self.completePromise.reject(ErrorMessage("Stream failed but does not have an error"))
                return
            }
            self.completePromise.reject(error)
        }

        if eventCode == .endEncountered {
            NSLog("END? \(source)")
        }

        if source == self.from && eventCode == .endEncountered {
            NSLog("end")
            self.finish()
        }
    }
}
