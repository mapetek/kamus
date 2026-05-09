import SwiftUI
import AppKit

@main
struct TDKDictionaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var eventMonitor: EventMonitor?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "TDK Dictionary")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: SearchView(popover: popover))
        popover?.behavior = .transient
        
        // Setup global keyboard shortcut (⌥⇧D)
        setupGlobalShortcut()
        
        // Setup event monitor to close popover when clicking outside
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover(event)
            }
        }
        eventMonitor?.start()
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func closePopover(_ sender: Any?) {
        popover?.performClose(sender)
    }
    
    func setupGlobalShortcut() {
        // Register global keyboard shortcut: Option+Shift+D
        let keyCode: UInt16 = 2  // 'D' key
        let modifiers: NSEvent.ModifierFlags = [.option, .shift]
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && event.modifierFlags.contains(modifiers) {
                self?.togglePopover(nil)
            }
        }
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
