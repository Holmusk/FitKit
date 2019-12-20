//
// Created by Martin Anderson on 2019-03-10.
//

import HealthKit

extension String: LocalizedError {
    public var errorDescription: String? {
        return self
    }
}

extension HKSampleType {
    public static func fromDartType(type: String) throws -> HKSampleType {
        guard let sampleType: HKSampleType = {
            switch type {
            case "heart_rate":
                return HKSampleType.quantityType(forIdentifier: .heartRate)
            case "step_count":
                return HKSampleType.quantityType(forIdentifier: .stepCount)
            case "height":
                return HKSampleType.quantityType(forIdentifier: .height)
            case "weight":
                return HKSampleType.quantityType(forIdentifier: .bodyMass)
            case "distance":
                return HKSampleType.quantityType(forIdentifier: .distanceWalkingRunning)
            case "energy":
                return HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)
            case "water":
                if #available(iOS 9, *) {
                    return HKSampleType.quantityType(forIdentifier: .dietaryWater)
                } else {
                    return nil
                }
            case "sleep":
                return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)
                case "active_minutes":
                if #available(iOS 9.3, *) {
                return HKSampleType.quantityType(forIdentifier: .appleExerciseTime)
                } else {
                    return nil
                }
            case "body_fat":
                return HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)
            case "meditation":
                if #available(iOS 10, *) {
                return HKSampleType.categoryType(forIdentifier: .mindfulSession)
                } else {
                    return nil
                }           
            default:
                return nil
            }
        }() else {
            throw "type \"\(type)\" is not supported";
        }
        return sampleType
    }
}

extension HKUnit {
    public static func fromDartType(type: String) throws -> HKUnit {
        guard let unit: HKUnit = {
            switch (type) {
            case "heart_rate":
                return HKUnit.init(from: "count/min")
            case "step_count":
                return HKUnit.count()
            case "height":
                return HKUnit.meter()
            case "weight":
                return HKUnit.gramUnit(with: .kilo)
            case "distance":
                return HKUnit.meter()
            case "energy":
                return HKUnit.kilocalorie()
            case "water":
                return HKUnit.liter()
            case "sleep":
                return HKUnit.minute() // this is ignored
            case "active_minutes":
                return HKUnit.minute()
            case "body_fat":
                return HKUnit.percent()
            case "meditation":
                return HKUnit.minute()
            default:
                return nil
            }
        }() else {
            throw "type \"\(type)\" is not supported";
        }
        return unit
    }
}