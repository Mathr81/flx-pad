import SwiftUI
import UIKit

@main
struct FLXPadApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Hosts one UIKit control; SwiftUI only does the layout.
struct Control<V: UIView>: UIViewRepresentable {
    let make: () -> V
    init(_ make: @escaping () -> V) { self.make = make }
    func makeUIView(context: Context) -> V { make() }
    func updateUIView(_ view: V, context: Context) {}
}

struct ContentView: View {
    @ObservedObject private var midi = MIDI.shared

    var body: some View {
        HStack(spacing: 10) {
            DeckView(deck: 0)
            MixerView(peers: midi.peers).frame(width: 330)
            DeckView(deck: 1)
        }
        .padding(10)
        .background(Color(white: 0.06).ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    }
}

// MARK: - Building blocks

/// Deck button: sends the SHIFT variant while SHIFT is held, and releases the same note it pressed.
func deckKey(_ label: String, _ key: FLX4.Key, deck: Int, color: UIColor = .systemOrange) -> some View {
    let status = FLX4.deckNote(deck)
    var sent = key.note
    return Control {
        let v = PadView(label, color: color) { down in
            if down { sent = decks[deck].shift ? key.shifted : key.note }
            MIDI.shared.note(status, sent, down)
        }
        v.led = { ledKey(status, key.note) }
        return v
    }
}

/// Mixer / FX button whose SHIFT variant depends on either SHIFT.
func globalKey(_ label: String, status: UInt8, _ key: FLX4.Key, color: UIColor = .systemOrange) -> some View {
    var sent = key.note
    return Control {
        let v = PadView(label, color: color) { down in
            if down { sent = anyShift ? key.shifted : key.note }
            MIDI.shared.note(status, sent, down)
        }
        v.led = { ledKey(status, key.note) }
        return v
    }
}

func knob(_ label: String, status: UInt8, cc: UInt8, color: UIColor = .systemOrange) -> some View {
    Control { KnobView(label, color: color) { MIDI.shared.cc14(status, cc, $0) } }
}

// MARK: - Deck

struct DeckView: View {
    let deck: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                deckKey("LOOP\nIN", FLX4.loopIn, deck: deck)
                deckKey("LOOP\nOUT", FLX4.loopOut, deck: deck)
                deckKey("RELOOP\nEXIT", FLX4.reloop, deck: deck)
                deckKey("◀ CUE/\nLOOP CALL", FLX4.callLeft, deck: deck, color: .systemGray)
                deckKey("CUE/ ▶\nLOOP CALL", FLX4.callRight, deck: deck, color: .systemGray)
            }
            .frame(height: 44)

            HStack(spacing: 8) {
                Control { JogView(deck: deck) }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Control {
                    FaderView("TEMPO", value: 0.5, center: 0.5) { MIDI.shared.cc14(FLX4.deckCC(deck), FLX4.tempo, $0) }
                }
                .frame(width: 52)
            }

            HStack(spacing: 8) {
                VStack(spacing: 6) {
                    Control {
                        PadView("SHIFT", color: .white) { down in
                            decks[deck].shift = down
                            MIDI.shared.note(FLX4.deckNote(deck), FLX4.shift, down)
                        }
                    }
                    deckKey("BEAT\nSYNC", FLX4.sync, deck: deck, color: .systemCyan)
                    deckKey("CUE", FLX4.cue, deck: deck, color: .systemOrange)
                    deckKey("▶︎ ‖", FLX4.play, deck: deck, color: .systemGreen)
                }
                .frame(width: 80)
                PadsView(deck: deck)
            }
            .frame(height: 260)
        }
    }
}

struct PadsView: View {
    let deck: Int
    private let modes = FLX4.PadMode.allCases

    var body: some View {
        VStack(spacing: 6) {
            ForEach([0, 3], id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(modes[row..<row + 3], id: \.self) { modeButton($0) }
                }
                .frame(height: 30)
            }
            ForEach([0, 4], id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row..<row + 4, id: \.self) { pad($0) }
                }
            }
        }
    }

    private func modeButton(_ mode: FLX4.PadMode) -> some View {
        Control {
            PadView(mode.label, color: mode.color, lit: { decks[deck].padMode == mode }) { down in
                if down {
                    decks[deck].padMode = mode
                    NotificationCenter.default.post(name: .ledChanged, object: nil) // repaint pads for the new mode
                }
                MIDI.shared.note(FLX4.deckNote(deck), mode.modeNote, down)
            }
        }
    }

    private func pad(_ index: Int) -> some View {
        var sent = (status: UInt8(0), note: UInt8(0))
        return Control {
            let v = PadView("\(index + 1)", color: .systemGray) { down in
                if down {
                    let state = decks[deck]
                    sent = (FLX4.padStatus(deck, shift: state.shift), state.padMode.firstPad + UInt8(index))
                }
                MIDI.shared.note(sent.status, sent.note, down)
            }
            v.led = { ledKey(FLX4.padStatus(deck, shift: false), decks[deck].padMode.firstPad + UInt8(index)) }
            return v
        }
    }
}

