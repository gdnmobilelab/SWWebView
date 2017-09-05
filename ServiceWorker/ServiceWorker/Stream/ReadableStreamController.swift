//
//  ReadableStreamController.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc public class ReadableStreamController: NSObject {

    weak var stream: ReadableStream?

    public func enqueue(_ data: Data) throws {
        guard let stream = self.stream else {
            throw ErrorMessage("Controller has no stream")
        }
        try stream.enqueue(data)
    }

    public func close() throws {
        guard let stream = self.stream else {
            throw ErrorMessage("Controller has no stream")
        }
        stream.close()
    }
}
