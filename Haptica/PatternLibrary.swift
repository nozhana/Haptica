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
            Group {
                if model.recordedPatterns.isEmpty {
                    VStack {
                        Image(systemName: "waveform.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .imageScale(.large)
                        
                        Text("You have no patterns yet. Try recording one.")
                            .font(.title)
                    }
                } else {
                    SelectableList(values: $model.recordedPatterns) { url in
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
            } // Group
            .onAppear(perform: model.populateRecordedPatterns)
            .navigationTitle("Pattern Library")
        } // NavigationStack
        .presentationDetents([.medium, .large])

    }
}

#Preview {
    PatternLibrary()
}
