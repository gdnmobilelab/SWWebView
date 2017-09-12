//
//  MemoryStream.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

@objc class WrappedWriteStream: NSObject, WritableStreamProtocol, StreamDelegate {

    internal let baseStream: OutputStream

    // If our underlying stream stalls, we store the pending data in memory until
    // it notifies us that it is ready to go again. For MemoryStream this never
    // happens, but it theoretically could with FileStream. Maybe?
    internal var pendingData: Data?

    internal init(baseStream: OutputStream) {
        self.baseStream = baseStream
        super.init()
        self.baseStream.delegate = self
        self.baseStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)

        self.baseStream.open()
    }

    func enqueue(_ newData: Data) {
        if newData.count == 0 {
            return
        }
        if self.baseStream.hasSpaceAvailable {
            _ = newData.withUnsafeBytes { bytes in
                self.baseStream.write(bytes, maxLength: newData.count)
            }
        } else if var pendingData = self.pendingData {
            pendingData.append(newData)
        } else {
            self.pendingData = newData
        }
    }

    internal let closedPromise = Promise<Void>.pending()

    public var closed: Promise<Void> {
        return self.closedPromise.promise
    }

    func close() {
        self.baseStream.close()
        self.baseStream.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        self.closedPromise.fulfill(())
    }

    func error(_ error: Error) {
        if self.closed.isResolved == false {
            self.closedPromise.reject(error)
        }
        self.close()
    }

    func stream(_: Stream, handle eventCode: Stream.Event) {
        //        if eventCode == .endEncountered {
        //            self.baseStream.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        //            self.closedPromise.fulfill(())
        //        }
        if eventCode == .hasSpaceAvailable, let pending = self.pendingData {
            self.enqueue(pending)
            self.pendingData = nil
        }
    }
}
