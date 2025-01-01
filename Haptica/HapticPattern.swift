//
//  HapticPattern.swift
//  Haptica
//
//  Created by Nozhan Amiri on 12/31/24.
//

import Foundation

struct HapticPattern: Codable {
    let pattern: [HapticPatternItem]
    
    enum CodingKeys: String, CodingKey {
        case pattern = "Pattern"
    }
}

struct HapticPatternItem: Codable {
    let event: HapticEvent?
    let parameterCurve: HapticParameterCurve?
    
    enum CodingKeys: String, CodingKey {
        case event = "Event"
        case parameterCurve = "ParameterCurve"
    }
}

struct HapticEvent: Codable {
    enum EventType: String, Codable {
        case transient = "HapticTransient"
        case continuous = "HapticContinuous"
    }
    
    let time: TimeInterval
    let eventType: EventType
    let duration: TimeInterval?
    let eventParameters: [HapticEventParameter]
    
    enum CodingKeys: String, CodingKey {
        case time = "Time"
        case eventType = "EventType"
        case duration = "Duration"
        case eventParameters = "EventParameter"
    }
}

struct HapticEventParameter: Codable {
    enum ParameterID: String, Codable {
        case intensity = "HapticIntensity"
        case sharpness = "HapticSharpness"
    }
    
    let parameterID: ParameterID
    let parameterValue: Double
    
    enum CodingKeys: String, CodingKey {
        case parameterID = "ParameterID"
        case parameterValue = "ParameterValue"
    }
}

struct HapticParameterCurve: Codable {
    enum ParameterID: String, Codable {
        case intensityControl = "HapticIntensityControl"
        case sharpnessControl = "HapticSharpnessControl"
    }
    
    let parameterID: ParameterID
    let time: TimeInterval
    let parameterCurveControlPoints: [HapticParameterCurveControlPoint]
    
    enum CodingKeys: String, CodingKey {
        case parameterID = "ParameterID"
        case time = "Time"
        case parameterCurveControlPoints = "ParameterCurveControlPoints"
    }
}

struct HapticParameterCurveControlPoint: Codable {
    let time: Double
    let parameterValue: Double
    
    enum CodingKeys: String, CodingKey {
        case time = "Time"
        case parameterValue = "ParameterValue"
    }
}
