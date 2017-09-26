import Foundation
import PromiseKit

@objc public class ReadableStream: NSObject {

    let controller: ReadableStreamController
    fileprivate var enqeueuedData = Data()
    fileprivate var pendingReads: [PendingRead] = []
    var closed = false
    public typealias PendingRead = (StreamReadResult) -> Void
    typealias StreamOperation = (ReadableStreamController) throws -> Void
    typealias StreamOperationNoThrow = (ReadableStreamController) -> Void

    // The readable stream needs to be thread-safe, so we ensure that all
    // read operations happen on the same queue.
    fileprivate let dispatchQueue = DispatchQueue(label: "Stream reader")

    let start: StreamOperation?
    let pull: StreamOperation?
    let cancel: StreamOperation?

    init(start: StreamOperationNoThrow? = nil, pull: StreamOperation? = nil, cancel: StreamOperation? = nil) {
        self.start = start
        self.pull = pull
        self.cancel = cancel
        self.controller = ReadableStreamController()
        super.init()

        self.controller.stream = self
        if let startExists = start {
            startExists(self.controller)
        }
    }

    deinit {
        NSLog("deinit?")
    }

    public static func fromLocalURL(_ url: URL, bufferSize: Int) throws -> ReadableStream {

        var bufferData = Data(count: bufferSize)

        var streamToUse: InputStream? = InputStream(url: url)

        var cancelled = false
        let start = { (_: ReadableStreamController) in

            guard let inputStream = streamToUse else {
                Log.error?("Trying to start a nil stream")
                return
            }

            inputStream.open()
        }

        let pull = { (c: ReadableStreamController) in

            guard let inputStream = streamToUse else {
                Log.error?("Trying to pull from nil stream")
                return
            }

            if cancelled == true {
                return
            }
            if inputStream.hasBytesAvailable == false {
                try c.close()
                inputStream.close()
                streamToUse = nil
            }
            try bufferData.withUnsafeMutableBytes { (body: UnsafeMutablePointer<UInt8>) -> Void in
                let length = inputStream.read(body, maxLength: bufferSize)

                if length > 0 {
                    // We might have read less data than the size of our buffer.
                    let actualReadData = Data(bytesNoCopy: body, count: length, deallocator: Data.Deallocator.none)
                    do {

                        try c.enqueue(actualReadData)
                    } catch {
                        cancelled = true
                        Log.error?("Failed to read stream: \(error)")
                    }
                }

                if inputStream.hasBytesAvailable == false {
                    inputStream.close()
                    streamToUse = nil
                    try c.close()
                }
            }
        }

        let cancel = { (c: ReadableStreamController) in
            cancelled = true
            streamToUse = nil
            try c.close()
        }

        return ReadableStream(start: start, pull: pull, cancel: cancel)
    }

    internal func enqueue(_ data: Data) throws {

        try self.dispatchQueue.sync { [weak self] in

            guard let selfInstance = self else {
                Log.error?("Trying to enqueue into a disposed stream")
                return
            }

            if selfInstance.closed == true {
                throw ErrorMessage("Cannot enqueue data after stream is closed")
            }

            if selfInstance.pendingReads.count > 0 {
                let read = pendingReads.remove(at: 0)
                DispatchQueue.main.async {
                    read(StreamReadResult(done: false, value: data))
                }
            } else {
                selfInstance.enqeueuedData.append(data)
            }
        }
    }

    public func read(cb: @escaping PendingRead) {
        self.dispatchQueue.sync { [weak self] in

            guard let selfInstance = self else {
                Log.error?("Trying to read from a stream that has been disposed")
                return
            }

            if selfInstance.enqeueuedData.count > 0 {
                // save a reference to our current pending data
                let data = enqeueuedData
                // now set self.enqueuedData to be a new Data object
                enqeueuedData = Data()
                // now send our current pending data
                DispatchQueue.global().async {
                    cb(StreamReadResult(done: false, value: data))
                }

            } else if selfInstance.closed == true {
                // If we're already closed then just push a done
                // block for good measure
                DispatchQueue.global().async {
                    cb(StreamReadResult(done: true, value: nil))
                }

            } else {
                selfInstance.pendingReads.append(cb)
                DispatchQueue.global().async {
                    do {
                        try selfInstance.pull?(selfInstance.controller)
                    } catch {
                        Log.error?("Pull operation on stream failed: \(error)")
                    }
                }
            }
        }
    }

    fileprivate func dataReadToEnd(targetData: NSMutableData = NSMutableData(), fulfill: @escaping (Data) -> Void, reject: @escaping (Error) -> Void) {
        self.read { read in
            if read.done {
                fulfill(targetData as Data)
            } else if let value = read.value {
                targetData.append(value)
                self.dataReadToEnd(targetData: targetData, fulfill: fulfill, reject: reject)
            } else {
                reject(ErrorMessage("Stream read returned neither an error nor data"))
            }
        }
    }

    public func read() -> Promise<StreamReadResult> {

        return Promise { (fulfill: @escaping (StreamReadResult) -> Void, _: (Error) -> Void) in
            self.read { pending in

                fulfill(pending)
            }
        }
    }

    public func readAll() -> Promise<Data> {

        return Promise { fulfill, reject in
            self.dataReadToEnd(fulfill: fulfill, reject: reject)
        }
    }

    func close() {
        self.dispatchQueue.sync { [weak self] in

            guard let selfInstance = self else {
                Log.error?("Trying to close stream that has already been disposed")
                return
            }

            selfInstance.closed = true
            selfInstance.pendingReads.forEach { $0(StreamReadResult(done: true, value: nil)) }
            selfInstance.pendingReads.removeAll()
        }
    }
}
