import Cocoa
import MIDIKit
import MIDIKitSMF

var greeting = "Hello, playground"
var thru = true;
var path = "/Users/kerrishotts/Downloads/test.mid"

var midiFile = MIDI.File()
midiFile.format = .singleTrack
midiFile.timeBase = .musical(ticksPerQuarterNote: 960)

var track = MIDI.File.Chunk.Track()
track.events = [
    .text(delta: .none, type: .trackOrSequenceName, string: "MIDIary recording"),
    .smpteOffset(delta: .none, hr: 0, min: 0, sec: 0, fr: 0, subFr: 0, frRate: ._2997dfps),
    .timeSignature(delta: .none, numerator: 4, denominator: 4),
    .tempo(delta: .none, bpm: 120.0),
]

midiFile.chunks = [
    .track(track)
]


let midiManager = MIDI.IO.Manager(
    clientName: "MyAppMIDIManager",
    model: "MyApp",
    manufacturer: "MyCompany"
)

do {
    try midiManager.start()
} catch let err {
    print("Error while starting MIDI manager: \(err)")
}

MIDI.IO.setNetworkSession(policy: .anyone)

let inputTag = "Virtual_MIDI_In"

try midiManager.addInput(
    name: "Diary MIDI In",
    tag: inputTag,
    uniqueID: .userDefaultsManaged(key: inputTag),
    receiveHandler: .events { events in
        // Note: this handler will be called on a background thread
        // so call the next line on main if it may result in UI updates
        DispatchQueue.main.async {
            events.forEach { receivedMIDIEvent($0) }
        }
    }
)

let outputTag = "Virtual_MIDI_Out"

try midiManager.addOutput(
    name: "Diary MIDI Out",
    tag: outputTag,
    uniqueID: .userDefaultsManaged(key: outputTag)
)


try midiManager.addInputConnection(
    toOutputs: .current(), // add all current system outputs to start with
    tag: "InputConnection1",
    automaticallyAddNewOutputs: true, // continually auto-add new outputs that appear
    preventAddingManagedOutputs: true, // filter out Manager-owned virtual outputs
    receiveHandler: .events { events in
        // Note: this handler will be called on a background thread
        // so call the next line on main if it may result in UI updates
        DispatchQueue.main.async {
            events.forEach { receivedMIDIEvent($0) }
        }
    }
)

let ins = midiManager.endpoints.inputs.sortedByName().description
let outs = midiManager.endpoints.outputs.sortedByName().description

private func receivedMIDIEvent(_ event: MIDI.Event) {
    let input = midiManager.managedInputs[inputTag]
    
    if (thru) {
        do {
            let output = midiManager.managedOutputs[outputTag];
            try output?.send(event: event);
        }
        catch let err {
            print("Error while thru: \(err)")
        }

    }
    print ("New event", event.description)
    switch event {
    case .noteOn(let payload):
        print("NoteOn:", payload.note, payload.velocity, payload.channel)
    case .noteOff(let payload):
        print("NoteOff:", payload.note, payload.velocity, payload.channel)
    case .cc(let payload):
        print("CC:", payload.controller, payload.value, payload.channel)
    case .programChange(let payload):
        print("PrgCh:", payload.program, payload.channel)
        
    // etc...

    default:
        break
    }
    
}
