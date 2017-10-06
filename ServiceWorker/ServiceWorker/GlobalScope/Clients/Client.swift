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

    static func getOrCreate<T: ClientProtocol>(from wrapper: T) -> Client {

        return self.existingClients.allObjects.first(where: { $0.wrapAround.id == wrapper.id }) ?? {

            let newClient = { () -> Client in
                // We could pass back either a Client or the more specific WindowClient - we need
                // our bridging class to match the protocol being passed in.
                if let windowWrapper = wrapper as? WindowClientProtocol {
                    return WindowClient(wrapping: windowWrapper)
                } else {
                    return Client(wrapping: wrapper)
                }
            }()

            self.existingClients.add(newClient)
            return newClient
        }()
    }

    let wrapAround: ClientProtocol
    internal init(wrapping: ClientProtocol) {
        self.wrapAround = wrapping
    }

    func postMessage(_ toSend: JSValue, _: [JSValue]) {

        guard let currentQueue = ServiceWorkerExecutionEnvironment.contextDispatchQueues.object(forKey: JSContext.current()) else {
            Log.error?("Could not get dispatch queue for current JS Context")
            return
        }

        dispatchPrecondition(condition: DispatchPredicate.onQueue(currentQueue))

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
