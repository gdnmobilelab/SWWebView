import JavaScriptCore

public protocol JSConvertable {
    func from(jsValue: JSValue, inQueue: DispatchQueue) -> Self?
}

public protocol JSConvertableHashable: JSConvertable, Hashable {
}

extension String: JSConvertableHashable {
    public func from(jsValue: JSValue, inQueue _: DispatchQueue) -> String? {
        return jsValue.toString()
    }
}

// extension Dictionary: JSConvertableHashable where Key: JSConvertableHashable, Value: JSConvertable {
//    public func from(jsValue: JSValue, inQueue _: DispatchQueue) -> [Key: Value]? {
//        return jsValue.toObject() as? [Key: Value]
//    }
// }
