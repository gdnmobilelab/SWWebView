//
//  SQLiteBlobStream.swift
//  Shared
//
//  Created by alastair.coote on 20/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import SQLite3
public class SQLiteBlobStream: Stream {

    let table: String
    let column: String
    let row: Int64
    let dbPointer: OpaquePointer
    public var isOpen: Bool = false

    var pointer: OpaquePointer?
    var blobLength: Int32?
    var currentPosition: Int32?

    var isWriteStream: Int32 {
        return 0
    }

    init(_ dbPointer: OpaquePointer, table: String, column: String, row: Int64) {

        self.dbPointer = dbPointer
        self.table = table
        self.column = column
        self.row = row

        super.init()
    }

    public override func open() {
        if self.isOpen {
            return
        }
        sqlite3_blob_open(self.dbPointer, "main", self.table, self.column, self.row, self.isWriteStream, &self.pointer)
        self.blobLength = sqlite3_blob_bytes(self.pointer)
        self.currentPosition = 0
        self.isOpen = true
    }

    public override func close() {
        if self.isOpen == false {
            return
        }
        self.isOpen = false
        sqlite3_blob_close(self.pointer)
    }
}
