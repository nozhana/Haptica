//
//  PatternLibrary.swift
//  Haptica
//
//  Created by Nozhan Amiri on 1/1/25.
//

import SwiftUI

struct PatternLibrary: View {
    @EnvironmentObject private var model: HapticRecorder.Observed
    
    var body: some View {
        NavigationStack {
            List {
                let brush = Bundle.main.url(forResource: "Brush", withExtension: "ahap")
                let knock = Bundle.main.url(forResource: "Knock", withExtension: "ahap")
                let rumble = Bundle.main.url(forResource: "Rumble", withExtension: "ahap")
                let slide = Bundle.main.url(forResource: "Slide", withExtension: "ahap")
                
                SelectableList(values: .constant([brush, knock, rumble, slide].compactMap(\.self)), isSection: true, sectionHeader: "Preset patterns") { url in
                    model.loadRecording(url)
                } label: { url in
                    Label(url.lastPathComponent, systemImage: "waveform")
                }

                if model.recordedPatterns.isEmpty {
                    VStack {
                        Image(systemName: "waveform.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .imageScale(.large)
                        
                        Text("You have no patterns yet.\nTry recording one.")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    SelectableList(values: $model.recordedPatterns, isSection: true, sectionHeader: "Recorded patterns") { url in
                        model.loadRecording(url)
                    } onDeleted: { url in
                        Task { @MainActor in
                            model.recordedPatterns.removeAll(where: { $0 == url })
                            try? FileManager.default.removeItem(at: url)
                        }
                    } onRenamed: { url, partialFileName in
                        Task { @MainActor in
                            model.recordedPatterns.replace([url], with: [url.deletingLastPathComponent().appendingPathComponent(partialFileName + ".ahap")])
                            try? FileManager.default.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(partialFileName + ".ahap"))
                        }
                    } label: { url in
                        Label(url.lastPathComponent, systemImage: "waveform")
                    }
                } // if/else
            } // List
            .onAppear(perform: model.populateRecordedPatterns)
            .navigationTitle("Pattern Library")
        } // NavigationStack
        .presentationDetents([.medium, .large])

    }
}

#Preview {
    PatternLibrary()
}
