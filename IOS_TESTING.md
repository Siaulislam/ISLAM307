# ISLAM 307 — iOS testing

The iOS build must run on macOS with Xcode. The repository now includes:

`.github/workflows/ios-test-build.yml`

It generates the missing Flutter iOS scaffold and creates two artifacts:

1. `ISLAM307-iOS-Simulator.zip` — runnable in an iOS Simulator on a Mac.
2. `ISLAM307-unsigned-iOS` — unsigned `.ipa` archive for later signing.

## Run the build

1. Open the GitHub repository.
2. Select **Actions → Flutter iOS test build**.
3. Click **Run workflow**.
4. When both jobs finish, download the artifacts from the workflow run.

## Test in iOS Simulator

On a Mac with Xcode:

```bash
unzip ISLAM307-iOS-Simulator.zip
open -a Simulator
xcrun simctl install booted Runner.app
xcrun simctl launch booted com.siaulislam.islam307
```

## Physical iPhone or TestFlight

The unsigned `.ipa` cannot be installed directly on an iPhone. A signed build
requires:

- Apple Developer team membership
- Distribution or Development signing certificate
- Matching provisioning profile
- Registered bundle identifier
- App Store Connect/TestFlight setup when applicable

Do not commit certificates, private keys, provisioning profiles, API keys, or
passwords. They must be stored as encrypted GitHub Actions secrets or handled
locally through Xcode.
