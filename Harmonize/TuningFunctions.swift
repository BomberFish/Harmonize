//
//  TuningFunctions.swift
//  Harmonize
//
//  Created by Hariz Shirazi on 2023-02-22.
//

import Foundation
import AudioKit
import AudioKitEX
import AudioKitUI
import AudioToolbox
import SoundpipeAudioKit
import UIKit

struct TunerData {
    var pitch: Float = 0.0
    var amplitude: Float = 0.0
    var noteNameWithSharps = "-"
    var noteNameWithFlats = "-"
    var closeness: Float = 0.0
    var targetPitch: Float = 0.0
}

class PreviewTunerConductor: ObservableObject {
    @Published var data = TunerData()
    init() {
        data.noteNameWithSharps = "E4"
        data.noteNameWithFlats = "E4"
        data.pitch = 329.63
        data.amplitude = 0.9
        data.closeness = 1.0
        data.targetPitch = 329.63
    }
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
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    // FIXME: Oh god.
    let noteFrequenciesFloat: [Float] = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    
    init() {
        guard let input = engine.input else {
            UIApplication.shared.alert(body: "Could not find Input!")
            fatalError("engine.input not found! Are you running in the sim?")
        }

        guard let device = engine.inputDevice else {
            UIApplication.shared.alert(body: "Could not find Input Device!")
            fatalError("engine.inputDevice not found! Are you running in the sim?")
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

func getGuitarString(noteName: String) -> Int {
    if noteName == "E2" {
        return 6
    } else if noteName == "A2" {
        return 5
    } else if noteName == "D3" {
        return 4
    } else if noteName == "G3" {
        return 3
    } else if noteName == "B3" {
        return 2
    } else if noteName == "E4" {
        return 1
    }
    return 0
}
