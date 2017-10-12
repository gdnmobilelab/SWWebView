import Foundation
import PromiseKit
import CommonCrypto

let logFunction: ((String) -> Void)? = nil

/// Probably the code I'm least confident about in the whole project, which is great, because it underpins
/// a lot of stuff! Anyway, it's a class to facilitate piping data from one stream to another. There are all
/// sorts of logging messages in here that I don't want to get rid of just yet, because I'm had some weirdly
/// inconsistent bugs pop up from time to time, and they're useful in debugging.
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

    public static func pipeRecordingLength(from: InputStream, to: OutputStream, bufferSize: Int) -> Promise<Int64> {

        let pipe = StreamPipe(from: from, bufferSize: bufferSize)
        var length: Int64 = 0

        pipe.hashListener = { _, count in
            length += Int64(count)
        }

        return Promise(value: ())
            .then {
                try pipe.add(stream: to)

                return pipe.pipe()
            }
            .then {
                length
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
            if self.outputStreamLeftovers.count == 0 {
                self.finish()
            }
            return
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
            logFunction?("!!!!!! \(stream) says it has no space available")
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

        if self.outputStreamLeftovers.count > 0 {
            fatalError("NO")
        }

        self.finished = true

        self.to.forEach { $0.close() }
        self.from.close()
        //        self.from.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        //        self.to.forEach { $0.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode) }

        if self.completePromise.promise.isPending {
            self.completePromise.fulfill(())
        }
    }

    public func stream(_ source: Stream, handle eventCode: Stream.Event) {

        logFunction?("Stream event! \(eventCode)")

        if eventCode == .openCompleted {
            logFunction?("Open complete \(source)")
        }

        if source == self.from && eventCode == .hasBytesAvailable {
            logFunction?("has bytes \(self.from) \(self.from.hasBytesAvailable), \(self.finished) \(self.outputStreamLeftovers.count)")

            if self.outputStreamLeftovers.count == 0 {
                logFunction?("\(self.from) has data and we're going to pipe it")
                self.doRead()
                self.outputStreamLeftovers.forEach({ stream, position in
                    self.doWrite(to: stream, with: position)
                })
            } else {
                logFunction?("\(self.from) has data but we have leftover data, so we're going to ignore that")
            }
        }

        // I have absolutely no idea why, but some OutputStreams send a .hasSpaceAvailable event while the
        // stream's hasSpaceAvailable property is false. They THEN fire an .openCompleted event, at which point
        // hasSpaceAvailable is true. I might be missing something obvious, but we're handling both here and
        // it seems to work out (because doWrite() will exit if hasSpaceAvailable is false)

        if eventCode == .hasSpaceAvailable || eventCode == .openCompleted, let output = source as? OutputStream {
            logFunction?("Stream \(output) has space available")

            if let position = self.outputStreamLeftovers[output] {
                logFunction?("Writing leftover into output \(output)")
                self.doWrite(to: output, with: position)
            } else {
                logFunction?("No data waiting for stream")
            }

            if self.outputStreamLeftovers.count == 0 {
                logFunction?("There is now no leftover data left")
                if self.from.hasBytesAvailable {
                    logFunction?("No leftover data for any stream, and input has available, so sending read event")
                    RunLoop.main.perform {
                        self.stream(self.from, handle: .hasBytesAvailable)
                    }
                } else if self.from.streamStatus == .atEnd {
                    logFunction?("Input stream is exhausted, finishing")
                    self.finish()
                } else {
                    logFunction?("\(self.from) does not have data available, but nor is it finished")
                }
            } else {
                logFunction?("There is still leftover data in \(Array(self.outputStreamLeftovers.keys))")
            }
        }

        if eventCode == .errorOccurred {
            logFunction?("error")
            guard let error = source.streamError else {
                self.completePromise.reject(ErrorMessage("Stream failed but does not have an error"))
                return
            }
            self.completePromise.reject(error)
            self.finish()
        }

        if eventCode == .endEncountered {
            logFunction?("END? \(source)")
        }

        if source == self.from && eventCode == .endEncountered && self.outputStreamLeftovers.count == 0 {
            logFunction?("end")
            self.finish()
        }

        logFunction?("Finished handling the event")
    }
}
