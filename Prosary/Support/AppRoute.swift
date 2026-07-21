//
//  AppRoute.swift
//  Prosary
//

import Foundation

enum AppRoute: Hashable {
    case rosary(configId: RosaryConfig.ID)
    case presets
    case about
}
