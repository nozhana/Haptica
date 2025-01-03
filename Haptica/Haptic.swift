//
//  Haptic.swift
//  StoryKit
//
//  Created by Nozhan Amiri on 12/17/24.
//

import AVFAudio
import Foundation
import CoreHaptics
import class UIKit.UIImpactFeedbackGenerator
import class UIKit.UISelectionFeedbackGenerator

final class Haptic {
    /// Singleton
    static let shared = Haptic()
    
    // MARK: - Properties
    private let audioSession = AVAudioSession.sharedInstance()
    private var engine: CHHapticEngine? {
        didSet {
            guard let engine else { return }
//            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.notifyWhenPlayersFinished(finishedHandler: playerDidFinish(withError:))
            engine.stoppedHandler = engineDidStop(withReason:)
            engine.resetHandler = engineDidRecoverFromServerError
        }
    }
    
    private var player: CHHapticPatternPlayer?
    
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    
    // MARK: - Initialization
    private init() {
        do {
            engine = try CHHapticEngine(audioSession: audioSession)
        } catch {
            print("Failed to start haptic engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Player
    private func playerDidFinish(withError error: Error?) -> CHHapticEngine.FinishedAction {
        print("All players finished playing. Stopping engine...")
        if let error {
            print("Player finished with error: \(error)")
        }
        self.player = nil
        return .stopEngine
    }
    
    // MARK: - Engine
    private func engineDidStop(withReason reason: CHHapticEngine.StoppedReason) {
        print("Engine stopped with reason: \(reason)")
    }
    
    private func engineDidRecoverFromServerError() {
        print("Engine reset.")
        prepare()
    }
    
    // MARK: Engine(Public)
    func prepare() {
        do {
            try engine?.start()
        } catch {
            print("Failed to start haptic engine: \(error.localizedDescription)")
        }
    }
    
    func stopEngine() {
        engine?.stop { error in
            guard let error else { return }
            print("Failed to stop haptic engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Haptics
    private func playImpactHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle? = nil, intensity: CGFloat? = nil) {
        let generator: UIImpactFeedbackGenerator
        if let style {
            generator = .init(style: style)
        } else {
            generator = .init()
        }
        
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
    }
    
    private func playSelectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    private func playAlignmentHaptic(magnitude: Double) {
        guard let engine else { return }
        try? engine.start()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(magnitude))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
        let attack = CHHapticEventParameter(parameterID: .attackTime, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness, attack], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play alignment haptic: \(error.localizedDescription)")
        }
    }
    
    private func playWarningHaptic(magnitude: Double, duration: TimeInterval) {
        guard let engine else { return }
        try? engine.start()
        
        var events = [CHHapticEvent]()
        
        for i in stride(from: 0, to: duration, by: 0.1) {
            let value = Float((1 - i / duration) * magnitude.clamped(to: 0...1))
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: value)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: value)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: i)
            events.append(event)
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play warning haptic: \(error.localizedDescription)")
        }
    }
    
