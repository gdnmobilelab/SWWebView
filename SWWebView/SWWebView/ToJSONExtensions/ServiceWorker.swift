import Foundation
import ServiceWorker

extension ServiceWorker: ToJSON {

    func toJSONSuitableObject() -> Any {
        return [
            "id": self.id,
            "installState": self.state.rawValue,
            "scriptURL": self.url.sWWebviewSuitableAbsoluteString
        ]
    }
}
