import Foundation
import CareCore

extension AppStore {
    @discardableResult func startVisitCompanion(title: String, encounterID: UUID? = nil, eventAt: Date? = nil) -> UUID? {
        createVisitCompanion(title: title, encounterID: encounterID, eventAt: eventAt)
    }
    @discardableResult func createVisitCompanion(title: String, encounterID: UUID? = nil, eventAt: Date? = nil, opening: String = "", synthetic: Bool? = nil) -> UUID? {
        var id: UUID?
        return mutate { id = try VisitCompanionEngine.create(title: title, encounterID: encounterID, eventAt: eventAt, opening: opening, synthetic: synthetic, in: &$0) } ? id : nil
    }
    @discardableResult func captureVisitCompanionAnswers(_ companionID: UUID) -> UUID? {
        var sourceID: UUID?
        let saved = mutate { sourceID = try VisitCompanionEngine.captureAnswers(companionID: companionID, in: &$0) }
        if saved, let sourceID, source(sourceID)?.state == .pending { analyze(sourceID) }
        return saved ? sourceID : nil
    }
}
