//
//  SQLiteBlobWriteStream.swift
//  Shared
//
//  Created by alastair.coote on 20/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3

public class SQLiteBlobWriteStream: SQLiteBlobStream {

    override var isWriteStream: Int32 {
        return 1
    }

    public func write(_ data: Data) -> Int {
        return data.withUnsafeBytes { bytes in
            self.write(bytes, maxLength: data.count)
        }
    }

    public func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {

        let bytesLeft = blobLength! - currentPosition!
        let lengthToWrite = min(Int32(len), bytesLeft)

        if sqlite3_blob_write(pointer!, buffer, lengthToWrite, currentPosition!) != SQLITE_OK {
            return -1
        }

        currentPosition = currentPosition! + lengthToWrite

        return Int(lengthToWrite)
    }

    public var hasSpaceAvailable: Bool {
        return currentPosition! < blobLength!
    }
}
