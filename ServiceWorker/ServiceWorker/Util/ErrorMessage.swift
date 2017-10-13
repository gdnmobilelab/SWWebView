import Foundation

/// An attempt to bridge between JS-like errors and Swift-like errors - Swift
/// would (I think) like us to create different classes/enums for each error. But
/// this lets us throw errors with custom strings attached.
public class ErrorMessage: Error, CustomStringConvertible {

    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return self.message
    }
}
