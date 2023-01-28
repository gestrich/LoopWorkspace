//
//  BolusNightscoutTreatment.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 1/7/23.
//

import Foundation
import NightscoutUploadKit
import HealthKit

extension BolusNightscoutTreatment {
    func graphItem(egvValues: [GraphItem], displayUnit: HKUnit) -> GraphItem {
        let relativeEgvValue = interpolateEGVValue(egvs: egvValues, atDate: timestamp)
        return GraphItem(type: .bolus(self), displayTime: timestamp, quantity: HKQuantity(unit: displayUnit, doubleValue: relativeEgvValue), displayUnit: displayUnit)
    }
}

extension BolusNightscoutTreatment: Equatable {
    public static func == (lhs: NightscoutUploadKit.BolusNightscoutTreatment, rhs: NightscoutUploadKit.BolusNightscoutTreatment) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
        lhs.duration == rhs.duration &&
        lhs.amount == rhs.amount
    }
}
