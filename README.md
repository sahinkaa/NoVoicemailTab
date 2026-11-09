# No Voicemail Tab

<img src="icon.png" alt="No Voicemail Tab icon" width="96">

Remove the Voicemail tab from the Phone app.

Tested on iOS 16.6 and iOS 26.0.1 with RootHide. Rootless and native RootHide packages are available in [Releases](https://github.com/sahinkaa/NoVoicemailTab/releases). Install the package for your jailbreak, then fully quit and reopen Phone.

## Build

Use Xcode, Theos and ldid. For RootHide, set THEOS to a RootHide-capable Theos checkout.

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```
