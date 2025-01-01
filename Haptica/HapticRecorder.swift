//
//  HapticRecorder.swift
//  Stories
//
//  Created by Nozhan Amiri on 12/28/24.
//

import CoreHaptics
import Combine
import SwiftUI

struct HapticRecorder: View {
    @StateObject private var model = Observed()
    
    private func locationUnit(for point: CGPoint, in size: CGSize) -> UnitPoint {
        .init(x: point.x / size.width, y: point.y / size.height)
    }
    
    private func point(for unit: UnitPoint, in size: CGSize) -> CGPoint {
        .init(x: unit.x * size.width, y: unit.y * size.height)
    }
    
    private func touchCanvas(in size: CGSize) -> some View {
        let image = Image(systemName: "circle.fill")
        
        return TimelineView(.animation(minimumInterval: 0.01)) { timeline in
            Canvas { context, canvas in
                Task { @MainActor in
                    model.update(withDate: timeline.date)
                }
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                context.blendMode = .plusLighter
                context.addFilter(.blur(radius: 4))
                
                for touchItem in model.touchItems {
                    var contextCopy = context
                    
                    let touchDate = touchItem.creationDate.timeIntervalSinceReferenceDate
                    if model.isPlaybackInProgress {
                        if model.runningTime < touchItem.time {
                            contextCopy.opacity = 0
                        } else {
                            contextCopy.opacity = (1 - (model.runningTime - touchItem.time)).clamped(to: 0...1)
                        }
                    } else {
                        contextCopy.opacity = (1 - (now - touchDate)).clamped(to: 0...1)
                    }
                    
                    let hue = (touchItem.locationUnit.x + (1 - touchItem.locationUnit.y)) / 2
                    contextCopy.addFilter(.colorMultiply(Color(hue: hue, saturation: 1, brightness: 1)))
                    contextCopy.draw(image, at: point(for: touchItem.locationUnit, in: canvas))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        model.registerTouch(locationUnit: locationUnit(for: value.location, in: size), date: timeline.date)
                    }
            )
        }
    }
    
