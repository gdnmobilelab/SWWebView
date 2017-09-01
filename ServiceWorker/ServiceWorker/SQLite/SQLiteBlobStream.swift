//
//  SQLiteBlobStream.swift
//  Shared
//
//  Created by alastair.coote on 20/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3
public class SQLiteBlobStream {
    
    class State {
        let pointer: OpaquePointer
        let blobLength: Int32
        var currentPosition: Int32
        
        init(pointer:OpaquePointer, blobLength:Int32) {
            self.pointer = pointer
            self.blobLength = blobLength
            self.currentPosition = 0
        }
    }

    let table: String
    let column: String
    let row: Int64
    let dbPointer: OpaquePointer
    
    public var isOpen: Bool {
        return self.openState != nil
    }

    internal var openState:State? = nil

    var isWriteStream: Int32 {
        return 0
    }

    init(_ dbPointer: OpaquePointer, table: String, column: String, row: Int64) {

        self.dbPointer = dbPointer
        self.table = table
        self.column = column
        self.row = row

    }

    public func open() throws {
        if self.openState != nil {
            throw ErrorMessage("Blob stream is already open")
        }
        
        var pointer: OpaquePointer?
        
        sqlite3_blob_open(self.dbPointer, "main", self.table, self.column, self.row, self.isWriteStream, &pointer)
        
        guard let setPointer = pointer else {
            throw ErrorMessage("Blob pointer was not stored")
        }

        self.openState = State(pointer: setPointer, blobLength: sqlite3_blob_bytes(setPointer))

    }

    public func close() throws {
        
        guard let openState = self.openState else {
            throw ErrorMessage("Blob stream is not open")
        }
        
        sqlite3_blob_close(openState.pointer)
        self.openState = nil
        
    }
}
