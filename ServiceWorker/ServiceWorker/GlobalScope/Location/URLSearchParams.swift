import Foundation
import JavaScriptCore

@objc public protocol URLSearchParamsExport: JSExport {
    func append(_: String, _: String)
    func delete(_: String)
    func entries(_: String) -> JSValue?
    func get(_: String) -> String?
    func getAll(_: String) -> [String]
    func has(_: String) -> Bool
    func keys(_: String) -> JSValue?
    func set(_: String, _: String)
    func sort()
    func toString() -> String
    func values() -> JSValue?
}

/// Quick implementation of URLSearchParams: https://developer.mozilla.org/en-US/docs/Web/API/URL/searchParams
/// does not store any information internally, just sets and gets from the underlying URLComponents.
@objc public class URLSearchParams: NSObject, URLSearchParamsExport {

    var components: URLComponents

    init(components: URLComponents) {
        self.components = components
        super.init()
    }

    fileprivate var queryItems: [URLQueryItem] {
        get {
            if let q = self.components.queryItems {
                return q
            }

            let arr: [URLQueryItem] = []
            self.components.queryItems = arr
            return arr
        }

        set(val) {
            self.components.queryItems = val
        }
    }

    public func append(_ name: String, _ value: String) {
        self.queryItems.append(URLQueryItem(name: name, value: value))
    }

    public func delete(_ name: String) {
        self.queryItems = self.queryItems.filter({ $0.name != name })
    }

    fileprivate func toIterator(item: Any) -> JSValue? {
        // Probably a better way of doing this but oh well

        guard let context = JSContext.current() else {
            return nil
        }

        return context
            .evaluateScript("(obj) => obj[Symbol.iterator]")
            .call(withArguments: [item])
    }

    public func entries(_ name: String) -> JSValue? {

        let entriesArray = self.queryItems
            .filter { $0.name == name }
            .map { [$0.name, $0.value] }

        // Probably a better way of doing this but oh well

        return self.toIterator(item: entriesArray)
    }

    public func get(_ name: String) -> String? {
        return self.queryItems.first(where: { $0.name == name && $0.value != nil })?.value
    }

    public func getAll(_ name: String) -> [String] {

        var all: [String] = []

        self.queryItems.forEach { item in
            if item.name == name, let val = item.value {
                all.append(val)
            }
        }

        return all
    }

    public func has(_ name: String) -> Bool {
        return self.queryItems.first(where: { $0.name == name }) != nil
    }

    public func keys(_: String) -> JSValue? {
        var keys: [String] = []

        self.queryItems.forEach({ item in
            if keys.contains(item.name) == false {
                keys.append(item.name)
            }
        })

        return self.toIterator(item: keys)
    }

    public func set(_ name: String, _ value: String) {
        self.delete(name)
        self.append(name, value)
    }

    public func sort() {
        self.queryItems = self.queryItems.sorted(by: { $0.name < $1.name })
    }

    public func toString() -> String {
        return self.components.url?.query ?? ""
    }

    public func values() -> JSValue? {

        let valuesArray = self.queryItems.map { $0.value }

        return self.toIterator(item: valuesArray)
    }
}
