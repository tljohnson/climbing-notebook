import SwiftUI

struct PrototypePitch: Identifiable, Equatable {
    let id: String
    let name: String
    let grade: String
    var notes: String
}

struct PrototypeRoute: Identifiable, Equatable {
    let id: String
    let name: String
    let grade: String
    let style: String
    var notes: String
    var pitches: [PrototypePitch]

    mutating func movePitches(from offsets: IndexSet, to destination: Int) {
        pitches.move(fromOffsets: offsets, toOffset: destination)
    }

    mutating func movePitch(id: String, by distance: Int) {
        guard let index = pitches.firstIndex(where: { $0.id == id }),
              pitches.indices.contains(index + distance) else { return }
        movePitches(from: IndexSet(integer: index), to: distance > 0 ? index + distance + 1 : index + distance)
    }
}

struct PrototypeArea: Identifiable {
    let id: String
    let name: String
    var routes: [PrototypeRoute]

    static var fixtures: [Self] {
        [Self(id: "granite", name: "Example Granite", routes: [
            PrototypeRoute(id: "skyline", name: "Paper Skyline", grade: "5.8", style: "Trad", notes:
                "A fictional five-pitch outing for trying the notebook.\n\nApproach: follow the imaginary ridge.\nDescent: return by the fictional walking path.\nGear: add your synthetic planning notes here.\n\nNot climbing guidance.", pitches: [
                    PrototypePitch(id: "slab", name: "Opening slab", grade: "5.6", notes: "Start below the imaginary rounded slab. A short pitch to settle into the day."),
                    PrototypePitch(id: "corner", name: "Quiet corner", grade: "5.8", notes: "Follow the fictional corner.\nKeep notes in your own words: arête, 岩, café."),
                    PrototypePitch(id: "traverse", name: "High traverse", grade: "5.7", notes: "Traverse across the imaginary ledge.\n\nThis longer example is here to test reading and scrolling, not to describe a real climb.\n\nAdd reminders, alternate plans or questions below. Plain text keeps line breaks and Unicode as entered."),
                    PrototypePitch(id: "crack", name: "Upper crack", grade: "5.8", notes: "An invented crack above the ledge. Try moving this pitch and checking its notes."),
                    PrototypePitch(id: "ridge", name: "Summit ridge", grade: "5.5", notes: "Finish on the fictional ridge. This is the fifth entered pitch.")
                ]),
            PrototypeRoute(id: "unwritten", name: "Unwritten Line", grade: "", style: "", notes: "", pitches: [])
        ]), Self(id: "meadow", name: "Example Meadow", routes: [])]
    }
}
