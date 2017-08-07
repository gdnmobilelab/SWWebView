//
//  ReadableStreamController.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public class ReadableStreamController: NSObject {

    let stream: ReadableStream

    init(_ stream: ReadableStream) {
        self.stream = stream
    }

    public func enqueue(_ data: Data) throws {
        try self.stream.enqueue(data)
    }

    public func close() {
        self.stream.close()
    }
}
