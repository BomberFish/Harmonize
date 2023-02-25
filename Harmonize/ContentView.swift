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

struct ContentView: View {
    #if targetEnvironment(simulator)
        @StateObject var conductor = PreviewTunerConductor()
    #else
        @StateObject var conductor = TunerConductor()
    #endif
    @State var A442 = false
    @State public var previewMode = false
    let appVersion = ((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") + " (" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown") + ")")
    var body: some View {
        NavigationView {
            List {
                #if targetEnvironment(simulator)
                Section {
                    HStack {
                        Spacer()
                        Text("! Preview Mode !")
                            .foregroundColor(Color(UIColor.red))
                            .font(.system(size: 21, weight: .semibold, design: .monospaced))
                        Spacer()
                    }
                }
                #endif
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
                    Text("Guitar String: \(getGuitarString(noteName: conductor.data.noteNameWithSharps))")
                }
                
                Section {
                    #if targetEnvironment(simulator)
                    Text("InputDevicePicker not shown - in preview mode")
                    #else
                    NodeOutputView(conductor.tappableNodeA).clipped()
                    #endif
                    
                } header: {
                    Label("Graph", systemImage: "waveform.path")
                }
                
                Section {
                    #if targetEnvironment(simulator)
                    Text("InputDevicePicker not shown - in preview mode")
                    #else
                    InputDevicePicker(device: conductor.initialDevice)
                    #endif
                } header: {
                    Label("Options", systemImage: "wrench.and.screwdriver")
                }
                Section {
                    Text("targetPitch: \(conductor.data.targetPitch)")
                        .textSelection(.enabled)
                    Text("closeness: \(conductor.data.closeness)")
                        .textSelection(.enabled)
                } header: {
                    Label("Debug - Here be Dragons!", systemImage: "ladybug")
                    
                }
            }
            #if targetEnvironment(simulator)
            .onAppear{
                    UIApplication.shared.alert(title: "Warning" ,body: "iPhone Simulator and/or Xcode Preview detected! Some features may be limited.")
                previewMode = true
            }
            #else
            .onAppear {
                conductor.start()
            }
            .onDisappear {
                conductor.stop()
            }
            #endif
            .navigationTitle("Harmonize")
            .toolbar {
                Button(
                    action: {
                        UIApplication.shared.alert(title: "Harmonize",body: "Version \(appVersion)\nMade with ❤️ by BomberFish")
                    }, label: {
                        Image(systemName: "info")
                    })
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
}
