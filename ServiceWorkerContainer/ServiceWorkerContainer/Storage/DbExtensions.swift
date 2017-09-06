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

class PipeStreamer {

    var readStream: ReadableStream?
    var blobStream: SQLiteBlobWriteStream?

    init(readStream: ReadableStream, blobStream: SQLiteBlobWriteStream) {
        self.readStream = readStream
        self.blobStream = blobStream
    }

    func stream(_ cb: @escaping (Error?, Data?) -> Void) {
        self.streamToDB(cb)
    }

    fileprivate func streamToDB(hash: CC_SHA256_CTX? = nil, _ cb: @escaping (Error?, Data?) -> Void) {

        var hashToUse: CC_SHA256_CTX

        if let hashExists = hash {
            hashToUse = hashExists
        } else {
            hashToUse = CC_SHA256_CTX()
            CC_SHA256_Init(&hashToUse)
        }

        guard let readStream = self.readStream, let blobStream = self.blobStream else {
            cb(ErrorMessage("ReadableStream no longer exists"), nil)
            return
        }

        readStream.read { result in
            if result.done {
                do {
                    try blobStream.close()
                    self.blobStream = nil
                    self.readStream = nil
                } catch {
                    cb(error, nil)
                    return
                }

                var hashData: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                CC_SHA256_Final(&hashData, &hashToUse)
                cb(nil, Data(bytes: hashData))
            } else if let value = result.value {
                do {
                    _ = try value.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Int in
                        CC_SHA256_Update(&hashToUse, bytes, CC_LONG(value.count))
                        return try blobStream.write(bytes, maxLength: value.count)
                    }
                } catch {
                    cb(error, nil)
                }
                self.streamToDB(hash: hashToUse, cb)
            } else {
                cb(ErrorMessage("Readable stream returned done == false but no value"), nil)
            }
        }
    }
}

extension SQLiteBlobWriteStream {

    func pipeReadableStream(stream: ReadableStream, _ cb: @escaping (Error?, Data?) -> Void) {
        do {
            try open()
        } catch {
            cb(error, nil)
            return
        }

        let streamer = PipeStreamer(readStream: stream, blobStream: self)
        return streamer.stream(cb)

        //            self.streamToDB(stream: stream, cb)
    }

    func pipeReadableStream(stream: ReadableStream) -> Promise<Data> {
        return Promise { fulfill, reject in
            self.pipeReadableStream(stream: stream) { err, hash in
                if let error = err {
                    reject(error)
                } else if let result = hash {
                    fulfill(result)
                } else {
                    reject(ErrorMessage("No error was returned, but no hash was returned either"))
                }
            }
        }
    }

    //    fileprivate func streamToDB(stream: ReadableStream, hash: CC_SHA256_CTX? = nil, _ cb: @escaping (Error?, Data?) -> Void) {
    //
    //        var hashToUse: CC_SHA256_CTX
    //
    //        if let hashExists = hash {
    //            hashToUse = hashExists
    //        } else {
    //            hashToUse = CC_SHA256_CTX()
    //            CC_SHA256_Init(&hashToUse)
    //        }
    //
    //        stream.read { result in
    //            if result.done {
    //                do {
    //                    try self.close()
    //                } catch {
    //                    cb(error, nil)
    //                    return
    //                }
    //
    //                var hashData: [UInt8] = Array(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    //                CC_SHA256_Final(&hashData, &hashToUse)
    //                cb(nil, Data(bytes: hashData))
    //            } else if let value = result.value {
    //                do {
    //                    _ = try value.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Int in
    //                        CC_SHA256_Update(&hashToUse, bytes, CC_LONG(value.count))
    //                        return try self.write(bytes, maxLength: value.count)
    //                    }
    //                } catch {
    //                    cb(error, nil)
    //                }
    //                self.streamToDB(stream: stream, hash: hashToUse, cb)
    //            } else {
    //                cb(ErrorMessage("Readable stream returned done == false but no value"), nil)
    //            }
    //        }
    //    }
}
