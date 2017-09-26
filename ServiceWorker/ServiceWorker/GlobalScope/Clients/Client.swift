import Foundation
import JavaScriptCore

@objc protocol ClientExports: JSExport {
    func postMessage(_ toSend: JSValue, _ transferrable: [JSValue])
    var id: String { get }
    var type: String { get }
    var url: String { get }
}

@objc class Client: NSObject, ClientExports {

    // We keep track of the client objects we've made before now, so that we
    // pass the same instances back into JSContexts where relevant. That means
    // they'll pass equality checks etc.
    // We don't want strong references though - if the JSContext is done with
    // a reference it doesn't have anything to compare to.
    fileprivate static var existingClients = NSHashTable<Client>.weakObjects()

    static func getOrCreate<T: ClientProtocol>(from wrapper: T, in context: JSContext) -> Client {

        return self.existingClients.allObjects.first(where: { $0.wrapAround.id == wrapper.id }) ?? {

            let newClient = { () -> Client in
                // We could pass back either a Client or the more specific WindowClient - we need
                // our bridging class to match the protocol being passed in.
                if let windowWrapper = wrapper as? WindowClientProtocol {
                    return WindowClient(wrapping: windowWrapper, in: context)
                } else {
                    return Client(wrapping: wrapper, in: context)
                }
            }()

            self.existingClients.add(newClient)
            return newClient
        }()
    }

    let wrapAround: ClientProtocol
    let context: JSContext

    internal init(wrapping: ClientProtocol, in context: JSContext) {
        self.wrapAround = wrapping
        self.context = context
    }

    func postMessage(_ toSend: JSValue, _: [JSValue]) {
        self.wrapAround.postMessage(message: toSend.toObject(), transferable: nil)
    }

    var id: String {
        return self.wrapAround.id
    }

    var type: String {
        return self.wrapAround.type.stringValue
    }

    var url: String {
        return self.wrapAround.url.absoluteString
    }
}
