# NHV

An unofficial nhentai iOS client written in Swift for browsing, searching, and managing favorites. Currently in development; build and install it yourself with Xcode.

## Features

- API key sign-in with automatic session restoration.
- Latest galleries, automatic pagination, and cover preloading in display order.
- Search and sorting with syntax suggestions, exclusions, removable search terms, and local search history.
- Gallery details, covers, page previews, and interactive tags for browsing related works.
- Favorites browsing, with actions to add or remove favorites.
- Dark and light themes; English, Simplified Chinese, and Japanese; optional language filtering for Home and Search.
- Current account information and local image cache cleanup.

A full page reader is not implemented yet.

## Build and install

You need a Mac with Xcode 26 or later and an iPhone running iOS 17 or later. Sign in to Xcode with your Apple Account to install on a physical device, or use an iPhone simulator to try the app.

1. Download or clone this repository and open `NHV.xcodeproj` in Xcode.
2. Select the **NHV** target. Under **Signing & Capabilities**, enable **Automatically manage signing**, select your own **Team**, and change the **Bundle Identifier** to a unique identifier.
3. Connect your iPhone, trust the Mac, and enable Developer Mode when prompted. Select the **NHV** scheme and your device in Xcode, or choose an iPhone simulator.
4. Click **Run** (`⌘R`) to build and install. If your device asks you to trust the developer, complete that step in Settings before opening the app.
5. Enter your own nhentai API key on the sign-in screen. Your network must be able to reach the API and image services.

Apps signed with a free Personal Team typically expire after seven days and need to be installed again through Xcode.

## License

The project code is released under the [MIT License](LICENSE). Third-party names, logos, and content belong to their respective rights holders.

This project is not affiliated with nhentai and is intended for learning, research, and personal use. Follow the laws and age restrictions applicable in your country or region, comply with platform terms, and respect content copyrights.
