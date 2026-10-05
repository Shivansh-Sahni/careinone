# Backup keyboard verification

The final full UI action failed its immediate keyboard-count assertion after one native Done tap. The software keyboard remains visible in original movie frames at41 and42 seconds. The synthesized event tap was at logical(383.833,585) in a440×956 window, apparently inside the visible Done button; this does not establish a clipped tap or a dismissal timing issue. Exported AX snapshots contain only the app root, so a precise native focus diagnosis is unavailable.

The unchanged complete BackupWorkflowUITests case passed separately on another allocated disposable iOS27 simulator in62.985 seconds, including exact keyboard absence, encrypted backup creation, offered share file, and invalidation when retained-audio selection changes. That pass does not erase the original full-action failure. No production or backup-test patch was made without a proven cause.

Original and focused native results, events, summary, logs, and fictional screenshots are retained. No personal data or backend credentials were used.
