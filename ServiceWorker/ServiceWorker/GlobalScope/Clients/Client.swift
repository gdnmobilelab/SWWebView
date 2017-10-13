import Foundation
import JavaScriptCore

@objc protocol ClientExports: JSExport {
    func postMessage(_ toSend: JSValue, _ transferrable: [JSValue])
    var id: String { get }
    var type: String { get }
    var url: String { get }
}

/// An implementation of the Client API: https://developer.mozilla.org/en-US/docs/Web/API/Client
/// mostly a wrapper around an external class that implements ClientProtocol.
@objc class Client: NSObject, ClientExports {

    // We keep track of the client objects we've made before now, so that we
    // pass the same instances back into JSContexts where relevant. That means
    // they'll pass equality checks etc.
    // We don't want strong references though - if the JSContext is done with
    // a reference it doesn't have anything to compare to, so it can be garbage collected.
    fileprivate static var existingClients = NSHashTable<Client>.weakObjects()

    static func getOrCreate<T: ClientProtocol>(from wrapper: T) -> Client {

        return self.existingClients.allObjects.first(where: { $0.clientInstance.id == wrapper.id }) ?? {

            let newClient = { () -> Client in

                // We could pass back either a Client or the more specific WindowClient - we need
                // our bridging class to match the protocol being passed in.

                if let windowWrapper = wrapper as? WindowClientProtocol {
                    return WindowClient(wrapping: windowWrapper)
                } else {
                    return Client(client: wrapper)
                }
            }()

            self.existingClients.add(newClient)
            return newClient
        }()
    }

    let clientInstance: ClientProtocol
    internal init(client: ClientProtocol) {
        self.clientInstance = client
    }

    func postMessage(_ toSend: JSValue, _: [JSValue]) {

        self.clientInstance.postMessage(message: toSend.toObject(), transferable: nil)
    }

    var id: String {
        return self.clientInstance.id
    }

    var type: String {
        return self.clientInstance.type.stringValue
    }

    var url: String {
        return self.clientInstance.url.absoluteString
    }
}
