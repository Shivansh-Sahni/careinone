**Resolved later September 15:** Xcode 27 license accepted. The complete native test action passes 20/20 (17 integration + 3 UI), and the unsigned iPhone Release build passes. See `native-final.json` and `device-release-final.txt`. Gateway suite now has 50 passing tests including synthetic-evaluation rubric checks. The earlier license blocker below is retained as historical context.

# September 15 verification

These results describe the current changes separately from the September 7 simulator screenshots and results.

| Check | Result |
|---|---|
| Swift core tests | **59 passed**, four suites; `swift-core.txt` |
| Gateway tests | **47 passed**; `gateway-tests.txt` |
| Real localhost HTTP smoke | Passed health, extraction, recipient-consent handshake, configuration, fixed synthetic check, and no-store headers |
| Cloud transport Foundation type check | Passed with the macOS command-line SDK |
| Native Swift syntax parse | Passed for every App, Views, and Services file |
| Repository release preflight | Passed project membership, plists, manifest, all 215 capability IDs, and release packet checks |
| iPhone build / native tests | **Blocked before compilation by Xcode 27’s license**; `native-build-blocker.txt` |
| Live OpenAI/Kimi validation | Not run; no provider credentials supplied |

The 17 integration tests (three newly added) and three UI tests need execution after accepting Xcode’s license. Syntax parsing and macOS transport checking do not establish that the complete iOS target builds. September 7 native pass results apply to the earlier commit only.

## Core test command used here

The existing Command Line Tools compiler works independently of the newly installed Xcode. Its Testing framework needs an explicit search path; its optional `_Testing_Foundation` cross-import overlay is missing. This runs every test with that optional overlay disabled:

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools swift test \
  --scratch-path /private/tmp/care-sep15-clt \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

Normal `swift test` remains the standard once Xcode is configured. This local toolchain workaround is not baked into the app or CI.

```sh
python3 -m unittest discover -s backend/tests -v
.venv/bin/python scripts/backend_smoke.py
python3 scripts/release_preflight.py
```

The HTTP smoke test starts and removes a localhost server with synthetic text and a random ephemeral token. It does not contact a provider.

## Next native run

Review and accept the license in Xcode or run `sudo xcodebuild -license`. Run the shared scheme’s complete test action and a Release build. Previously available: iPhone 16 Pro, iOS 18.4, ID `653F56D1-0FC8-4449-A486-118013DBECAC`; check availability before choosing the destination.

Check cloud connection/consent, backup creation/restore, question editing, encounter editing/removal, Help & privacy, and readable badges at large text sizes. No new-view screenshot is claimed as verified.
