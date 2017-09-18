//
//  WebSQLResultRows.swift
//  ServiceWorker
//
//  Created by alastair.coote on 18/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

@objc protocol WebSQLResultRowsExports: JSExport {
    func item(_: Int) -> Any?
    var length: Int { get }
}

@objc class WebSQLResultRows: NSObject, WebSQLResultRowsExports {

    let rows: [Any]

    init(rows: [Any]) {
        self.rows = rows
    }

    func item(_ index: Int) -> Any? {
        return self.rows[index]
    }

    var length: Int {
        return self.rows.count
    }
}
