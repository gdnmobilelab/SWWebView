//
//  MemoryStream.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

@objc class WrappedStream: NSObject, WritableStreamProtocol, StreamDelegate {

    internal let baseStream: OutputStream

    internal init(baseStream: OutputStream) {
        self.baseStream = baseStream
        super.init()
        self.baseStream.delegate = self
        self.baseStream.open()
    }

    func enqueue(_ newData: Data) {
        _ = newData.withUnsafeBytes { bytes in
            self.baseStream.write(bytes, maxLength: newData.count)
        }
    }

    fileprivate let closedPromise = Promise<Void>.pending()

    public var closed: Promise<Void> {
        return self.closedPromise.promise
    }

    func close() {
        self.baseStream.close()
        self.closedPromise.fulfill(())
    }

    func error(_ error: Error) {
        if self.closed.isResolved == false {
            self.closedPromise.reject(error)
        }
        self.close()
    }

    func stream(_: Stream, handle eventCode: Stream.Event) {
        NSLog("stream event!")
        if eventCode == .endEncountered {

            self.closedPromise.fulfill(())
        }
    }
}
