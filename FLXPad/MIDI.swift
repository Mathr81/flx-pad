import CoreMIDI
import Foundation
import Network

extension Notification.Name {
    /// Posted on the main thread; `object` is the changed key (UInt16), or nil to redraw everything.
    static let ledChanged = Notification.Name("FLXPad.ledChanged")
}

func ledKey(_ status: UInt8, _ data1: UInt8) -> UInt16 { UInt16(status) << 8 | UInt16(data1) }

/// Per-deck controller state that the real FLX4 keeps in its firmware.
final class DeckState {
    var shift = false
    var padMode = FLX4.PadMode.hotCue
}
let decks = [DeckState(), DeckState()]
var anyShift: Bool { decks.contains { $0.shift } }

/// Network (RTP-MIDI) session: the iPad shows up in rtpMIDI's directory on Windows.
final class MIDI: ObservableObject {
    static let shared = MIDI()

    @Published private(set) var peers: [String] = []
    private var values: [UInt16: UInt8] = [:] // last value received per (status, data1), main thread only
    private var client = MIDIClientRef(), outPort = MIDIPortRef(), inPort = MIDIPortRef()
    private let session = MIDINetworkSession.default()
    // Browsing Bonjour from the app makes iOS ask for local network access up front.
    private let browser = NWBrowser(for: .bonjour(type: "_apple-midi._udp", domain: nil), using: .udp)

    private init() {
        session.isEnabled = true
        session.connectionPolicy = .anyone
        browser.start(queue: .main)
        MIDIClientCreateWithBlock("FLX-Pad" as CFString, &client, nil)
        MIDIOutputPortCreate(client, "FLX-Pad Out" as CFString, &outPort)
        MIDIInputPortCreateWithProtocol(client, "FLX-Pad In" as CFString, ._1_0, &inPort) { [weak self] list, _ in
            var words: [UInt32] = []
            for packet in list.unsafeSequence() {
                let start = UnsafeRawPointer(packet)
                    .advanced(by: MemoryLayout<MIDIEventPacket>.offset(of: \.words)!)
                    .assumingMemoryBound(to: UInt32.self)
                words += UnsafeBufferPointer(start: start, count: Int(packet.pointee.wordCount))
            }
            let messages = UMP.shortMessages(words)
            DispatchQueue.main.async { messages.forEach { self?.receive($0.0, $0.1, $0.2) } }
        }
        MIDIPortConnectSource(inPort, session.sourceEndpoint(), nil)
        NotificationCenter.default.addObserver(
            forName: Notification.Name(MIDINetworkNotificationSessionDidChange), object: nil, queue: .main
        ) { [weak self] _ in self?.refreshPeers() }
        refreshPeers()
    }

    private func refreshPeers() {
        peers = session.connections().map { $0.host.name }.sorted()
    }

    private func receive(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        var status = status, data2 = data2
        if status & 0xF0 == 0x80 { status |= 0x10; data2 = 0 } // note off = note on with velocity 0
        let key = ledKey(status, data1)
        guard values[key] != data2 else { return }
        values[key] = data2
        NotificationCenter.default.post(name: .ledChanged, object: key)
    }

    func value(_ key: UInt16) -> UInt8 { values[key] ?? 0 }

    func send(_ status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        var list = MIDIEventList()
        var word = UMP.pack(status, data1, data2)
        withUnsafeMutablePointer(to: &list) { ptr in
            let packet = MIDIEventListInit(ptr, ._1_0)
            _ = MIDIEventListAdd(ptr, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
            MIDISendEventList(outPort, session.destinationEndpoint(), ptr)
        }
    }

    func note(_ status: UInt8, _ note: UInt8, _ on: Bool) { send(status, note, on ? 0x7F : 0x00) }

    func cc14(_ status: UInt8, _ cc: UInt8, _ value: Double) {
        let v = FLX4.split14(value)
        send(status, cc, v.msb) // Mixxx applies the value when the LSB arrives
        send(status, cc + 0x20, v.lsb)
    }
}
