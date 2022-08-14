//
//  ContentView.swift
//  Shared
//
//  Created by Kerri Shotts on 2/21/22.
//

import SwiftUI
import CoreData
import MIDIKit
import MIDIKitSMF
import UniformTypeIdentifiers


let MIDI_MANAGER_CLIENT_NAME = "MIDIary"
let MIDI_MANAGER_MODEL = "MIDIary"
let MIDI_MANAGER_MANUFACTURER = "Kerri Shotts"

let MIDI_INPUT_TAG = "Virtual_MIDI_In"
let MIDI_INPUT_NAME = "MIDIary MIDI In"
let MIDI_OUTPUT_TAG = "Virtual_MIDI_Out"
let MIDI_OUTPUT_NAME = "MIDIary MIDI Out"
let MIDI_INPUT_CONNECTION = "InputConnection1"

enum MidiInitStates {
    case none
    case started
    case ready
}


extension String {
    // from https://gist.github.com/totocaster/3a1f008c780793b86a6c4d2d6ae735c4
    func sanitized() -> String {
        // see for ressoning on charachrer sets https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)
        
        return self
            .components(separatedBy: invalidCharacters)
            .joined(separator: "")
    }
}

extension MidiPerformance {
    public override var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        let formattedTimestamp = formatter.string(from: self.timestamp!)
        return "\(formattedTimestamp), \(self.notes) notes"
    }
}

struct MidiFile: FileDocument {
    // tell the system we support only plain text
    static var readableContentTypes = [UTType.midi]

    // by default our document is empty
    var midiData:Data = Data()

    
    // a simple initializer that creates new, empty documents
    init() {
    }
    
    init(data:Data) {
        midiData = data
    }

    // this initializer loads data that has been saved previously
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            midiData = data
        }
    }

    // this will be called when the system wants to write our data to disk
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: midiData)
    }
}

