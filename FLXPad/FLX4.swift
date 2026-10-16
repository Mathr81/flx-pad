// MIDI layout of the Pioneer DDJ-FLX4, copied from Mixxx's mapping
// (mixxxdj/mixxx: res/controllers/Pioneer-DDJ-FLX4.midi.xml and -script.js).
enum FLX4 {
    /// A deck button: the note it sends, and the note it sends while SHIFT is held.
    struct Key { let note: UInt8; let shifted: UInt8 }

    // Status bytes
    static func deckNote(_ deck: Int) -> UInt8 { 0x90 + UInt8(deck) }
    static func deckCC(_ deck: Int) -> UInt8 { 0xB0 + UInt8(deck) }
    static func padStatus(_ deck: Int, shift: Bool) -> UInt8 { 0x97 + UInt8(deck * 2) + (shift ? 1 : 0) }
    static let mixerNote: UInt8 = 0x96, mixerCC: UInt8 = 0xB6
    static let fxNote: UInt8 = 0x94, fxCC: UInt8 = 0xB4

    // Deck buttons (deckNote)
    static let shift: UInt8 = 0x3F
    static let play = Key(note: 0x0B, shifted: 0x0E)
    static let cue = Key(note: 0x0C, shifted: 0x48)
    static let sync = Key(note: 0x58, shifted: 0x60)
    static let syncLong: UInt8 = 0x5C // sent while SYNC is held, like the hardware (Mixxx: sync lock)
    static let loopIn = Key(note: 0x10, shifted: 0x4C)
    static let loopOut = Key(note: 0x11, shifted: 0x4E)
    static let reloop = Key(note: 0x4D, shifted: 0x50)
    static let callLeft = Key(note: 0x51, shifted: 0x3E)
    static let callRight = Key(note: 0x53, shifted: 0x3D)
    static let headphoneCue = Key(note: 0x54, shifted: 0x68)
    static let jogTouch = Key(note: 0x36, shifted: 0x67)

    // Deck CCs (deckCC). 14-bit controls send MSB on cc, LSB on cc + 0x20.
    static let jogPlatter: UInt8 = 0x22, jogSearch: UInt8 = 0x29, jogSide: UInt8 = 0x21
    static let tempo: UInt8 = 0x00, volume: UInt8 = 0x13, trim: UInt8 = 0x04
    static let eqHi: UInt8 = 0x07, eqMid: UInt8 = 0x0B, eqLow: UInt8 = 0x0F
    static let vuMeter: UInt8 = 0x02 // output only

    // Mixer (mixerCC / mixerNote)
    static let crossfader: UInt8 = 0x1F, headphoneMix: UInt8 = 0x0C
    static func filter(_ deck: Int) -> UInt8 { 0x17 + UInt8(deck) }
    static let browse = Key(note: 0x40, shifted: 0x64) // CC, relative: 0x01 down, 0x7F up
    static let browsePress = Key(note: 0x41, shifted: 0x42)
    static func load(_ deck: Int) -> UInt8 { 0x46 + UInt8(deck) }

    // Beat FX (fxNote / fxCC)
    static let fxSelect = Key(note: 0x63, shifted: 0x64)
    static let fxLeft: UInt8 = 0x4A, fxRight: UInt8 = 0x4B
    static let fxOnOff = Key(note: 0x47, shifted: 0x43)
    static let fxLevel: UInt8 = 0x02 // 7-bit
    /// CH1 / CH2 position of the Beat FX channel lever: (status, note).
    static func fxChannel(_ deck: Int) -> (UInt8, UInt8) { (0x94 + UInt8(deck), 0x10 + UInt8(deck)) }

    /// Mixxx scratches at 720 jog ticks per platter revolution.
    static let jogTicksPerTurn = 720.0

    enum PadMode: Int, CaseIterable {
        case hotCue, beatJump, sampler, stems, beatLoop, keyShift

        var label: String { ["HOT CUE", "BEAT JUMP", "SAMPLER", "STEMS", "BEAT LOOP", "KEY SHIFT"][rawValue] }
        /// Note of the mode button (deckNote). The bottom row is SHIFT + top row on the hardware.
        var modeNote: UInt8 { [0x1B, 0x20, 0x22, 0x69, 0x6D, 0x6F][rawValue] }
        /// Note of pad 1; pad n sends firstPad + n - 1 on padStatus.
        var firstPad: UInt8 { [0x00, 0x20, 0x30, 0x40, 0x60, 0x70][rawValue] }

        /// What pad `index` (0-7) does in Mixxx's FLX4 mapping.
        func padLabel(_ index: Int, deck: Int) -> String {
            switch self {
            case .hotCue: return "CUE \(index + 1)"
            case .beatJump: return ["◀ 1", "1 ▶", "◀ 2", "2 ▶", "◀ 4", "4 ▶", "◀ 8", "8 ▶"][index]
            case .sampler: return "S\([1, 2, 3, 4, 9, 10, 11, 12][index] + deck * 4)"
            case .stems: return index < 4 ? "STEM \(index + 1)" : "FX \(index - 3)"
            case .beatLoop: return ["1/4", "1/2", "1", "2", "4", "8", "16", "32"][index]
            case .keyShift: return ["0", "+1", "+2", "+3", "-3", "-2", "-1", "0"][index]
            }
        }
    }

    /// Normalised 0...1 value -> 14-bit (MSB, LSB).
    static func split14(_ value: Double) -> (msb: UInt8, lsb: UInt8) {
        let v = Int((min(max(value, 0), 1) * 16383).rounded())
        return (UInt8(v >> 7), UInt8(v & 0x7F))
    }

    /// Relative jog ticks -> CC values centred on 64, split into ±63 chunks.
    static func jogValues(_ ticks: Int) -> [UInt8] {
        var left = ticks, out: [UInt8] = []
        while left != 0 {
            let step = min(max(left, -63), 63)
            out.append(UInt8(64 + step))
            left -= step
        }
        return out
    }
}

/// MIDI 1.0 messages packed as Universal MIDI Packets (what CoreMIDI's event lists carry).
enum UMP {
    static func pack(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) -> UInt32 {
        0x2000_0000 | UInt32(status) << 16 | UInt32(data1 & 0x7F) << 8 | UInt32(data2 & 0x7F)
    }

    /// Extracts MIDI 1.0 channel voice messages, skipping other packet types by their size.
    static func shortMessages(_ words: [UInt32]) -> [(UInt8, UInt8, UInt8)] {
        let sizes = [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4] // words per message type
        var out: [(UInt8, UInt8, UInt8)] = [], i = 0
        while i < words.count {
            let w = words[i]
            if w >> 28 == 0x2 { out.append((UInt8(w >> 16 & 0xFF), UInt8(w >> 8 & 0x7F), UInt8(w & 0x7F))) }
            i += sizes[Int(w >> 28)]
        }
        return out
    }
}
