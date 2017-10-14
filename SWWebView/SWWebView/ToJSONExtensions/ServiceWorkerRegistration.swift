import Foundation
import ServiceWorkerContainer

extension ServiceWorkerRegistration: ToJSON {
    func toJSONSuitableObject() -> Any {

        return [
            "id": self.id,
            "scope": self.scope.sWWebviewSuitableAbsoluteString,
            "active": self.active?.toJSONSuitableObject(),
            "waiting": self.waiting?.toJSONSuitableObject(),
            "installing": self.installing?.toJSONSuitableObject(),
            "redundant": self.redundant?.toJSONSuitableObject(),
            "unregistered": self.unregistered
        ]
    }
}
