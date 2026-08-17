import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics

extension Notification.Name {
    static let shortcutChanged = Notification.Name("Kamus.shortcutChanged")
}

final class GlobalHotKeyListener {
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var expectedKeyCode: UInt16 = 0
    private var requiredFlags: CGEventFlags = []
    var onTrigger: (() -> Void)?

    /// Event tap kurulu mu; izin sonradan verildiğinde yeniden kurmak için kullanılır.
    var isRunning: Bool { eventTap != nil }

    func start(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        stop()
        
        guard CGPreflightListenEventAccess() else { return false }
        
        expectedKeyCode = keyCode
        requiredFlags = cgFlags(from: modifiers)
        
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: GlobalHotKeyListener.eventTapCallback,
            userInfo: userInfo
        ) else { return false }
        
        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    
    func stop() {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }
        eventTap = nil
    }
    
    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let listener = Unmanaged<GlobalHotKeyListener>.fromOpaque(userInfo).takeUnretainedValue()
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = listener.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        if type == .keyDown {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
            if keyCode == listener.expectedKeyCode && flags == listener.requiredFlags {
                listener.onTrigger?()
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}

enum InputMonitoringPermission {
    static func isTrusted() -> Bool {
        CGPreflightListenEventAccess()
    }
    
    static func request() -> Bool {
        CGRequestListenEventAccess()
    }
    
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum KeyCodeFormatter {
    static func displayString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "#\(keyCode)"
        }
    }
}

enum ShortcutDefaults {
    static let keyCode: UInt16 = 37
    static let modifiers: NSEvent.ModifierFlags = [.control, .command]
    
    static var keyCodeInt: Int { Int(keyCode) }
    static var modifiersInt: Int { Int(modifiers.rawValue) }
}

final class KeyRecorderView: NSView {
    var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }
    
    var onKey: ((UInt16, NSEvent.ModifierFlags) -> Void)?
    var onCancel: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        if event.keyCode == 53 {
            isRecording = false
            onCancel?()
            return
        }
        
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).intersection(relevant)
        guard !mods.isEmpty else { return }
        
        isRecording = false
        onKey?(event.keyCode, mods)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}

struct KeyRecorderField: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCommit: (UInt16, NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.onKey = { keyCode, mods in
            onCommit(keyCode, mods)
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        view.onCancel = {
            onCancel()
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyRecorderView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

/// Sistem butonlarının bombeli/gölgeli bezeline karşılık düz, gölgesiz buton stili.
struct SoftButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, prominent: prominent)
    }

    private struct Surface: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(prominent ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(prominent ? 0 : 0.8),
                                      lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }

        private var fill: Color {
            if prominent {
                return Color.accentColor.opacity(configuration.isPressed ? 0.75 : (isHovering ? 0.9 : 1))
            }
            if configuration.isPressed { return Color.primary.opacity(0.16) }
            if isHovering { return Color.primary.opacity(0.10) }
            return Color.primary.opacity(0.06)
        }
    }
}

struct SettingsView: View {
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode: Int = ShortcutDefaults.keyCodeInt
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = ShortcutDefaults.modifiersInt
    @State private var isRecording = false
    @State private var isPermissionGranted = InputMonitoringPermission.isTrusted()
    @State private var showsStaleGrantHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Kısayol") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        recorderField

                        Button(isRecording ? "Dinleniyor…" : "Kısayol Ata") {
                            isRecording.toggle()
                        }
                        .buttonStyle(SoftButtonStyle(prominent: isRecording))

                        Button("Sıfırla", action: resetToDefault)
                            .buttonStyle(SoftButtonStyle())
                    }

                    Text("En az bir modifier (⌃ ⌥ ⇧ ⌘) içeren kombinasyonlar kabul edilir.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            section("Global Kısayol İzni") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isPermissionGranted ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(isPermissionGranted ? "Input Monitoring izni verildi"
                                                 : "Input Monitoring izni gerekli")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        if !isPermissionGranted {
                            Button("İzin İste") {
                                _ = InputMonitoringPermission.request()
                                refreshPermission()
                                showsStaleGrantHint = !isPermissionGranted
                            }
                            .buttonStyle(SoftButtonStyle(prominent: true))
                        }

                        Button("Ayarları Aç") {
                            InputMonitoringPermission.openSystemSettings()
                        }
                        .buttonStyle(SoftButtonStyle())
                    }

                    if showsStaleGrantHint && !isPermissionGranted {
                        Text("Sistem Ayarları'nda anahtar zaten açıksa izin kaydı eskimiş demektir: "
                             + "listeden Kamus'u “−” ile kaldırıp uygulamayı yeniden başlatın.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: refreshPermission)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Kullanıcı System Settings'ten dönünce durum kendiliğinden tazelensin.
            refreshPermission()
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.6)

            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                )
        }
    }

    private var recorderField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? Color.accentColor
                                                  : Color(nsColor: .separatorColor),
                                      lineWidth: isRecording ? 1.5 : 1)
                )

            Text(isRecording ? "Tuşlara bas…" : shortcutDisplay)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isRecording ? .secondary : .primary)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 26)
        .overlay(
            KeyRecorderField(
                isRecording: $isRecording,
                onCommit: { keyCode, mods in
                    shortcutKeyCode = Int(keyCode)
                    shortcutModifiers = Int(mods.rawValue)
                    NotificationCenter.default.post(name: .shortcutChanged, object: nil)
                },
                onCancel: {}
            )
        )
        .animation(.easeOut(duration: 0.12), value: isRecording)
    }

    private func refreshPermission() {
        isPermissionGranted = InputMonitoringPermission.isTrusted()
    }

    private var shortcutDisplay: String {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(shortcutModifiers))
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option) { s += "⌥" }
        if mods.contains(.shift) { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        s += KeyCodeFormatter.displayString(for: UInt16(shortcutKeyCode))
        return s
    }
    
    private func resetToDefault() {
        shortcutKeyCode = ShortcutDefaults.keyCodeInt
        shortcutModifiers = ShortcutDefaults.modifiersInt
        NotificationCenter.default.post(name: .shortcutChanged, object: nil)
    }
}

