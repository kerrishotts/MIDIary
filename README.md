# MIDIary

A simple SwiftUI application that listens to your MIDI inputs, and records what it hears into performances. Each performance can then be exported to a MIDI file for use in other applications (to listen to, to edit, etc.)

I find it most useful for recording my piano practice sessions without explicitly needing to set up a recording session. This allows me to catch performances I thought were good automatically, but also to catch the actual practice process and learn from my playing. Others may find it useful for other things.

## Backlog

- [ ] Select custom MIDI IN and OUT endpoints
- [ ] Show MIDI as a piano roll in UI (Maybe w/ AudioKit?)
- [ ] Enable MIDI playback in UI
- [ ] Prettier UI
- [ ] BUG: When switching between size classes, the sidebar doesn't always allow navigation. https://stackoverflow.com/questions/63552716/how-to-run-the-split-view-on-ipad-using-swiftui seems useful here?
- [ ] BUG: Doesn't record when backgrounded
- [ ] Add "Stay Awake" option
- [ ] Add settings for Time Signature and Tempo (currently 4/4 and 120QBPM)
- [ ] Add metronome?
- [ ] Indicate which performance is actively recording
- [ ] Practice Stats & Reports?
- [ ] Practice Notes?

## Dependencies

This app is not possible without [MIDIKit](https://github.com/orchetect/MIDIKit) and [MIDIKitSMF](https://github.com/orchetect/MIDIKitSMF), which is Copyright (c) 2021 Steffan Andrews - https://github.com/orchetect. 

## License

CC-BY 4.0.
