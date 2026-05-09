# TDK Dictionary - macOS Menubar App

A lightweight, native macOS menubar application that provides instant access to Turkish word definitions from TDK Sözlük (Türk Dil Kurumu).

## Features

- **Menubar Integration**: Lives in your macOS menubar for quick access
- **Global Keyboard Shortcut**: Press `⌥⇧D` (Option+Shift+D) to open/close instantly
- **Real-time Search**: Query words from the official TDK dictionary
- **Rich Results**: Display meanings, examples, part of speech, and compound words
- **Native SwiftUI Interface**: Beautiful, responsive macOS design
- **No API Key Required**: Uses the public TDK API endpoint

## System Requirements

- macOS 12.0 or later
- Xcode 13.0 or later (for building)

## Building the App

### Option 1: Using Xcode

1. Open Terminal and navigate to the project directory:
   ```bash
   cd /path/to/TDKDictionary
   ```

2. Create an Xcode project:
   ```bash
   swift package generate-xcodeproj
   ```

3. Open the generated project:
   ```bash
   open TDKDictionary.xcodeproj
   ```

4. In Xcode:
   - Select the "TDKDictionary" scheme
   - Set the build target to "My Mac"
   - Press `Cmd+B` to build
   - Press `Cmd+R` to run

### Option 2: Using Swift Package Manager (Command Line)

1. Build the app:
   ```bash
   cd /path/to/TDKDictionary
   swift build -c release
   ```

2. Run the app:
   ```bash
   swift run -c release TDKDictionary
   ```

### Option 3: Create an App Bundle

To create a standalone `.app` bundle:

```bash
cd /path/to/TDKDictionary
swift build -c release
mkdir -p TDKDictionary.app/Contents/MacOS
mkdir -p TDKDictionary.app/Contents/Resources
cp .build/release/TDKDictionary TDKDictionary.app/Contents/MacOS/
cp Sources/TDKDictionary/Info.plist TDKDictionary.app/Contents/Info.plist
```

Then move `TDKDictionary.app` to `/Applications/`.

## Usage

1. **Launch the App**: Run the application (it will hide from the dock and appear in the menubar)
2. **Click the Menubar Icon**: Click the book icon (📖) in the top-right corner of your screen
3. **Search**: Type a Turkish word in the search field
4. **View Results**: See meanings, examples, and word properties instantly
5. **Global Shortcut**: Press `⌥⇧D` anytime to toggle the search window

## Architecture

### Main Components

- **TDKDictionaryApp.swift**: Application entry point, menubar setup, and global shortcut handling
- **SearchView.swift**: Main UI with search field and results display
- **TDKAPIClient.swift**: API client for querying the TDK endpoint

### API Integration

The app queries the public TDK API endpoint:
```
https://sozluk.gov.tr/gts?ara={word}
```

Response includes:
- Word definition and meaning
- Examples of usage
- Part of speech (noun, verb, adjective, etc.)
- Compound words
- Etymology information (when available)

## Keyboard Shortcut

The default global keyboard shortcut is **Option+Shift+D** (`⌥⇧D`).

To customize this, edit the `setupGlobalShortcut()` method in `TDKDictionaryApp.swift`:
- Change `keyCode` to your preferred key (find key codes [here](https://stackoverflow.com/questions/3202629/where-can-i-find-a-list-of-mac-virtual-key-codes))
- Modify `modifiers` to your preferred modifier keys

## Troubleshooting

### App doesn't appear in menubar
- Make sure the app is running (check Activity Monitor)
- The app uses `.accessory` activation policy, so it won't appear in the dock

### Global shortcut not working
- Check System Preferences > Security & Privacy > Accessibility to ensure the app has permission
- Try restarting the app

### Search results are empty
- Check your internet connection
- The TDK API might be temporarily unavailable

## Future Enhancements

- Search history
- Favorite words
- Dark mode support
- Keyboard navigation
- Word pronunciation
- Multiple dictionary sources

## License

This project is provided as-is for personal use.

## Credits

- TDK (Türk Dil Kurumu) for the public dictionary API
- Built with Swift and SwiftUI
