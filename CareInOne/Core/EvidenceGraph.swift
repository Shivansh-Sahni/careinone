import Foundation

public enum EvidenceNodeID: Hashable, Sendable {
    case source(UUID), report(UUID), entity(UUID), conflict(String), loop(String)
    public var key: String {
        switch self {
        case .source(let id): "source:" + id.uuidString
        case .report(let id): "report:" + id.uuidString
        case .entity(let id): "entity:" + id.uuidString
        case .conflict(let id): "conflict:" + id
        case .loop(let id): "loop:" + id
        }
    }
    public var label: String {
        switch self {
        case .source: "Preserved source"
        case .report: "Reviewed report"
        case .entity: "Care item"
        case .conflict: "Discrepancy"
        case .loop: "Follow-through"
        }
    }
}
public struct EvidenceNode: Identifiable, Sendable {
    public var id: EvidenceNodeID
    public var title: String
    public var detail: String
    public var sourceIDs: [UUID]
}
public struct EvidenceEdge: Identifiable, Sendable {
    public var from: EvidenceNodeID
    public var to: EvidenceNodeID
    public var label: String
    public var id: String { from.key + "|" + to.key + "|" + label }
}
public enum EvidenceDirection: String, CaseIterable, Sendable {
    case upstream = "Where it comes from", downstream = "What it informs"
}
public struct EvidenceTraceStep: Identifiable, Sendable {
    public var node: EvidenceNode
    public var depth: Int
    public var parent: EvidenceNodeID?
    public var relationship: String?
    public var id: EvidenceNodeID { node.id }
}
public struct EvidenceTrace: Sendable {
    public var steps: [EvidenceTraceStep]
    public var truncated: Bool
}

/// A graph of information dependencies. An edge never asserts clinical causality.
public struct EvidenceGraph: Sendable {
    public var nodes: [EvidenceNodeID: EvidenceNode]
    public var edges: [EvidenceEdge]

    public init(_ state: CareState) {
        var nodes: [EvidenceNodeID: EvidenceNode] = [:], edges: [EvidenceEdge] = []
        let sources = Dictionary(uniqueKeysWithValues: state.sources.map { ($0.id, $0) })
        let claims = state.claims.filter { $0.canonical && sources[$0.sourceID] != nil }
        let claimsByID = Dictionary(uniqueKeysWithValues: claims.map { ($0.id, $0) })
        let byEntity = Dictionary(grouping: claims, by: \.entityID)
        let relevantEntities = Set(claims.flatMap { [$0.entityID, $0.relatedEntityID].compactMap { $0 } })
        func add(_ id: EvidenceNodeID, _ title: String, _ detail: String, _ sourceIDs: [UUID]) {
            nodes[id] = EvidenceNode(id: id, title: title, detail: detail, sourceIDs: Array(Set(sourceIDs)).sorted { $0.uuidString < $1.uuidString })
        }
        for source in state.sources {
            add(.source(source.id), source.title, "Original evidence · " + source.kind.rawValue + " · version \(source.version)", [source.id])
        }
        for claim in claims {
            add(.report(claim.id), claim.summary, ContinuityComparator.describe(claim, sourceTitle: sources[claim.sourceID]?.title), [claim.sourceID])
            edges.append(EvidenceEdge(from: .source(claim.sourceID), to: .report(claim.id), label: "is the evidence for"))
            if let id = claim.entityID { edges.append(EvidenceEdge(from: .report(claim.id), to: .entity(id), label: "reports on")) }
        }
        for entity in state.entities where relevantEntities.contains(entity.id) {
            let reports = byEntity[entity.id] ?? []
            add(.entity(entity.id), entity.label, "Saved projection: " + state.projection(for: entity.id).displayLabel, reports.map(\.sourceID))
        }
        for conflict in state.conflicts {
            let reports = conflict.claimIDs.compactMap { claimsByID[$0] }
            guard !reports.isEmpty else { continue }
            add(.conflict(conflict.id), conflict.reason, conflict.status.rawValue + "\n" + conflict.question, reports.map(\.sourceID))
            for claim in reports { edges.append(EvidenceEdge(from: .report(claim.id), to: .conflict(conflict.id), label: "participates in this comparison")) }
            edges.append(EvidenceEdge(from: .entity(conflict.entityID), to: .conflict(conflict.id), label: "has a saved discrepancy"))
        }
        for loop in state.loops {
            let reports = loop.claimIDs.compactMap { claimsByID[$0] }
            guard !reports.isEmpty else { continue }
            add(.loop(loop.id), loop.title, loop.stage.displayLabel + " · " + loop.status.rawValue, reports.map(\.sourceID))
            for claim in reports { edges.append(EvidenceEdge(from: .report(claim.id), to: .loop(loop.id), label: "informs this workflow")) }
            edges.append(EvidenceEdge(from: .entity(loop.entityID), to: .loop(loop.id), label: "has follow-through"))
        }
        func endpoint(_ id: UUID) -> EvidenceNodeID? {
            if claimsByID[id] != nil { return .report(id) }
            if nodes[.entity(id)] != nil { return .entity(id) }
            return nil
        }
        for relation in state.relations where relation.kind != .sameEntity {
            guard let from = endpoint(relation.from), let to = endpoint(relation.to) else { continue }
            edges.append(EvidenceEdge(from: from, to: to, label: "Saved relation: " + relation.kind.displayLabel))
        }
        self.nodes = nodes
        var seen = Set<String>()
        self.edges = edges.filter { nodes[$0.from] != nil && nodes[$0.to] != nil && seen.insert($0.id).inserted }.sorted { $0.id < $1.id }
    }

