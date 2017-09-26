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