var needToCreateNewPerformance = true
var currentPerformance = MidiPerformance()
var currentTrack=MIDI.File.Chunk.Track()
var timestampOfLastEvent = Date()
//var currentNotes = 0
//var currentNoteOffs = 0
var waitingForFirstEvent = true
var dirty = false
var lastSaveTimestamp = Date()
var documentForExporting = MidiFile()

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MidiPerformance.timestamp, ascending: false)],
        animation: .default)
    private var performances: FetchedResults<MidiPerformance>
    
    let midiManager = MIDI.IO.Manager(
        clientName: MIDI_MANAGER_CLIENT_NAME,
        model: MIDI_MANAGER_MODEL,
        manufacturer: MIDI_MANAGER_MANUFACTURER)
    
    // save recordings every 10s
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    @State var message = ""
    
    @State var thru = true
    @State var listenToAll = true
    
    @State var midiTimeBase = 960
    @State var midiTempo = 120.0
    @State var timeSignatureNumerator = 4
    @State var timeSignatureDenominator = 4
    
    @State var midiState = MidiInitStates.none
    @State var timeBetween = 30
    @State var selection: String? = "home"
    @State var showExportSheet = false
    
    @State var currentNotes = 0
    @State var currentNoteOffs = 0
    
    var body: some View {
        NavigationView {
            List {
                Group {
                    NavigationLink(tag: "home", selection: $selection) {
                        VStack {
                            Text("Select a performance")
                            switch midiState {
                            case .none:
                                Text("Starting MIDI Manager...")
                            case .started:
                                Text("Creating Virtual MIDI Connections...")
                            case .ready:
                                Text("or start playing (Listening for MIDI events)")
                            }
                            Text(message)
                            Text("Current Recording: Notes: \(currentNotes), Off: \(currentNoteOffs), Delta: \(currentNotes - currentNoteOffs)")
                        }.padding()
                            .navigationTitle("MIDIary")
                    } label: { Text("MIDIary") }
                    NavigationLink(tag: "settings", selection: $selection) {
                        Form {
                            Toggle("Thru", isOn: $thru)
                            Toggle("Listen to all MIDI inputs", isOn: $listenToAll)
                            TextField("Break", value: $timeBetween, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }.padding()
                            .navigationTitle("MIDIary Settings")
                    } label: {
                        Text("Settings")
                    }
                }
                Section (header: Text("Performances")) {
                    ForEach(performances) { performance in
                        NavigationLink {
                            VStack {
                                Text(performance.description)
                                Text("Notes: \(performance.notes)")
                                Text("Tempo: \(performance.tempo)")
                                Text("Time Signature: \(performance.timeSigNumerator) / \(performance.timeSigDenominator)")
                            }
                            .navigationTitle(performance.description)
                            .toolbar {
                                ToolbarItem {
                                    Button {
                                        if (performance == currentPerformance && dirty) {
                                            savePerformance()
                                        }
                                        documentForExporting = MidiFile(data: performance.midi!)
                                        showExportSheet = true
                                    } label: {
                                        Label("Export", systemImage: "square.and.arrow.down")
                                    }
                                    .fileExporter(isPresented: $showExportSheet, document: documentForExporting, contentType: .midi, defaultFilename: performance.description.sanitized()) { result in
                                        switch result {
                                        case .success(let url):
                                            print("Saved to \(url)")
                                        case .failure(let error):
                                            print(error.localizedDescription)
                                        }
                                    }
                                }
                                ToolbarItem {
                                    Button(action: addPerformance) {
                                        Label("Play", systemImage: "play")
                                    }
                                }
                                ToolbarItem {
                                    Button {
                                        withAnimation {
                                            viewContext.delete(performance)
                                            do {
                                                try viewContext.save()
                                            } catch {
                                                let nsError = error as NSError
                                                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                                            }
                                        }
                                        selection = "home"
                                    }
                                    label: {
                                        Label("Delete Performance", systemImage: "trash")
                                    }
                                }
                            }
                        } label: {
                            Text(performance.description)
                        }
                        
                    }
                    .onDelete(perform: deletePerformances)
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addPerformance) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear() {
            do {
                try midiManager.start()
                MIDI.IO.setNetworkSession(policy: .anyone)
                midiState = .started
                
            } catch let err {
                message = "Error while starting MIDI manager: \(err)"
            }
        }
        .onDisappear() {
            if (dirty) {
                if (currentNotes > 0) {
                    savePerformance()
                }
            }
        }
        .onReceive(timer) { input in
            if (dirty && currentNotes > 0) {
                savePerformance()
            }
        }
        .onChange(of: midiState) { newState in
            switch newState {
            case .none:
                do {
                    try midiManager.start()
                    MIDI.IO.setNetworkSession(policy: .anyone)
                    midiState = .started
                } catch let err {
                    message = "Error while starting MIDI manager: \(err)"
                }
            case .started:
                do {
                    try midiManager.addInput(
                        name: MIDI_INPUT_NAME,
                        tag: MIDI_INPUT_TAG,
                        uniqueID: .userDefaultsManaged(key: MIDI_INPUT_TAG),
                        receiveHandler: .events { events in
                            let now = Date()
                            DispatchQueue.main.async {
                                events.forEach { receivedMIDIEvent($0, timestamp: now) }
                            }
                        })
                    
                    try midiManager.addOutput(
                        name: MIDI_OUTPUT_NAME,
                        tag: MIDI_OUTPUT_TAG,
                        uniqueID: .userDefaultsManaged(key: MIDI_OUTPUT_TAG)
                    )
                    try midiManager.addInputConnection(
                        toOutputs: .currentOutputs(),
                        tag: MIDI_INPUT_CONNECTION,
                        mode: .allEndpoints,
                        filter: .owned(),
                        //automaticallyAddNewOutputs: true,
                        //preventAddingManagedOutputs: true,
                        receiveHandler: .events { events in
                            if (!listenToAll) { return }
                            let now = Date()
                            DispatchQueue.main.async {
                                events.forEach { receivedMIDIEvent($0, timestamp: now) }
                            }
                        }
                    )
                    
                    midiState = .ready
                } catch let err {
                    message = "Error while adding MIDI connections: \(err)"
                }
            case .ready:
                message = ""
            }
            
        }
    }
    
    private  func receivedMIDIEvent(_ event: MIDI.Event, timestamp: Date) {
        
        if (thru) {
            do {
                let output = midiManager.managedOutputs[MIDI_OUTPUT_TAG];
                try output?.send(event: event);
            }
            catch let err {
                print("Error while thru: \(err)")
            }

        }
        print ("New event", event.description)
        switch event {
        case .noteCC(_):
            fallthrough
        case .noteOff(_):
            fallthrough
        case .notePitchBend(_):
            fallthrough
        case .notePressure(_):
            fallthrough
        case .pitchBend(_):
            fallthrough
        case .pressure(_):
            fallthrough
        case .cc(_):
            fallthrough
        case .noteManagement(_):
            fallthrough
        case .noteOn(_):
            var deltaBetweenEvents = abs(timestampOfLastEvent.timeIntervalSince(timestamp))
            let deltaBetweenSaves = abs(lastSaveTimestamp.timeIntervalSinceNow)
            timestampOfLastEvent = timestamp
            if (needToCreateNewPerformance) {
                addPerformance()
                needToCreateNewPerformance = false
            }
            if (!waitingForFirstEvent) {
                if (deltaBetweenEvents > Double(timeBetween)) {
                    // player paused long enough, start a new performance!
                    if (currentNotes > 0) {
                        savePerformance()
                        addPerformance()
                    }
                }
            }
            switch event {
            case .noteOn(_):
                currentNotes += 1
            case .noteOff(_):
                currentNoteOffs += 1
            default:
                break
            }
            if (waitingForFirstEvent) {
                deltaBetweenEvents = 0
                waitingForFirstEvent = false
            }
            let tickResolution = 60_000_000.0 / currentPerformance.tempo / Double(midiTimeBase)
            let delta = floor((deltaBetweenEvents * 1_000_000) / tickResolution)
            currentTrack.events.append(
                event.smfEvent(delta: .ticks(UInt32(delta)))!)
            dirty = true
            
            print ("Notes: \(currentNotes), Off: \(currentNoteOffs), Delta: \(currentNotes - currentNoteOffs)")
            break
        default:
            // ignore all other events
            break
        }
        
    }
    
    private func savePerformance() {

        // we always want the most up-to-date # of notes so the description is correct
        currentPerformance.notes = Int32(currentNotes)

        var midiFile = MIDI.File();
        midiFile.format = .singleTrack
        midiFile.timeBase = .musical(ticksPerQuarterNote:UInt16(midiTimeBase))
        
        var track = MIDI.File.Chunk.Track()
        track.events = [
            .text(
                delta: .none,
                type: .trackOrSequenceName,
                string: currentPerformance.description.asciiStringLossy
            ),
        ]
        track.events.append(contentsOf: currentTrack.events)
        
        midiFile.chunks = [
            .track(track)
        ]
        
        do {
            try currentPerformance.midi = midiFile.rawData()
            dirty = false
            lastSaveTimestamp = Date()
            print ("Saved \(lastSaveTimestamp)")
        } catch let err {
            print("Error while saving midi file \(err)")
        }

        do {
            try viewContext.save()
        } catch {

            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private  func addPerformance() {
        withAnimation {
            if (dirty) {
                savePerformance()
            }
            let performance = MidiPerformance(context: viewContext)
            performance.timestamp = Date()
            performance.notes = 0
            performance.timeSigDenominator = Int16(timeSignatureDenominator)
            performance.timeSigNumerator = Int16(timeSignatureNumerator)
            performance.tempo = midiTempo
            performance.rating = 0
            
            currentPerformance = performance
            waitingForFirstEvent = true
            timestampOfLastEvent = Date()
            currentTrack = MIDI.File.Chunk.Track()
            currentNotes = 0
            currentNoteOffs = 0
            
            currentTrack.events = [
                //.smpteOffset(delta: .none, hr: 0, min: 0, sec: 0, fr: 0, subFr: 0, frRate: ._2997dfps),
                .timeSignature(
                    delta: .none,
                    numerator: UInt8(timeSignatureNumerator),
                    denominator: UInt8(timeSignatureDenominator >> 1)
                ),
                .tempo(
                    delta: .none,
                    bpm: performance.tempo
                )
            ]

            do {
                try viewContext.save()
            } catch {

                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }


    private func deletePerformances(offsets: IndexSet) {
        withAnimation {
            offsets.map { performances[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    
}
/*
 
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

*/

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
