import Foundation

class MessagePortAction: ToJSON {

    enum ActionType: String {
        case message
        case close
    }

    let type: ActionType
    let data: Any?
    let id: String
    let portIDs: [String]

    init(type: ActionType, id: String, data: Any?, portIds: [String] = []) {
        self.type = type
        self.data = data
        self.id = id
        self.portIDs = portIds
    }

    func toJSONSuitableObject() -> Any {
        return [
            "type": self.type.rawValue,
            "data": self.data,
            "id": self.id,
            "portIDs": self.portIDs
        ]
    }
}
