//
//  MessagePortAction.swift
//  SWWebView
//
//  Created by alastair.coote on 20/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

class MessagePortAction: ToJSON {

    enum ActionType: String {
        case message
        case close
    }

    let type: ActionType
    let data: Any?
    let id: String

    init(type: ActionType, id: String, data: Any?) {
        self.type = type
        self.data = data
        self.id = id
    }

    func toJSONSuitableObject() -> Any {
        return [
            "type": self.type.rawValue,
            "data": self.data,
            "id": self.id
        ]
    }
}