extension FLX4.PadMode {
    var color: UIColor {
        [UIColor.systemPink, .systemBlue, .systemPurple, .systemGreen, .systemYellow, .systemTeal][rawValue]
    }
}

// MARK: - Mixer

struct MixerView: View {
    let peers: [String]

    var body: some View {
        VStack(spacing: 8) {
            Text(peers.isEmpty ? "○ En attente de rtpMIDI…" : "● " + peers.joined(separator: ", "))
                .font(.caption.bold())
                .foregroundColor(peers.isEmpty ? .orange : .green)
                .lineLimit(1)

            HStack(spacing: 6) {
                globalKey("LOAD\n1", status: FLX4.mixerNote, FLX4.Key(note: FLX4.load(0), shifted: FLX4.load(0)))
                Control {
                    EncoderView(onStep: { step in
                        MIDI.shared.send(FLX4.mixerCC, anyShift ? FLX4.browse.shifted : FLX4.browse.note, step > 0 ? 0x01 : 0x7F)
                    }, onPress: {
                        let note = anyShift ? FLX4.browsePress.shifted : FLX4.browsePress.note
                        MIDI.shared.note(FLX4.mixerNote, note, true)
                        MIDI.shared.note(FLX4.mixerNote, note, false)
                    })
                }
                .frame(width: 130)
                globalKey("LOAD\n2", status: FLX4.mixerNote, FLX4.Key(note: FLX4.load(1), shifted: FLX4.load(1)))
            }
            .frame(height: 64)

            HStack(spacing: 6) {
                ChannelStrip(deck: 0)
                VStack(spacing: 8) {
                    knob("HEAD MIX", status: FLX4.mixerCC, cc: FLX4.headphoneMix, color: .systemGray).frame(height: 64)
                    Control {
                        KnobView("FX LEVEL", value: 0, color: .systemRed) {
                            MIDI.shared.send(FLX4.fxCC, FLX4.fxLevel, UInt8(($0 * 127).rounded()))
                        }
                    }
                    .frame(height: 64)
                    Spacer()
                }
                .frame(width: 64)
                ChannelStrip(deck: 1)
            }

            HStack(spacing: 5) {
                Control { PadView("FX\n◀", color: .systemRed) { MIDI.shared.note(FLX4.fxNote, FLX4.fxLeft, $0) } }
                Control { PadView("FX\n▶", color: .systemRed) { MIDI.shared.note(FLX4.fxNote, FLX4.fxRight, $0) } }
                globalKey("FX\nSELECT", status: FLX4.fxNote, FLX4.fxSelect, color: .systemRed)
                fxChannel(0)
                fxChannel(1)
                globalKey("FX\nON", status: FLX4.fxNote, FLX4.fxOnOff, color: .systemRed)
            }
            .frame(height: 40)

            Control {
                FaderView("", value: 0.5, center: 0.5, horizontal: true) {
                    MIDI.shared.cc14(FLX4.mixerCC, FLX4.crossfader, $0)
                }
            }
            .frame(height: 48)
        }
    }

    /// One position of the Beat FX channel lever, as an on/off toggle.
    private func fxChannel(_ deck: Int) -> some View {
        let (status, note) = FLX4.fxChannel(deck)
        return Control { PadView("FX\nCH\(deck + 1)", color: .systemRed, latching: true) { MIDI.shared.note(status, note, $0) } }
    }
}

struct ChannelStrip: View {
    let deck: Int

    var body: some View {
        let cc = FLX4.deckCC(deck)
        VStack(spacing: 4) {
            Group {
                knob("TRIM", status: cc, cc: FLX4.trim, color: .systemGray)
                knob("HI", status: cc, cc: FLX4.eqHi)
                knob("MID", status: cc, cc: FLX4.eqMid)
                knob("LOW", status: cc, cc: FLX4.eqLow)
                knob("CFX", status: FLX4.mixerCC, cc: FLX4.filter(deck), color: .systemTeal)
            }
            .frame(minHeight: 44, maxHeight: 62)
            deckKey("CUE 🎧", FLX4.headphoneCue, deck: deck).frame(height: 34)
            HStack(spacing: 4) {
                Control { () -> MeterView in
                    let m = MeterView(label: "")
                    m.led = { ledKey(cc, FLX4.vuMeter) }
                    return m
                }
                .frame(width: 8)
                Control { FaderView("VOL", value: 1) { MIDI.shared.cc14(cc, FLX4.volume, $0) } }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
