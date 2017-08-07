//
//  SQLiteBlobInputStream.swift
//  Shared
//
//  Created by alastair.coote on 19/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3

public class SQLiteBlobReadStream: SQLiteBlobStream {

    public var hasBytesAvailable: Bool {
        return currentPosition! < blobLength!
    }

    public func getBuffer(_: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length _: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }

    public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {

        let bytesLeft = blobLength! - currentPosition!

        let lengthToRead = min(Int32(len), bytesLeft)

        if sqlite3_blob_read(pointer!, buffer, lengthToRead, currentPosition!) != SQLITE_OK {
            return -1
        }
        currentPosition = currentPosition! + lengthToRead
        return Int(lengthToRead)
    }
}