    private func playRollAwayHaptic(magnitude: Double, duration: TimeInterval) {
        guard let engine else { return }
        try? engine.start()
        
        var events = [CHHapticEvent]()
        
        var relativeTimeInverse = duration
        
        while relativeTimeInverse > 0.1 {
            let value = (relativeTimeInverse * magnitude).clamped(to: 0...1)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(value))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(value))
            let attack = CHHapticEventParameter(parameterID: .attackTime, value: Float(value / 2))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness, attack], relativeTime: duration - relativeTimeInverse)
            events.append(event)
            relativeTimeInverse /= 1.3
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            
//            if let dic = try? pattern.exportDictionary() {
//                print("Pattern Dictionary")
//                print(dic)
//                
//                if JSONSerialization.isValidJSONObject(dic),
//                   let data = try? JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted),
//                   let json = String(data: data, encoding: .utf8) {
//                    print("Pattern JSON String:")
//                    print(json)
//                    
//                    if let jsonData = json.data(using: .utf8),
//                       let jsonObj = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String: Any] {
//                        let patternDictionary = jsonObj
//                            .mapKeys { CHHapticPattern.Key(rawValue: $0) }
//                        let decodedPattern = try? CHHapticPattern(dictionary: patternDictionary)
//                        print("Decoded pattern: \(try? decodedPattern?.exportDictionary())")
//                    }
//                }
//            }
            
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play roll away haptic: \(error.localizedDescription)")
        }
    }
    
    private func playLevelChangeHaptic(level: Double) {
        guard let engine else { return }
        try? engine.start()
        
        let parameterValue = level.clamped(to: 0...1) * 0.7 + 0.2
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(parameterValue))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(parameterValue))
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play level change haptic: \(error.localizedDescription)")
        }
    }
    
    private func playTickHaptic(intensity i: Double, sharpness s: Double) {
        guard let engine else { return }
        try? engine.start()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(i))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(s))
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play tick haptic: \(error.localizedDescription)")
        }
    }
    
    private func playTicksHaptic(ticks: [Tick]) {
        guard let engine else { return }
        try? engine.start()
        
        var events = [CHHapticEvent]()
        
        ticks.forEach { tick in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(tick.intensity).clamped(to: 0...1))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(tick.sharpness).clamped(to: 0...1))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: tick.relativeTime)
            events.append(event)
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play ticks haptic: \(error.localizedDescription)")
        }
    }
    
    private func playHapticFromFile(url: URL) {
        guard let engine else { return }
        try? engine.start()
        
        do {
            let pattern = try CHHapticPattern(contentsOf: url)
            self.player = try engine.makePlayer(with: pattern)
            try player!.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to play haptic from file: \(error.localizedDescription)")
        }
    }
    
    func saveHapticToFile(pattern: CHHapticPattern) throws -> URL {
        let dictionary = try pattern.exportDictionary()
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let id = UUID()
        let url = URL.hapticsDirectory.appendingPathComponent("\(id.uuidString).ahap")
        try data.write(to: url)
        return url
    }
    
    func play(_ feedback: Feedback) {
        switch feedback {
        case .impact(let style, let intensity):
            playImpactHaptic(style: style, intensity: intensity)
        case .selection:
            playSelectionHaptic()
        case .alignment(let magnitude):
            playAlignmentHaptic(magnitude: magnitude)
        case .warning(let magnitude, let duration):
            playWarningHaptic(magnitude: magnitude, duration: duration)
        case .rollAway(let magnitude, let duration):
            playRollAwayHaptic(magnitude: magnitude, duration: duration)
        case .levelChange(let level):
            playLevelChangeHaptic(level: level)
        case .tick(let intensity, let sharpness):
            playTickHaptic(intensity: intensity, sharpness: sharpness)
        case .ticks(let ticks):
            playTicksHaptic(ticks: ticks)
        case .file(let url):
            playHapticFromFile(url: url)
        }
    }
}

extension Haptic {
    enum Feedback {
        case impact(style: UIImpactFeedbackGenerator.FeedbackStyle? = nil, intensity: CGFloat? = nil)
        case selection
        case alignment(magnitude: Double = 0.75)
        case warning(magnitude: Double = 1, duration: TimeInterval = 1)
        case rollAway(magnitude: Double = 1, duration: TimeInterval = 1.5)
        case levelChange(level: Double = 0.5)
        case tick(intensity: Double, sharpness: Double)
        case ticks(ticks: [Tick])
        case file(url: URL)
    }
}

extension URL {
    static var hapticsDirectory: URL = {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? .documentsDirectory
        url.append(component: "haptics", directoryHint: .isDirectory)
        
        if FileManager.default.fileExists(atPath: url.path()) {
            return url
        }
        
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("Failed to create hapticsDirectory")
        }
        
        return url
    }()
}

extension Haptic {
    struct Tick {
        let intensity: Double
        let sharpness: Double
        let relativeTime: TimeInterval
    }
}
