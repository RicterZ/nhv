# NHV

An unofficial nhentai client for iOS, built with Swift and SwiftUI.

<img width="4435" height="2796" alt="github-preview" src="https://github.com/user-attachments/assets/9171f053-0dc3-4fe7-a685-71fc2eb071f6" />

## Features

- **Browse and discover** — Explore galleries, search by title or tags, and sort results by date or popularity.
- **Read comfortably** — A fullscreen reader with tap or swipe paging, pinch-to-zoom, and image preloading.
- **Keep your place** — Manage favorites and revisit galleries through searchable, on-device browsing history.
- **Open and share** — Jump to a gallery from its ID or URL, optionally detect links on the clipboard, and share through iOS.
- **Make it yours** — Light and dark themes, English / Simplified Chinese / Japanese, language filtering, and optional cover blurring.

## Build and install

NHV requires **iOS 17 or later** and your own **nhentai API key**. After installation, open the app and enter your key. Your device must be able to reach the API and image services.

[GitHub releases](https://github.com/RicterZ/nhv/releases) provide source code and, starting with 0.1.4, an **unsigned IPA** for sideloading. Download the IPA from the release's **Assets** section and sign it through AltStore Classic. There is no App Store / TestFlight build at present.

| Method | What you need | Best for |
| --- | --- | --- |
| Xcode | A Mac with Xcode 26 or later, an Apple Account, and an iPhone | Building and installing directly from source |
| AltStore Classic | An iPhone, AltServer on Mac or Windows, an Apple Account, and a device IPA | Installing and refreshing an existing IPA |

AltStore installs IPA files; it does not compile this repository. Building an IPA from source still requires a Mac with Xcode.

### Install directly with Xcode

A free Apple Account is sufficient for installation on your own device. A paid Apple Developer Program membership is optional.

1. **Get the project.** Download and extract the source from a release, or clone the repository:

   ```sh
   git clone https://github.com/RicterZ/nhv.git
   cd nhv
   open NHV.xcodeproj
   ```

2. **Set up Xcode.** Use Xcode 26 or later, finish its first-launch setup, and install iOS platform support if prompted. In **Xcode → Settings → Accounts**, add your Apple Account.

3. **Configure signing.** Select the project in the navigator, then the **NHV** app target. In **Signing & Capabilities**:

   - Enable **Automatically manage signing**.
   - Select your own **Team** (your Personal Team works for a free account).
   - Replace `local.nhv.reader` with a unique bundle identifier for your copy, such as `com.yourname.nhv`.

   The repository's signing team belongs to the maintainer; replace it with your own. Keep the same team and bundle identifier when updating your installation.

4. **Connect the iPhone.** Connect by USB, unlock it, and accept **Trust This Computer** if asked. Enable **Settings → Privacy & Security → Developer Mode**, restart the phone, and confirm when prompted. If that option is missing, pair the device with Xcode first.

5. **Build and run.** In Xcode's toolbar, select the **NHV** scheme and your iPhone as the destination. Press **⌘R**. Xcode will build, sign, install, and launch the app. If iOS asks you to trust the developer, follow the prompt under **Settings → General → VPN & Device Management**.

For a simulator, select an installed iPhone simulator instead of a physical device and press **⌘R**. Device signing is not required.

With a free Personal Team, the provisioning profile typically expires after **seven days**. Connect the phone and run the project again to renew it. For updates, get the newer source and repeat the build using the same identity; deleting the app first removes its local data.

### Build an IPA for sideloading

Skip this section if you downloaded an IPA from a release or are installing directly through Xcode. To make your own IPA for AltStore Classic, create an **iOS device build** and package it as follows. A simulator build cannot be installed on an iPhone.

Run the following from the repository root on a Mac with Xcode 26 or later. It builds Release without signing and packages the result in a temporary directory:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
nhv_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/nhv-ipa.XXXXXX")"

xcodebuild \
  -project NHV.xcodeproj \
  -scheme NHV \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$nhv_build_dir/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build &&
mkdir -p "$nhv_build_dir/Payload" &&
ditto "$nhv_build_dir/DerivedData/Build/Products/Release-iphoneos/NHV.app" \
  "$nhv_build_dir/Payload/NHV.app" &&
ditto -c -k --keepParent "$nhv_build_dir/Payload" "$nhv_build_dir/NHV.ipa" &&
printf 'IPA created at: %s\n' "$nhv_build_dir/NHV.ipa"
```

If Xcode is installed elsewhere, adjust `DEVELOPER_DIR`. The resulting IPA is **unsigned**: AltStore must sign it with your account before iOS can run it. Copy it to the iPhone's Files app using AirDrop, iCloud Drive, or another file transfer method.

### Install with AltStore Classic

Use **AltStore Classic**, which supports sideloading your own IPA files. AltStore PAL is a separate distribution method and is not the route described here.

1. **Install AltServer on your computer.** Follow the official [AltStore Classic setup guide](https://faq.altstore.io/) for macOS or Windows, including any platform-specific dependencies. AltServer runs on the computer; AltStore runs on the iPhone.
2. **Install AltStore on the iPhone.** Connect the phone by USB, unlock it, and trust the computer. From AltServer's menu, choose **Install AltStore → your iPhone** and follow the Apple Account prompts. Complete developer trust and enable Developer Mode on the phone if requested.
3. **Import NHV.** Keep AltServer running and the phone connected. Open **AltStore → My Apps → +**, choose `NHV.ipa` from Files, and follow the sign-in prompts. AltStore signs and installs the app using your account.
4. **Refresh before expiry.** With a free account, apps normally expire after **seven days**. Use **Refresh All** in AltStore while AltServer is reachable. For wireless refresh, enable Wi-Fi syncing for the phone in Finder or iTunes as appropriate, and keep both devices on the same network with AltServer running. USB is also an option.
5. **Install updates.** Build or obtain the newer IPA, then import it through AltStore again using the same account and app identifier. Keep the existing app installed to retain its local data.

Free accounts normally allow **three active sideloaded apps**, including AltStore itself. If installation fails, first check AltServer connectivity, signing expiry, and available app slots. Refer to the [official AltStore documentation](https://faq.altstore.io/) for current setup instructions and troubleshooting.

## License

The project code is released under the [MIT License](LICENSE). Third-party names, logos, and content belong to their respective rights holders.

This project is not affiliated with nhentai and is intended for learning, research, and personal use. Follow the laws and age restrictions applicable in your country or region, comply with platform terms, and respect content copyrights.
