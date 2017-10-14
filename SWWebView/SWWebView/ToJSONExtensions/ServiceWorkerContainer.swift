import Foundation
import ServiceWorkerContainer

extension ServiceWorkerContainer: ToJSON {
    func toJSONSuitableObject() -> Any {
        return [
            "readyRegistration": (self.readyRegistration as? ServiceWorkerRegistration)?.toJSONSuitableObject(),
            "controller": self.controller?.toJSONSuitableObject()
        ]
    }
}
