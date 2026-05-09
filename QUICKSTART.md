# Quick Start Guide - TDK Dictionary

## 🚀 Getting Started in 2 Minutes

### Step 1: Build the App

Open Terminal and run:

```bash
cd /Users/akif/Developer/Projects/manus/TDKDictionary
./build.sh
```

This will:
- Compile the Swift code
- Create a standalone `TDKDictionary.app` bundle

### Step 2: Run the App

```bash
open TDKDictionary.app
```

The app will launch and appear in your menubar (top-right corner) with a 📖 icon.

### Step 3: Start Using It

1. **Click the 📖 icon** in the menubar
2. **Type a Turkish word** (e.g., "yazılım", "bilgisayar", "kitap")
3. **Press Enter** or wait for results
4. **View meanings, examples, and word properties**

### Keyboard Shortcut

Press **`⌥⇧D`** (Option+Shift+D) anytime to toggle the search window open/closed.

---

## 📦 Installation (Optional)

To keep the app permanently in your Applications folder:

```bash
cp -r TDKDictionary.app /Applications/
```

Then you can launch it from Spotlight (`Cmd+Space` → type "TDK Dictionary").

---

## 🔧 Troubleshooting

### "App is damaged and can't be opened"

Run this command:

```bash
sudo xattr -rd com.apple.quarantine /Applications/TDKDictionary.app
```

### Global shortcut not working

1. Go to **System Preferences** → **Security & Privacy** → **Accessibility**
2. Add `TDKDictionary` to the list
3. Restart the app

### No results when searching

- Check your internet connection
- Try a different word
- The TDK API might be temporarily unavailable

---

## 🎨 Customizing the Shortcut

To change the keyboard shortcut from `⌥⇧D` to something else:

1. Open `Sources/TDKDictionary/TDKDictionaryApp.swift`
2. Find the `setupGlobalShortcut()` method
3. Change `keyCode` and `modifiers` to your preference
4. Rebuild with `./build.sh`

Common key codes:
- `2` = D
- `0` = A
- `11` = B
- `8` = C
- `1` = S

Modifiers:
- `.option` = ⌥
- `.shift` = ⇧
- `.command` = ⌘
- `.control` = ⌃

Example for `⌘⌥S`:
```swift
let keyCode: UInt16 = 1  // S
let modifiers: NSEvent.ModifierFlags = [.command, .option]
```

---

## 📚 Features

✅ **Menubar App** - Always accessible, never clutters your screen
✅ **Global Hotkey** - Open instantly from anywhere
✅ **Real-time Search** - Query the official TDK dictionary
✅ **Rich Results** - Meanings, examples, word types, compound words
✅ **Native macOS** - Built with SwiftUI for perfect integration
✅ **No Configuration** - Works out of the box

---

## 💡 Tips

- The app automatically closes when you click outside the search window
- Compound words are shown at the bottom of each entry
- Examples are limited to 2 per meaning to keep the UI clean
- The app uses the official TDK API (no scraping)

---

## 🆘 Need Help?

Check the full README.md for more detailed information about building and customizing the app.
