//
//  AppRoute.swift
//  Prosary
//

import Foundation

enum AppRoute: Hashable {
    case rosary(configId: RosaryConfig.ID)
    case presets
    case about
    case angelus
    case jesusPrayerSetup
    case jesusPrayer(target: JesusPrayerTarget)
}
