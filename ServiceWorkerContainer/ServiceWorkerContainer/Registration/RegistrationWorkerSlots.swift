//
//  RegistrationWorkerSlots.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 29/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

enum RegistrationWorkerSlot: String {
    case active
    case waiting
    case installing
    case redundant
}
