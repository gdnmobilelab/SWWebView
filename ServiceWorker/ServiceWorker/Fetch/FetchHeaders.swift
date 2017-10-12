import Foundation
import JavaScriptCore

/// The part of our FetchHeaders object that will be available inside a JSContext
@objc protocol FetchHeadersExports: JSExport {

    func set(_ name: String, _ value: String)
    func get(_ name: String) -> String?
    func delete(_ name: String)
    func getAll(_ name: String) -> [String]
    func append(_ name: String, _ value: String)
    func keys() -> [String]
    init()
}

/// Replicating the Fetch APIs Headers object: https://developer.mozilla.org/en-US/docs/Web/API/Headers
@objc public class FetchHeaders: NSObject, FetchHeadersExports {

    struct KeyValuePair {
        let key: String
        let value: String
    }

    internal var values: [KeyValuePair] = []

    public func set(_ name: String, _ value: String) {

        self.delete(name)
        self.values.append(KeyValuePair(key: name.lowercased(), value: value))
    }

    public func delete(_ name: String) {
        self.values = self.values.filter { $0.key != name.lowercased() }
    }

    public func append(_ name: String, _ value: String) {
        self.values.append(KeyValuePair(key: name.lowercased(), value: value))
    }

    public func keys() -> [String] {
        let nameSet = Set(values.map { $0.key })
        return Array(nameSet)
    }

    public func get(_ name: String) -> String? {
        let all = getAll(name)

        if all.count == 0 {
            return nil
        }

        return all.joined(separator: ",")
    }

    public func getAll(_ name: String) -> [String] {
        return self.values
            .filter { $0.key == name.lowercased() }
            .map { $0.value }
    }

    public required override init() {
        super.init()
    }

    fileprivate init(existing: [KeyValuePair]) {
        super.init()
        self.values = existing
    }

    public func clone() -> FetchHeaders {
        return FetchHeaders(existing: self.values)
    }

    /// Transform a JSON string into a FetchHeaders object. Used when returning responses from the service worker
    /// cache, which stores headers as a JSON string in the database.
    ///
    /// - Parameter json: The JSON string to parse
    /// - Returns: A complete FetchHeaders object with the headers provided in the JSON
    /// - Throws: If the JSON cannot be parsed successfully.
    public static func fromJSON(_ json: String) throws -> FetchHeaders {

        guard let jsonAsData = json.data(using: String.Encoding.utf8) else {
            throw ErrorMessage("Could not parse JSON string")
        }

        let headersObj = try JSONSerialization.jsonObject(with: jsonAsData, options: JSONSerialization.ReadingOptions())
        let fh = FetchHeaders()

        guard let asArray = headersObj as? [[String: String]] else {
            throw ErrorMessage("JSON string not in the form expected")
        }

        try asArray.forEach { dictionary in

            guard let key = dictionary["key"], let value = dictionary["value"] else {
                throw ErrorMessage("Header entry does not have key/value pair")
            }

            fh.append(key, value)
        }

        return fh
    }

    /// Convert a FetchHeaders object to a JSON string, for storage (i.e. in the cache database)
    ///
    /// - Returns: A JSON string
    /// - Throws: if the JSON can't be encoded. Not sure what would ever cause this to happen.
    public func toJSON() throws -> String {

        var dictionaryArray: [[String: String]] = []
        keys().forEach { key in
            self.getAll(key).forEach { value in
                dictionaryArray.append([
                    "key": key,
                    "value": value
                ])
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dictionaryArray, options: JSONSerialization.WritingOptions())

        guard let string = String(data: jsonData, encoding: String.Encoding.utf8) else {
            throw ErrorMessage("Could not encode JSON to string")
        }
        return string
    }

    public func filteredBy(allowedKeys: [String]) -> FetchHeaders {

        let lowercaseAllowed = allowedKeys.map { $0.lowercased() }

        let filteredHeaders = FetchHeaders()

        self.keys()
            .filter { lowercaseAllowed.contains($0) == true }
            .forEach { key in

                if let value = self.get(key) {
                    filteredHeaders.set(key, value)
                }
            }

        return filteredHeaders
    }

    public func filteredBy(disallowedKeys: [String]) -> FetchHeaders {

        let lowercaseDisallowed = disallowedKeys.map { $0.lowercased() }

        let filteredHeaders = FetchHeaders()

        self.keys()
            .filter { lowercaseDisallowed.contains($0) == false }
            .forEach { key in

                if let value = self.get(key) {
                    filteredHeaders.set(key, value)
                }
            }

        return filteredHeaders
    }
}
