# Apple upload and screenshot requirements — checked October 4, 2026

Current primary-source guidance was checked directly during release preparation. Recheck before an eventual upload because these requirements change.

| Requirement | Current evidence | CareInOne action |
|---|---|---|
| Build tools / SDK | Since April 28, 2026: Xcode 26 or later, with the iOS/iPadOS 26 SDK or later | Record the actual final archive tools/SDK. The installed Xcode 27/iOS 27 tooling meets this threshold; a simulator build is not upload validation |
| Deployment target | Since September 9, 2026: iOS/iPadOS 13 or later | The project's iOS 18 target meets this threshold |
| Future tools / target | Starting April 2027: SDK 27 or later and iOS/iPadOS 15 or later | Current source/tooling already meets these announced thresholds, but final archive must still be checked |
| Build association | Bundle identifier/version associates the upload; build string identifies each build | Preserve `org.carecontinuity.app`; ensure a new build number is not already uploaded |
| Upload role | Account Holder, Admin, App Manager or Developer | Current individual account has Account Holder/Admin; verify the NutriAssist team role after conversion |

Sources: [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/), [Apple submitting guidance](https://developer.apple.com/app-store/submitting/), and [Apple upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

App screenshots require 1–10 JPEG/JPG/PNG files for the applicable required device sets, with no alpha channel. Current large-iPhone 6.9-inch portrait options include 1260×2736, 1290×2796 and 1320×2868. Apple allows the documented 6.5-inch alternative when the 6.9-inch set is absent. The 6.3-inch iPhone 18 Pro set alone does not satisfy the large-iPhone requirement. Because CareInOne supports iPad, provide the required 13-inch iPad set; accepted portrait options include 2064×2752 and 2048×2732. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

Capture actual native device pixels from the verified final fictional-demo candidate, without simulator/macOS chrome or credentials. Retain dimensions, color channels, build/device/runtime and visual inspection evidence. Scaling a smaller phone screenshot is not a substitute for checking the actual large-phone/iPad layout.
