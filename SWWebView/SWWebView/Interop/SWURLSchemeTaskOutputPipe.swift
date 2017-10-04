//
//  SWURLSchemeTaskOutputPipe.swift
//  SWWebView
//
//  Created by alastair.coote on 04/10/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker

class SWURLSchemeTaskOutputStream: OutputStreamImplementation {

    let task: SWURLSchemeTask
    let statusCode: Int
    let headers: [String: String]

    init(task: SWURLSchemeTask, statusCode: Int, headers: [String: String]) throws {

        self.task = task
        self.statusCode = statusCode
        self.headers = headers

        super.init(toMemory: ())
    }

    convenience init(task: SWURLSchemeTask, response: FetchResponseProtocol) throws {

        var headers: [String: String] = [:]
        response.headers.keys().forEach { key in
            if let value = response.headers.get(key) {
                headers[key] = value
            }
        }

        try self.init(task: task, statusCode: response.status, headers: headers)
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        let data = Data(bytes: buffer, count: len)

        do {
            try self.task.didReceive(data)
            return len
        } catch {
            self.throwError(error)
            return -1
        }
    }

    override var hasSpaceAvailable: Bool {
        return true
    }

    override func open() {
        do {
            try self.task.didReceiveHeaders(statusCode: self.statusCode, headers: self.headers)
            self.emitEvent(event: .openCompleted)
            self.emitEvent(event: .hasSpaceAvailable)
        } catch {
            self.throwError(error)
        }
    }

    override func close() {
        do {
            try self.task.didFinish()
        } catch {
            self.throwError(error)
        }
    }
}
