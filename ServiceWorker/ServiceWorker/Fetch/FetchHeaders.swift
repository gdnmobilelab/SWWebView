//
//  FetchHeaders.swift
//  ServiceWorker
//
//  Created by alastair.coote on 14/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import JavaScriptCore

/// The part of our FetchHeaders object that will be available inside a JSContext
@objc protocol FetchHeadersExports: JSExport {

    func set(_ name: String, _ value: String)
    func get(_ name: String) -> String?
    func delete(_ name: String)
    func getAll(_ name: String) -> [String]?
    func append(_ name: String, _ value: String)
    func keys() -> [String]
    init()
}

/// Replicating the Fetch APIs Headers object: https://developer.mozilla.org/en-US/docs/Web/API/Headers
@objc public class FetchHeaders: NSObject, FetchHeadersExports {

    fileprivate var values = [String: [String]]()

    public func set(_ name: String, _ value: String) {
        self.values[name.lowercased()] = [value]
    }

    public func delete(_ name: String) {
        self.values.removeValue(forKey: name.lowercased())
    }

    public func append(_ name: String, _ value: String) {
        if self.values[name.lowercased()] != nil {
            self.values[name.lowercased()]!.append(value)
        } else {
            self.values[name.lowercased()] = [value]
        }
    }

    public func keys() -> [String] {
        var arr = [String]()
        for (key, _) in self.values {
            arr.append(key)
        }
        return arr
    }

    public func get(_ name: String) -> String? {
        return self.values[name.lowercased()]?.first
    }

    public func getAll(_ name: String) -> [String]? {
        return self.values[name.lowercased()]
    }

    public required override init() {
        super.init()
    }

    /// Transform a JSON string into a FetchHeaders object. Used when returning responses from the service worker
    /// cache, which stores headers as a JSON string in the database.
    ///
    /// - Parameter json: The JSON string to parse
    /// - Returns: A complete FetchHeaders object with the headers provided in the JSON
    /// - Throws: If the JSON cannot be parsed successfully.
    public static func fromJSON(_ json: String) throws -> FetchHeaders {
        let jsonAsData = json.data(using: String.Encoding.utf8)!
        let headersObj = try JSONSerialization.jsonObject(with: jsonAsData, options: JSONSerialization.ReadingOptions())
        let fh = FetchHeaders()

        for (key, values) in headersObj as! [String: [String]] {
            for value in values {
                fh.append(key, value)
            }
        }
        return fh
    }

    /// Convert a FetchHeaders object to a JSON string, for storage (i.e. in the cache database)
    ///
    /// - Returns: A JSON string
    /// - Throws: if the JSON can't be encoded. Not sure what would ever cause this to happen.
    public func toJSON() throws -> String {
        var dict = [String: [String]]()

        for key in self.keys() {
            dict[key] = []
            for value in self.getAll(key)! {
                dict[key]!.append(value)
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions())

        return String(data: jsonData, encoding: String.Encoding.utf8)!
    }
}
