import Foundation
import PromiseKit

public class StreamPipe: NSObject, StreamDelegate {

    let from: InputStream
    fileprivate var to = Set<OutputStream>()
    var buffer: UnsafeMutablePointer<UInt8>
    let bufferSize: Int

    public fileprivate(set) var started: Bool = false

    init(from: InputStream, bufferSize: Int) {
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

        let doStart = {
            self.from.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            self.from.open()
            self.to.forEach { toStream in
                toStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                toStream.open()
            }
        }

        if Thread.isMainThread == false {
            // There's something weird with the ServiceWorker DispatchQueue here - if we
            // don't don't schedule in the main queue, the stream never dispatches.
            DispatchQueue.main.sync(execute: doStart)
        } else {
            doStart()
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

        return firstly {
            try pipe.add(stream: to)

            return pipe.pipe()
        }
    }

    func doReadWrite() {

        let readLength = self.from.read(self.buffer, maxLength: self.bufferSize)

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

    public func stream(_ source: Stream, handle eventCode: Stream.Event) {

        if source == self.from && eventCode == .hasBytesAvailable {
            while self.from.hasBytesAvailable && self.to.first(where: { $0.hasSpaceAvailable == false }) == nil {
                self.doReadWrite()
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
            self.to.forEach { $0.close() }
            self.from.close()
            let doStop = {
                self.from.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                self.to.forEach { $0.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode) }
            }

            if Thread.isMainThread == false {
                DispatchQueue.main.sync(execute: doStop)
            } else {
                doStop()
            }

            if self.completePromise.promise.isPending {
                self.completePromise.fulfill(())
            }
        }
    }
}
