# CareInOne naming and compatibility

The product name is **CareInOne** throughout the app, error messages, exports, setup instructions, release listing, deployment templates, package, source folder, Xcode project, targets, and scheme. Open `CareInOne.xcodeproj`, then select `CareInOne`.

A few internal identifiers intentionally retain their original bytes. They are compatibility keys, not the product name:

- `org.carecontinuity.app` is the installed app identity. Changing it creates a different sandbox and can disconnect the existing patient from their records. Test bundle IDs use the same stable prefix.
- The Swift module remains `CareContinuity` through `PRODUCT_MODULE_NAME`; SwiftData model identity must remain compatible with the existing store. The executable, target, and scheme are `CareInOne`. Integration tests import the stable module.
- `CareContinuity.store`, the application-support folder, and the Keychain service continue opening the same database, evidence, and credentials.
- `carecontinuity-encrypted-backup` and `carecontinuity-backup-v1` are archive format/authenticated-encryption identifiers. Changing them would invalidate existing backups.
- Export cleanup recognizes both the current and former temporary export directories, so erase/restore also removes copies made before the rename.
- Earlier files under `docs/verification/` are immutable historical build/test evidence. Their recorded commands and paths describe the builds actually tested at that time.

New deployment services and export filenames use CareInOne. No Git remote, signing identity, live cloud resource, or credentials were changed by this rename. A future storage migration must preserve originals, validate copied content, and exercise upgrade/rollback before retiring any compatibility keys.
