//
//  DbExtensions.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 25/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import ServiceWorker
import CommonCrypto
import PromiseKit

extension SQLiteBlobWriteStream {

    func pipeReadableStream(stream: ReadableStream, _ cb: @escaping (Error?, Data?) -> Void) {
        open()
        self.streamToDB(stream: stream, cb)
    }

    func pipeReadableStream(stream: ReadableStream) -> Promise<Data> {
        return Promise { fulfill, reject in
            self.pipeReadableStream(stream: stream) { err, hash in
                if err != nil {
                    reject(err!)
                } else {
                    fulfill(hash!)
                }
            }
        }
    }

    fileprivate func streamToDB(stream: ReadableStream, hash: CC_SHA256_CTX? = nil, _ cb: @escaping (Error?, Data?) -> Void) {

        var hashToUse: CC_SHA256_CTX

        if hash == nil {
            hashToUse = CC_SHA256_CTX()
            CC_SHA256_Init(&hashToUse)
        } else {
            hashToUse = hash!
        }

        stream.read { result in
            if result.done {
                self.close()

                var hashData: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                CC_SHA256_Final(&hashData, &hashToUse)
                cb(nil, Data(bytes: hashData))
            } else {
                do {
                    _ = try result.value!.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Int in
                        CC_SHA256_Update(&hashToUse, bytes, CC_LONG(result.value!.count))
                        return try self.write(bytes, maxLength: result.value!.count)
                    }
                } catch {
                    cb(error, nil)
                }
                self.streamToDB(stream: stream, hash: hashToUse, cb)
            }
        }
    }
}
