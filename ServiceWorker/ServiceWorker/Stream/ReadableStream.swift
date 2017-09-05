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

    public static func fromInputStream(stream: InputStream, bufferSize: Int) throws -> ReadableStream {

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
                try c.close()
                stream.close()
            }
            try bufferData.withUnsafeMutableBytes { (body: UnsafeMutablePointer<UInt8>) -> Void in
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
                    try c.close()
                }
            }
        }

        let cancel = { (c: ReadableStreamController) in
            cancelled = true
            try c.close()
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
            if self.enqeueuedData.count > 0 {
                // save a reference to our current pending data
                let data = enqeueuedData
                // now set self.enqueuedData to be a new Data object
                enqeueuedData = Data()
                // now send our current pending data
                DispatchQueue.global().async {
                    cb(StreamReadResult(done: false, value: data))
                }

            } else if self.closed == true {
                // If we're already closed then just push a done
                // block for good measure
                DispatchQueue.global().async {
                    cb(StreamReadResult(done: true, value: nil))
                }

            } else {
                self.pendingReads.append(cb)
                DispatchQueue.global().async {
                    do {
                        try self.pull?(self.controller)
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
        self.dispatchQueue.sync {
            self.closed = true
            self.pendingReads.forEach { $0(StreamReadResult(done: true, value: nil)) }
        }
    }
}
