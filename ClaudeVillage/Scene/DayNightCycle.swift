import SpriteKit

// Day/night cycle logic is embedded in VillageScene.
// This file provides helper utilities for time-based visual effects.

struct DayNightHelper {
    static func currentPeriod() -> DayPeriod {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<8:   return .dawn
        case 8..<17:  return .day
        case 17..<19: return .sunset
        case 19..<22: return .evening
        default:      return .night
        }
    }

    static var isNight: Bool {
        let period = currentPeriod()
        return period == .evening || period == .night
    }
}

enum DayPeriod {
    case dawn, day, sunset, evening, night
}
