import Foundation

/// Aliases affect future matching only. Existing reviewed claim associations
/// remain unchanged when a patient adds or removes an alias.
public enum EntityAliasPolicy {
    public static func add(_ raw: String, to entityID: UUID, in state: inout CareState) throws {
        guard let index = state.entities.firstIndex(where: { $0.id == entityID }) else {
            throw CareError.invalid("This care item was removed. The alias was not saved.")
        }
        let display = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        let key = Normalizer.key(display)
        guard !key.isEmpty else { throw CareError.invalid("Enter a recognizable name for this same care item.") }
        let entity = state.entities[index]
        guard key != entity.normalizedKey, key != Normalizer.key(entity.label),
              !entity.aliases.contains(where: { Normalizer.key($0) == key }) else {
            throw CareError.invalid("This name is already saved for this care item. No duplicate alias was added.")
        }
        state.entities[index].aliases.append(display)
        state.audit.append(Audit(action: "entity_alias_added"))
    }

    public static func remove(_ raw: String, from entityID: UUID, in state: inout CareState) throws {
        guard let index = state.entities.firstIndex(where: { $0.id == entityID }) else {
            throw CareError.invalid("This care item was removed. No alias was changed.")
        }
        let key = Normalizer.key(raw)
        let matches: (String) -> Bool = { key.isEmpty ? $0 == raw : Normalizer.key($0) == key }
        guard state.entities[index].aliases.contains(where: matches) else {
            throw CareError.invalid("This alias was already removed. No other saved information was changed.")
        }
        state.entities[index].aliases.removeAll(where: matches)
        state.audit.append(Audit(action: "entity_alias_removed"))
    }
}
