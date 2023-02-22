//
//  ContentView.swift
//  Harmonize
//
//  Created by Hariz Shirazi on 2023-02-21.
//

import AudioKit
import AudioKitEX
import AudioKitUI
import AudioToolbox
import SoundpipeAudioKit
import SwiftUI

struct TunerData {
    var pitch: Float = 0.0
    var amplitude: Float = 0.0
    var noteNameWithSharps = "-"
    var noteNameWithFlats = "-"
    var closeness: Float = 1.0
    var targetPitch: Float = 0.0
}

class TunerConductor: ObservableObject, HasAudioEngine {
    @Published var data = TunerData()

    let engine = AudioEngine()
    let initialDevice: Device

    let mic: AudioEngine.InputNode
    let tappableNodeA: Fader
    let tappableNodeB: Fader
    let tappableNodeC: Fader
    let silence: Fader

    var tracker: PitchTap!

    let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    // FIXME: Oh god.
    let noteFrequenciesFloat: [Float] = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    
    init() {
        guard let input = engine.input else {
            UIApplication.shared.alert(body: "Could not find Input!")
            preconditionFailure("Could not find Input!")
        }

        guard let device = engine.inputDevice else {
            UIApplication.shared.alert(body: "Could not find Input Device!")
            preconditionFailure("Could not find Input Device!")
        }

        initialDevice = device

        mic = input
        tappableNodeA = Fader(mic)
        tappableNodeB = Fader(tappableNodeA)
        tappableNodeC = Fader(tappableNodeB)
        silence = Fader(tappableNodeC, gain: 0)
        engine.output = silence

        tracker = PitchTap(mic) { pitch, amp in
            DispatchQueue.main.async {
                self.update(pitch[0], amp[0])
            }
        }
        tracker.start()
    }

    func update(_ pitch: AUValue, _ amp: AUValue) {
        // Reduces sensitivity to background noise to prevent random / fluctuating data.
        guard amp > 0.1 else { return }

        data.pitch = pitch
        data.amplitude = amp

        var frequency = pitch
        while frequency > Float(noteFrequencies[noteFrequencies.count - 1]) {
            frequency /= 2.0
        }
        while frequency < Float(noteFrequencies[0]) {
            frequency *= 2.0
        }

        var minDistance: Float = 10000.0
        var index = 0

        for possibleIndex in 0 ..< noteFrequencies.count {
            let distance = fabsf(Float(noteFrequencies[possibleIndex]) - frequency)
            if distance < minDistance {
                index = possibleIndex
                minDistance = distance
            }
        }
        let octave = Int(log2f(pitch / frequency))
        data.noteNameWithSharps = "\(noteNamesWithSharps[index])\(octave)"
        data.noteNameWithFlats = "\(noteNamesWithFlats[index])\(octave)"
        var pitchFloat = Float(pitch)
        var currentTargetPitch: Float = Float(noteFrequenciesFloat.min(by: { abs($0 - pitchFloat) < abs($1 - pitchFloat) })!) * Float(octave + 1)
        data.targetPitch = currentTargetPitch
        data.closeness = Float(pitch) / currentTargetPitch
    }
}

struct ContentView: View {
    @StateObject var conductor = TunerConductor()
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("\(conductor.data.noteNameWithSharps) / \(conductor.data.noteNameWithFlats)")
                } header: {
                    Label("Note", systemImage: "music.quarternote.3")
                }
                Section {
                    Text("\(conductor.data.pitch, specifier: "%0.1f")")
                } header: {
                    Label("Frequency", systemImage: "waveform")
                }
                Section {
                    InputDevicePicker(device: conductor.initialDevice)
                } header: {
                    Label("Options", systemImage: "wrench.and.screwdriver")
                }
                Section {
                    Text("targetPitch: \(conductor.data.targetPitch)")
                    Text("closeness: \(conductor.data.closeness)")
                } header: {
                    Label("Debug - Here be Dragons!", systemImage: "ladybug")
                    
                }
                Section {
                    NodeOutputView(conductor.tappableNodeA).clipped()
                } header: {
                    Label("Graph", systemImage: "waveform.path")
                }
            }
            .onAppear {
                conductor.start()
            }
            .onDisappear {
                conductor.stop()
            }
            .navigationTitle("Harmonize")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct InputDevicePicker: View {
    @State var device: Device

    var body: some View {
        Picker("Input: \(device.deviceID)", selection: $device) {
            ForEach(getDevices(), id: \.self) {
                Text($0.deviceID)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: device, perform: setInputDevice)
    }

    func getDevices() -> [Device] {
        AudioEngine.inputDevices.compactMap { $0 }
    }

    func setInputDevice(to device: Device) {
        do {
            try AudioEngine.setInputDevice(device)
        } catch let err {
            print(err)
        }
    }
}
