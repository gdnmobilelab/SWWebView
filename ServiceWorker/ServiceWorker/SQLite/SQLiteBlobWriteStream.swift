import Foundation
import SQLite3

public class SQLiteBlobWriteStream: SQLiteBlobStream {

    override var isWriteStream: Int32 {
        return 1
    }

    public func write(_ data: Data) throws -> Int {
        return try data.withUnsafeBytes { bytes in
            try self.write(bytes, maxLength: data.count)
        }
    }

    public func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) throws -> Int {

        guard let state = self.openState else {
            throw ErrorMessage("Cannot write to a stream that is not open")
        }

        let bytesLeft = state.blobLength - state.currentPosition
        let lengthToWrite = min(Int32(len), bytesLeft)

        if sqlite3_blob_write(state.pointer, buffer, lengthToWrite, state.currentPosition) != SQLITE_OK {
            return -1
        }

        state.currentPosition += lengthToWrite

        return Int(lengthToWrite)
    }

    public var hasSpaceAvailable: Bool? {
        guard let state = self.openState else {
            return nil
        }
        return state.currentPosition < state.blobLength
    }
}
