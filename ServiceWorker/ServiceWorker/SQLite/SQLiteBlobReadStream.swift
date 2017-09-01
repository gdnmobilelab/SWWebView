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

    public var hasBytesAvailable: Bool? {
        guard let state = self.openState else {
            return nil
        }
        return state.currentPosition < state.blobLength
    }

    public func getBuffer(_: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length _: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }

    public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) throws -> Int {

        guard let state = self.openState else {
            throw ErrorMessage("Trying to read a closed stream")
        }

        let bytesLeft = state.blobLength - state.currentPosition

        let lengthToRead = min(Int32(len), bytesLeft)

        if sqlite3_blob_read(state.pointer, buffer, lengthToRead, state.currentPosition) != SQLITE_OK {
            throw ErrorMessage("Failed to read stream")
        }
        state.currentPosition += lengthToRead
        return Int(lengthToRead)
    }
}