@main
struct KamusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 460)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventMonitor: EventMonitor?
    private let searchViewModel = SearchViewModel()
    private let popoverSize = NSSize(width: 400, height: 500)
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var lastHotkeyFire: TimeInterval = 0
    private var lastPopoverShow: TimeInterval = 0
    private var searchWindow: NSWindow?
    private let globalHotKeyListener = GlobalHotKeyListener()
    // Sistem izin diyaloğu uygulama başına en fazla bir kez gösterilsin;
    // sonrasında yalnızca popover içindeki yönlendirme mesajı görünür.
    private var didPromptForAccessibility = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Kâmus")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        let hosting = NSHostingController(
            rootView: SearchView(
                viewModel: searchViewModel,
                popover: popover
            )
        )
        hosting.view.frame = NSRect(origin: .zero, size: popoverSize)
        hosting.preferredContentSize = popoverSize
        popover?.contentViewController = hosting
        popover?.behavior = .transient
        popover?.contentSize = popoverSize
        
        NotificationCenter.default.addObserver(self, selector: #selector(reconfigureShortcut), name: .shortcutChanged, object: nil)
        
        // Setup global keyboard shortcut
        setupGlobalShortcut()
        
        // Setup event monitor to close popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, let popover = self.popover, popover.isShown else { return }
                if self.shouldClosePopover(popover: popover) {
                    self.closePopover(event)
                }
            }
        }
        eventMonitor?.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        
        globalHotKeyListener.stop()
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if let popover = popover {
            if popover.isShown {
                closePopover(sender)
            } else {
                showPopover(sender)
            }
        }
    }
    
    func showPopover(_ sender: Any?) {
        if let popover = popover, let button = statusItem?.button {
            let selectedOutcome = SelectedTextReader.readSelectedWord(promptIfNeeded: !didPromptForAccessibility)
            if case .notTrusted = selectedOutcome {
                didPromptForAccessibility = true
            }
            lastPopoverShow = Date().timeIntervalSinceReferenceDate
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            ensurePopoverVisible(popover, button: button, attempt: 0)
            
            switch selectedOutcome {
            case .text(let selected):
                searchViewModel.setQueryAndSearch(selected)
            case .notTrusted:
                searchViewModel.errorMessage = "Seçili kelimeyi alabilmem için Erişilebilirlik izni gerekiyor. System Settings → Privacy & Security → Accessibility."
            case .noSelection, .unsupported:
                break
            }
            
            if case .text = selectedOutcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let self else { return }
                    if self.isPopoverActuallyVisible(popover) { return }
                    self.showSearchWindow()
                }
            }
        }
    }
    
    private func ensurePopoverVisible(_ popover: NSPopover, button: NSStatusBarButton, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            
            if popover.isShown {
                popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                return
            }
            
            if attempt < 2 {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                self.ensurePopoverVisible(popover, button: button, attempt: attempt + 1)
                return
            }
            
            self.showSearchWindow()
        }
    }
    
    private func isPopoverActuallyVisible(_ popover: NSPopover) -> Bool {
        guard popover.isShown else { return false }
        guard let window = popover.contentViewController?.view.window else { return false }
        return window.isVisible
    }
    
    private func shouldClosePopover(popover: NSPopover) -> Bool {
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastPopoverShow < 0.35 {
            return false
        }
        
        guard let window = popover.contentViewController?.view.window else { return true }
        let mouse = NSEvent.mouseLocation
        return !window.frame.contains(mouse)
    }
    
    func showSearchWindow() {
        if searchWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: popoverSize.width, height: popoverSize.height),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Kâmus"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = NSHostingController(
                rootView: SearchView(
                    viewModel: searchViewModel,
                    popover: nil
                )
            )
            searchWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        searchWindow?.makeKeyAndOrderFront(nil)
    }
    
    func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
    }
    
    func setupGlobalShortcut() {
        removeShortcutMonitors()

        let keyCode = UInt16(UserDefaults.standard.object(forKey: "shortcutKeyCode") as? Int ?? ShortcutDefaults.keyCodeInt)
        let requiredRaw = UserDefaults.standard.object(forKey: "shortcutModifiers") as? Int ?? ShortcutDefaults.modifiersInt
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let required = NSEvent.ModifierFlags(rawValue: UInt(requiredRaw)).intersection(relevant)

        globalHotKeyListener.onTrigger = { [weak self] in
            Task { @MainActor in
                self?.togglePopover(nil)
            }
        }
        if globalHotKeyListener.start(keyCode: keyCode, modifiers: required) {
            return
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.matchesShortcut(event: event, keyCode: keyCode, modifiers: required) {
                Task { @MainActor in
                    self.togglePopover(nil)
                }
            }
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.matchesShortcut(event: event, keyCode: keyCode, modifiers: required) {
                Task { @MainActor in
                    self.togglePopover(nil)
                }
                return nil
            }
            return event
        }
    }
    
    private func matchesShortcut(event: NSEvent, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard !event.isARepeat else { return false }
        guard event.keyCode == keyCode else { return false }
        let current = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastHotkeyFire < 0.25 {
            return false
        }
        lastHotkeyFire = now
        
        return current.intersection(relevant) == modifiers.intersection(relevant)
    }
    
    private func removeShortcutMonitors() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }
    
    @objc private func reconfigureShortcut() {
        setupGlobalShortcut()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Input Monitoring izni uygulama çalışırken verilmiş olabilir; o durumda
        // başlangıçta kurulamayan event tap'i yeniden kurmayı dene. Aksi hâlde
        // kısayol, uygulama yeniden başlatılana kadar zayıf NSEvent yolunda kalır.
        if !globalHotKeyListener.isRunning && InputMonitoringPermission.isTrusted() {
            setupGlobalShortcut()
        }
    }
}

