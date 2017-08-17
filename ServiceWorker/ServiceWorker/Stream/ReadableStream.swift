//
//  ReadableStream.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

@objc public class ReadableStream: NSObject {

    var controller: ReadableStreamController?
    fileprivate var enqeueuedData = NSMutableData()
    fileprivate var pendingReads: [PendingRead] = []
    var closed = false
    public typealias PendingRead = (StreamReadResult) -> Void
    typealias StreamOperation = (ReadableStreamController) -> Void

    // The readable stream needs to be thread-safe, so we ensure that all
    // read operations happen on the same queue.
    fileprivate let dispatchQueue = DispatchQueue(label: "Stream reader")

    let start: StreamOperation?
    let pull: StreamOperation?
    let cancel: StreamOperation?

    init(start: StreamOperation? = nil, pull: StreamOperation? = nil, cancel: StreamOperation? = nil) {
        self.start = start
        self.pull = pull
        self.cancel = cancel
        super.init()
        self.controller = ReadableStreamController(self)

        if self.start != nil {
            self.start!(self.controller!)
        }
    }

    public static func fromInputStream(stream: InputStream, bufferSize: Int) -> ReadableStream {

        var bufferData = Data(count: bufferSize)

        var cancelled = false
        let start = { (_: ReadableStreamController) in
            stream.open()
        }

        let pull = { (c: ReadableStreamController) in
            if cancelled == true {
                return
            }
            if stream.hasBytesAvailable == false {
                c.close()
                stream.close()
            }
            bufferData.withUnsafeMutableBytes { (body: UnsafeMutablePointer<UInt8>) -> Void in
                let length = stream.read(body, maxLength: bufferSize)

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

                if stream.hasBytesAvailable == false {
                    stream.close()
                    c.close()
                }
            }
        }

        let cancel = { (c: ReadableStreamController) in
            cancelled = true
            c.close()
        }

        return ReadableStream(start: start, pull: pull, cancel: cancel)
    }

    internal func enqueue(_ data: Data) throws {

        try self.dispatchQueue.sync {
            if self.closed == true {
                throw ErrorMessage("Cannot enqueue data after stream is closed")
            }

            if self.pendingReads.count > 0 {
                let read = pendingReads.remove(at: 0)
                DispatchQueue.main.async {
                    read(StreamReadResult(done: false, value: data))
                }
            } else {
                self.enqeueuedData.append(data)
            }
        }
    }

    public func read(cb: @escaping PendingRead) {
        self.dispatchQueue.sync {
            if self.enqeueuedData.length > 0 {
                let data = enqeueuedData
                enqeueuedData = NSMutableData()
                DispatchQueue.main.async {
                    cb(StreamReadResult(done: false, value: data as Data))
                }

            } else if self.closed == true {
                // If we're already closed then just push a done
                // block for good measure
                DispatchQueue.main.async {
                    cb(StreamReadResult(done: true, value: nil))
                }

            } else {
                self.pendingReads.append(cb)
                DispatchQueue.main.async {
                    self.pull?(self.controller!)
                }
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

    public func readToEnd(transformer: @escaping (Data) throws -> Void) -> Promise<Void> {

        return Promise { fulfill, reject in

            var doRead: (() -> Void)?

            doRead = {
                self.read { read in
                    if read.done {
                        fulfill(())
                    } else {
                        do {
                            try transformer(read.value!)
                            doRead!()
                        } catch {
                            reject(error)
                        }
                    }
                }
            }

            doRead!()
        }
    }

    func close() {
        self.dispatchQueue.sync {
            self.closed = true
            self.pendingReads.forEach { $0(StreamReadResult(done: true, value: nil)) }
        }
    }
}