    /// Bounded breadth-first traversal: one shortest path per node, with explicit truncation.
    public func trace(from root: EvidenceNodeID, direction: EvidenceDirection, maximumDepth: Int = 6, maximumNodes: Int = 200) -> EvidenceTrace {
        guard let start = nodes[root] else { return EvidenceTrace(steps: [], truncated: false) }
        let limit = max(1, min(maximumNodes, 2_000)), depthLimit = max(0, min(maximumDepth, 30))
        let adjacent = Dictionary(grouping: edges) { direction == .upstream ? $0.to : $0.from }
        var steps = [EvidenceTraceStep(node: start, depth: 0)], visited: Set<EvidenceNodeID> = [root]
        var index = 0, truncated = false
        while index < steps.count {
            let current = steps[index]; index += 1
            for edge in adjacent[current.id] ?? [] {
                let target = direction == .upstream ? edge.from : edge.to
                guard !visited.contains(target), let node = nodes[target] else { continue }
                guard current.depth < depthLimit, steps.count < limit else { truncated = true; continue }
                visited.insert(target)
                steps.append(EvidenceTraceStep(node: node, depth: current.depth + 1, parent: current.id, relationship: edge.label))
            }
        }
        return EvidenceTrace(steps: steps, truncated: truncated)
    }
}

public struct SourceOmissionPreview: Sendable {
    public var omittedSourceIDs: [UUID]
    public var comparison: ContinuityComparison
    public var careItemsWithoutReports: [Entity]
}
public enum SourceOmissionEngine {
    public static func preview(_ sourceIDs: Set<UUID>, in state: CareState) throws -> SourceOmissionPreview {
        guard !sourceIDs.isEmpty, sourceIDs.count <= 30, sourceIDs.isSubset(of: Set(state.sources.map(\.id))) else {
            throw CareError.invalid("Select 1–30 saved sources for this temporary preview.")
        }
        let before = ContinuityEngine.snapshot(state, title: "All currently saved evidence")
        var copy = state
        let ordered = sourceIDs.sorted { $0.uuidString < $1.uuidString }
        for id in ordered { try Task.checkCancellation(); Reconciler.deleteSource(id, from: &copy) }
        let remaining = Set(copy.claims.filter(\.canonical).compactMap(\.entityID))
        let previouslyPresent = Set(state.claims.filter(\.canonical).compactMap(\.entityID))
        return SourceOmissionPreview(omittedSourceIDs: ordered, comparison: ContinuityComparator.compare(before, to: copy),
            careItemsWithoutReports: state.entities.filter { previouslyPresent.contains($0.id) && !remaining.contains($0.id) }.sorted { $0.id.uuidString < $1.id.uuidString })
    }
}
