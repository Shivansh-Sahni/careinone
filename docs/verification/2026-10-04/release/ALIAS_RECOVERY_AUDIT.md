# Alias recovery — October 4, 2026

`EntityDetailView` previously compared the untrimmed input to stored aliases, then saved a trimmed value. Case and spacing variants could become duplicates. A missing entity also produced a successful no-op, and a mistaken alias had no removal control.

The focused repair uses `EntityAliasPolicy` to collapse display whitespace and compare the same normalized key used by future entity matching. Duplicate aliases, the primary name, empty non-name input, a removed item and a stale removal fail explicitly without committing a change. Failed persistence retains the previous state and the alias input. Removal requires confirmation and explains that only future name matching changes; existing reviewed claims, sources, relations and their canonical associations stay unchanged. A removal clears legacy equivalent duplicate entries together while preserving other aliases.

The entity detail shows each alias as wrapping text with an accessible removal button. No Calendar control or clinical association rule was changed by this edit.

## Evidence

| Check | Result | Scope |
|---|---|---|
| [alias-syntax-check.log](alias-syntax-check.log) | Parse exit 0 | Changed view, policy and tests only |
| [alias-core-tests.log](alias-core-tests.log) | Four tests passed, exit 0 | Case/spacing duplicates with no false audit history; future automatic matching stops without rewriting reviewed evidence; legacy duplicates; empty and stale errors |
| `EntityAliasIntegrationTests` | Both passed in [Candidate4](candidate4-summary.json) | Actual SwiftData reopen after add/remove preserving claim identity; save-failure rollback and a deleted item's stale draft rejection |

The independent core suite compiled with a pre-existing redundant `#require` warning in `WorkflowHardeningTests`. Native persistence/rollback cases passed in Candidate4. Final user-facing alias removal confirmation/navigation remains a separate manual boundary. This edit does not establish arbitrary multi-patient alias management, terminology validation, or clinical synonym correctness.
