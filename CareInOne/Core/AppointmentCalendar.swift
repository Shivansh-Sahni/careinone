import Foundation
import CryptoKit

/// Calendar exports require an explicitly scheduled, reviewed appointment.
/// This is an evidence eligibility check, never a confirmation of outside care.
public enum AppointmentCalendarPolicy {
    public static func canExport(_ claim: Claim, in state: CareState, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard claim.canonical, claim.kind == .appointment,
              [.scheduled, .appointmentScheduled].contains(claim.action),
              [.reported, .documented].contains(claim.certainty),
              !claim.negated, !claim.conditional,
              let date = claim.dueAt, date.timeIntervalSince1970.isFinite,
              claim.duePrecision == .exact, date >= calendar.startOfDay(for: now),
              state.source(claim.sourceID) != nil,
              state.unsupersededClaims.contains(where: { $0.id == claim.id && $0 == claim }),
              !state.conflicts.contains(where: { $0.status == .unresolved && $0.claimIDs.contains(claim.id) }) else { return false }
        return true
    }

    /// An opaque receipt identifies this exact reviewed calendar snapshot.
    /// No title, source quotation or patient name is stored in preferences.
    public static func receiptKey(_ claim: Claim) -> String {
        let snapshot = claim.id.uuidString + "|" + String(claim.dueAt?.timeIntervalSince1970.bitPattern ?? 0) + "|" + String(claim.dueTimeKnown)
        return SHA256.hash(data: Data(snapshot.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public static func claimKey(_ claim: Claim) -> String {
        SHA256.hash(data: Data(claim.id.uuidString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