    @ViewBuilder
    private var recordButton: some View {
        if !model.isPlaybackInProgress {
            Button {
                if model.isRecording {
                    model.stopRecording()
                } else {
                    model.startRecording()
                }
            } label: {
                Image(systemName: model.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .imageScale(.large)
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.smooth, value: model.mode)
            } // Button/label
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var playbackButton: some View {
        if model.isReadyForPlayback || model.isPlaybackInProgress {
            Button {
                if model.isPlaybackInProgress {
                    model.stopPlayback()
                } else if model.isReadyForPlayback {
                    model.startPlayback()
                }
            } label: {
                Image(systemName: model.isPlaybackInProgress ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .imageScale(.large)
                    .foregroundStyle(.blue)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.smooth, value: model.mode)
            } // Button/label
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var resetButton: some View {
        if case .readyForPlayback = model.mode {
            Button(role: .destructive) {
                model.reset()
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .imageScale(.large)
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var showRecordingsButton: some View {
        Button {
            model.isShowingRecordings = true
        } label: {
            Image(systemName: "list.bullet.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .imageScale(.large)
                .foregroundStyle(.teal)
                .transition(.scale.combined(with: .opacity))
        }

    }
    
    @ViewBuilder
    private var caption: some View {
        switch model.mode {
        case .readyForPlayback(let url),
                .playbackInProgress(let url):
            let partialName = String(url.lastPathComponent.dropLast(5))
            if UUID(uuidString: partialName) != nil {
                EmptyView()
            } else {
                Label(url.lastPathComponent, systemImage: "waveform")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
        default:
            EmptyView()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                touchCanvas(in: geometry.size)
                    .background(.black)
                
                VStack {
                    caption
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        recordButton
                        
                        Group {
                            playbackButton
                            resetButton
                        } // Group
                        .transition(.scale.combined(with: .opacity))
                        
                        showRecordingsButton
                    } // HStack
                } // VStack
                .padding(.horizontal, 16)
                .padding(.bottom, 44)
            } // ZStack
        } // GeometryReader
        .ignoresSafeArea()
        .sheet(isPresented: $model.isShowingRecordings) {
            PatternLibrary()
                .environmentObject(model)
        }
    }
}

#Preview {
    HapticRecorder()
}

extension HapticRecorder {
    final class Observed: ObservableObject {
        struct TouchItem: Identifiable, Hashable {
            let locationUnit: UnitPoint
            let creationDate: Date
            let time: TimeInterval
            
            var id: Int { hashValue }
        }
        
        enum ViewMode: Equatable {
            case idle
            case recording(startDate: Date)
            case readyForPlayback(url: URL)
            case playbackInProgress(url: URL)
            case loading
        }
        
        enum DropState {
            case idle
            case valid
            case invalid
        }
        
        @Published private(set) var touchItems: [TouchItem] = []
        @Published private(set) var mode = ViewMode.idle
        @Published var recordedPatterns: [URL] = []
        @Published var isShowingRecordings = false
        
        var isIdle: Bool {
            mode == .idle
        }
        
        var isLoading: Bool {
            mode == .loading
        }
        
        var isRecording: Bool {
            switch mode {
            case .recording: true
            default: false
            }
        }
        
        var isReadyForPlayback: Bool {
            switch mode {
            case .readyForPlayback: true
            default: false
            }
        }
        
        var isPlaybackInProgress: Bool {
            switch mode {
            case .playbackInProgress: true
            default: false
            }
        }

        private(set) var recordedTouchItems: [TouchItem] = []
        
        private var timer: Timer?
        
        private(set) var runningTime: Double = 0
        
        private var recordingSubscriber: AnyCancellable?
        
        func registerTouch(locationUnit: UnitPoint, date: Date) {
            guard isIdle || isRecording || isReadyForPlayback else { return }
            let touch = TouchItem(locationUnit: locationUnit, creationDate: date, time: runningTime)
            touchItems.append(touch)
            Haptic.shared.play(.tick(intensity: locationUnit.x, sharpness: 1 - locationUnit.y))
        }
        
        func update(withDate date: Date) {
            if isPlaybackInProgress {
                touchItems = touchItems.filter {
                    $0.time > runningTime - 1
                }
            } else {
                touchItems = touchItems.filter {
                    $0.creationDate.timeIntervalSinceReferenceDate > date.timeIntervalSinceReferenceDate - 1
                }
            }
        }
        
        func loadRecording(_ url: URL) {
            guard let data = FileManager.default.contents(atPath: url.path()),
            let dictionary = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.mapKeys(CHHapticPattern.Key.init),
            let pattern = try? CHHapticPattern(dictionary: dictionary) else { return }
            
            let touchItems = touchItems(for: pattern)
            guard !touchItems.isEmpty else { return }
            
            Task { @MainActor in
                self.recordedTouchItems = touchItems
                self.mode = .readyForPlayback(url: url)
                self.isShowingRecordings = false
            }
        }
        
        func populateRecordedPatterns() {
            guard var urls = try? FileManager.default.contentsOfDirectory(atPath: URL.hapticsDirectory.path())
                .map(URL.hapticsDirectory.appendingPathComponent) else {
                return
            }
            
            urls.removeAll { url in
                do {
                    _ = try CHHapticPattern(contentsOf: url)
                    return false
                } catch {
                    try? FileManager.default.removeItem(at: url)
                    return true
                }
            }
            
            urls.removeDuplicates()
            
            Task { @MainActor in
                recordedPatterns = urls
            }
        }
        
        @MainActor func reset() {
            recordingSubscriber?.cancel()
            recordingSubscriber = nil
            stopTimer()
            touchItems.removeAll()
            recordedTouchItems.removeAll()
            mode = .idle
        }
        
        @MainActor func startRecording() {
            reset()
            recordingSubscriber = $touchItems
                .receive(on: DispatchQueue.main)
                .sink { items in
                    let subtraction = items.filter { item in
                        !self.recordedTouchItems.contains(item)
                    }
                    
                    Task { @MainActor in
                        self.recordedTouchItems.append(contentsOf: subtraction)
                        self.recordedTouchItems.removeDuplicates()
                        self.recordedTouchItems.sort(using: KeyPathComparator(\.creationDate))
                    }
                }
            
            startRecordingTimer()
            mode = .recording(startDate: .now)
        }
        
        @MainActor func stopRecording() {
            recordingSubscriber?.cancel()
            recordingSubscriber = nil
            
            stopTimer()
            mode = .loading
            
            let events = recordedTouchItems.map { item in
                let intensityValue = Float(item.locationUnit.x).clamped(to: 0...1)
                let sharpnessValue = Float(1 - item.locationUnit.y).clamped(to: 0...1)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessValue)
                // TODO: Support continuous haptic
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: relativeTimeForRecordedItems(of: item.creationDate))
                return event
            }
            
            do {
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let url = try Haptic.shared.saveHapticToFile(pattern: pattern)
                
                mode = .readyForPlayback(url: url)
            } catch {
                print("Failed to save haptic.")
                mode = .idle
            }
        }
        
        @MainActor func startPlayback() {
            guard case .readyForPlayback(let url) = mode else {
                return
            }
            
            mode = .playbackInProgress(url: url)
            startPlaybackTimer()
        }
        
        @MainActor func stopPlayback() {
            guard case .playbackInProgress(let url) = mode else {
                return
            }
            stopTimer()
            mode = .readyForPlayback(url: url)
        }
        
        private func startRecordingTimer() {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: true, block: recordingBlock(timer:))
            timer!.fire()
        }
        
        private func stopTimer() {
            timer?.invalidate()
            timer = nil
            Task { @MainActor in
                runningTime = 0
            }
        }
        
        private func recordingBlock(timer: Timer) {
            Task { @MainActor in
                if runningTime > 10 {
                    stopRecording()
                    return
                }
                runningTime += 0.01
            }
        }
        
        private func startPlaybackTimer() {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: true, block: playbackBlock(timer:))
            timer!.fire()
        }
        
        private func playbackBlock(timer: Timer) {
            let maximum = recordedTouchItems.map(\.time).max() ?? 10
            let minimum = recordedTouchItems.map(\.time).min() ?? 0
            
            if runningTime.between(lhs: minimum, rhs: minimum + 0.01),
               case .playbackInProgress(let url) = mode {
                Haptic.shared.play(.file(url: url))
            }
            
            if runningTime > maximum + 1 {
                Task { @MainActor in
                    stopPlayback()
                }
                return
            }
            runningTime += 0.01
            
            let touches = recordedTouchItems.filter { $0.time.between(lhs: runningTime - 0.005, rhs: runningTime + 0.005) }
            Task { @MainActor in
                touchItems.append(contentsOf: touches)
            }
        }
        
        private func relativeTimeForRecordedItems(of date: Date) -> TimeInterval {
            let minDate = self.recordedTouchItems.map(\.creationDate).min() ?? .now
            return date.timeIntervalSinceReferenceDate - minDate.timeIntervalSinceReferenceDate
        }
        
        private func pattern(from touchItems: [TouchItem]) throws -> CHHapticPattern {
            let events = touchItems.map { item in
                let intensityValue = Float(item.locationUnit.x).clamped(to: 0...1)
                let sharpnessValue = Float(1 - item.locationUnit.y).clamped(to: 0...1)
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessValue)
                // TODO: Support continuous haptic
                let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: relativeTimeForRecordedItems(of: item.creationDate))
                return event
            }
            
            return try CHHapticPattern(events: events, parameters: [])
        }
        
        private func touchItems(for pattern: CHHapticPattern) -> [TouchItem] {
            guard let dictionary = try? pattern.exportDictionary(),
                  let items = dictionary[.pattern] as? [[CHHapticPattern.Key: Any]] else {
                print("Failed to decode pattern")
                return []
            }
            
            let events = items.filter({ $0.contains(where: { $0.key == .event })})
                .flatMap(\.values).compactMap { $0 as? [CHHapticPattern.Key: Any] }
            
            let baseCreationDate = Date.now
            
            let touchItems: [TouchItem] = events.compactMap { event in
                guard let time = event[.time] as? Double,
                      let parameters = event[.eventParameters] as? [[CHHapticPattern.Key: Any]],
                      let intensity = parameters.first(where: { dic in
                          dic[.parameterID] as? String == "HapticIntensity"
                      })?[.parameterValue] as? Double,
                      let sharpness = parameters.first(where: { dic in
                          dic[.parameterID] as? String == "HapticSharpness"
                      })?[.parameterValue] as? Double else {
                    print("Failed to decode pattern")
                    return nil
                }
                let roundedTime = (time * 100).rounded() / 100
                let roundedIntensity = (intensity * 1000).rounded() / 1000
                let roundedSharpness = (sharpness * 1000).rounded() / 1000
                let creationDate = baseCreationDate + roundedTime
                
                let touchItem = TouchItem(locationUnit: .init(x: roundedIntensity, y: 1 - roundedSharpness), creationDate: creationDate, time: roundedTime)
                
                return touchItem
            }
            
            return touchItems
        }
    }
}

extension Sequence where Element: Equatable {
    var duplicatesRemoved: [Element] {
        reduce(into: []) { partialResult, element in
            if partialResult.contains(element) { return }
            partialResult.append(element)
        }
    }
}

extension Array where Element: Equatable {
    mutating func removeDuplicates() {
        self = duplicatesRemoved
    }
}

extension Array where Element: Equatable {
    mutating func removeAllOccurrences(of element: Element) {
        removeAll(where: { $0 == element })
    }
}