enum SelectedTextReader {
    enum Outcome {
        case text(String)
        case notTrusted
        case noSelection
        case unsupported
    }
    
    static func readSelectedWord(promptIfNeeded: Bool) -> Outcome {
        guard AccessibilityPermission.isTrusted(promptIfNeeded: promptIfNeeded) else { return .notTrusted }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        
        if let focusedElement = focusedUIElement(from: systemWideElement) {
            return readSelected(from: focusedElement) ?? .noSelection
        }
        
        var focused: AnyObject?
        let focusedError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard focusedError == .success, let focused else { return .unsupported }
        let focusedRef = focused as CFTypeRef
        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return .unsupported }
        let focusedElement = focused as! AXUIElement
        
        return readSelected(from: focusedElement) ?? .noSelection
    }
    
    private static func focusedUIElement(from systemWideElement: AXUIElement) -> AXUIElement? {
        var focusedApp: AnyObject?
        let appError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appError == .success, let focusedApp else { return nil }
        let focusedAppRef = focusedApp as CFTypeRef
        guard CFGetTypeID(focusedAppRef) == AXUIElementGetTypeID() else { return nil }
        let focusedAppElement = focusedApp as! AXUIElement
        
        var focusedUI: AnyObject?
        let uiError = AXUIElementCopyAttributeValue(
            focusedAppElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUI
        )
        guard uiError == .success, let focusedUI else { return nil }
        let focusedUIRef = focusedUI as CFTypeRef
        guard CFGetTypeID(focusedUIRef) == AXUIElementGetTypeID() else { return nil }
        return (focusedUI as! AXUIElement)
    }
    
    private static func readSelected(from element: AXUIElement) -> Outcome? {
        if let direct = copyAttributeString(element, attribute: kAXSelectedTextAttribute) {
            if let sanitized = sanitize(direct) {
                return .text(sanitized)
            }
        }
        
        let valueString = copyAttributeString(element, attribute: kAXValueAttribute)
        if let valueString,
           let range = copyAttributeRange(element, attribute: kAXSelectedTextRangeAttribute) {
            let nsString = valueString as NSString
            let length = nsString.length
            let location = range.location
            let selectedLength = range.length
            if location >= 0, selectedLength > 0, location + selectedLength <= length {
                let selected = nsString.substring(with: NSRange(location: location, length: selectedLength))
                if let sanitized = sanitize(selected) {
                    return .text(sanitized)
                }
            }
        }
        
        if let valueString,
           let sanitized = sanitize(valueString),
           !sanitized.isEmpty {
            return .text(sanitized)
        }
        
        return nil
    }
    
    private static func copyAttributeString(_ element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? String
    }
    
    private static func copyAttributeRange(_ element: AXUIElement, attribute: String) -> CFRange? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        guard let value else { return nil }
        let valueRef = value as CFTypeRef
        guard CFGetTypeID(valueRef) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
    
    private static func sanitize(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let firstToken = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first.map(String.init) ?? trimmed
        let cleaned = firstToken.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
        return cleaned.isEmpty ? nil : cleaned
    }
}

enum AccessibilityPermission {
    static func isTrusted(promptIfNeeded: Bool) -> Bool {
        if !promptIfNeeded {
            return AXIsProcessTrusted()
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

// Event monitor for detecting clicks outside popover
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
