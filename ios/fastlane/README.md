fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios sync_certs

```sh
[bundle exec] fastlane ios sync_certs
```

Sync certificates and provisioning profiles via Match

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios build

```sh
[bundle exec] fastlane ios build
```

Build IPA for App Store / TestFlight (used in CI)

### ios ci_beta

```sh
[bundle exec] fastlane ios ci_beta
```

Full CI pipeline: build + upload to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
