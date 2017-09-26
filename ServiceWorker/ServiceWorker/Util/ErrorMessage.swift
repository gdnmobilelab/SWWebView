import Foundation

public class ErrorMessage: Error, CustomStringConvertible {

    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return self.message
    }
}
