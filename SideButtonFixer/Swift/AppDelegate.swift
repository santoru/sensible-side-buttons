// AppDelegate.swift — Core event tap logic, TCC monitoring, version check, global hotkey
// GPLv2

import Cocoa
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    fileprivate var tap: CFMachPort?
    private var tccTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?

    // Published state for SwiftUI menu
    @objc dynamic var isEnabled = true
    @objc dynamic var triggerOnMouseDown = true
    @objc dynamic var swapButtons = false

    // Gesture synthesis feedback
    private var flashWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaults()
        loadPreferences()
        checkMacOSVersion()
        setupStatusItem()
        setupMenu()
        registerGlobalHotKey()

        if UserDefaults.standard.bool(forKey: "SBFWasEnabled") {
            startTap()
        }
        startTCCTimer()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.isVisible = true
        return false
    }

    // MARK: - Defaults

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "SBFWasEnabled": true,
            "SBFMouseDown": true,
            "SBFSwapButtons": false
        ])
    }

    private func loadPreferences() {
        triggerOnMouseDown = UserDefaults.standard.bool(forKey: "SBFMouseDown")
        swapButtons = UserDefaults.standard.bool(forKey: "SBFSwapButtons")
    }

    // MARK: - macOS Version Check (#8)

    private func checkMacOSVersion() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        // Tested on 10.13–15.x; warn on anything newer
        let maxTestedMajor = 15
        if version.majorVersion > maxTestedMajor {
            let alert = NSAlert()
            alert.messageText = "Untested macOS Version"
            alert.informativeText = "SensibleSideButtons has not been tested on macOS \(version.majorVersion). It may not work correctly. Proceed with caution."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Quit")
            if alert.runModal() == .alertSecondButtonReturn {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Status Item & Menu (#4, #5, #10, #11, #13)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enableItem.setAccessibilityLabel("Toggle side button swipe enabled")
        menu.addItem(enableItem)
        menu.addItem(.separator())

        let mouseDownItem = NSMenuItem(title: "Trigger on Mouse Down", action: #selector(toggleMouseDown), keyEquivalent: "")
        mouseDownItem.setAccessibilityLabel("Toggle trigger on mouse down or up")
        menu.addItem(mouseDownItem)

        let swapItem = NSMenuItem(title: "Swap Buttons", action: #selector(toggleSwap), keyEquivalent: "")
        swapItem.setAccessibilityLabel("Swap back and forward button assignment")
        menu.addItem(swapItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(hideMenuBarIcon), keyEquivalent: "")
        hideItem.setAccessibilityLabel("Hide menu bar icon, use Command-Shift-B to show again")
        menu.addItem(hideItem)

        let hideInfo = NSMenuItem(title: "⌘⇧B to show again", action: nil, keyEquivalent: "")
        hideInfo.isEnabled = false
        menu.addItem(hideInfo)

        menu.addItem(.separator())

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let aboutItem = NSMenuItem(title: "SensibleSideButtons \(version)", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        menu.addItem(aboutItem)

        let websiteItem = NSMenuItem(title: "Website", action: #selector(openWebsite), keyEquivalent: "")
        websiteItem.setAccessibilityLabel("Open SensibleSideButtons website")
        menu.addItem(websiteItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.setAccessibilityLabel("Quit SensibleSideButtons")
        menu.addItem(quitItem)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateIcon() {
        let imageName = (tap != nil) ? "MenuIcon" : "MenuIconDisabled"
        statusItem?.button?.image = NSImage(named: imageName)
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        // Enabled
        if let item = menu.items.first(where: { $0.title == "Enabled" }) {
            item.state = (tap != nil) ? .on : .off
        }
        // Trigger on Mouse Down
        if let item = menu.items.first(where: { $0.title == "Trigger on Mouse Down" }) {
            item.state = triggerOnMouseDown ? .on : .off
        }
        // Swap Buttons
        if let item = menu.items.first(where: { $0.title == "Swap Buttons" }) {
            item.state = swapButtons ? .on : .off
        }
    }

    // MARK: - Failure Feedback (#3)

    func flashIconOnFailure() {
        flashWorkItem?.cancel()
        statusItem?.button?.image = NSImage(named: "MenuIconDisabled")
        let work = DispatchWorkItem { [weak self] in
            self?.updateIcon()
        }
        flashWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    // MARK: - Event Tap

    func startTap() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else {
            promptAccessibility()
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.otherMouseUp.rawValue) | CGEventMask(1 << CGEventType.otherMouseDown.rawValue),
            callback: mouseCallback,
            userInfo: refcon
        )

        guard let tap = tap else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        UserDefaults.standard.set(true, forKey: "SBFWasEnabled")
        updateIcon()
    }

    func stopTap() {
        guard let t = tap else { return }
        CGEvent.tapEnable(tap: t, enable: false)
        CFMachPortInvalidate(t)
        tap = nil
        UserDefaults.standard.set(false, forKey: "SBFWasEnabled")
        updateIcon()
    }

    private func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - TCC Monitoring (#11)

    private func startTCCTimer() {
        tccTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !AXIsProcessTrusted() && self.tap != nil {
                self.stopTap()
            }
        }
    }

    // MARK: - Global Hotkey (#9) — ⌘⇧B

    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x53534231), // "SSB1"
                                      id: 1)
        var ref: EventHotKeyRef?
        // ⌘⇧B = kVK_ANSI_B (11), modifiers: cmdKey | shiftKey
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_B),
                                         UInt32(cmdKey | shiftKey),
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        if status == noErr {
            hotKeyRef = ref
        }

        // Install Carbon event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    fileprivate func toggleMenuBarVisibility() {
        statusItem.isVisible.toggle()
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        if tap != nil { stopTap() } else { startTap() }
        refreshMenu()
    }

    @objc private func toggleMouseDown() {
        triggerOnMouseDown.toggle()
        UserDefaults.standard.set(triggerOnMouseDown, forKey: "SBFMouseDown")
        refreshMenu()
    }

    @objc private func toggleSwap() {
        swapButtons.toggle()
        UserDefaults.standard.set(swapButtons, forKey: "SBFSwapButtons")
        refreshMenu()
    }

    @objc private func hideMenuBarIcon() {
        statusItem.isVisible = false
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://sensible-side-buttons.archagon.net")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }
}

// MARK: - C Callbacks

private func mouseCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

    // Re-enable tap if OS disabled it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = delegate.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
    let isDown = type == .otherMouseDown

    let backButton: Int64 = delegate.swapButtons ? 4 : 3
    let forwardButton: Int64 = delegate.swapButtons ? 3 : 4

    if buttonNumber == backButton {
        if (delegate.triggerOnMouseDown && isDown) || (!delegate.triggerOnMouseDown && !isDown) {
            if !GestureSynthesizer.fakeSwipe(.left) {
                delegate.flashIconOnFailure()
                return Unmanaged.passUnretained(event)
            }
        }
        return nil
    } else if buttonNumber == forwardButton {
        if (delegate.triggerOnMouseDown && isDown) || (!delegate.triggerOnMouseDown && !isDown) {
            if !GestureSynthesizer.fakeSwipe(.right) {
                delegate.flashIconOnFailure()
                return Unmanaged.passUnretained(event)
            }
        }
        return nil
    }

    return Unmanaged.passUnretained(event)
}

private func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return OSStatus(eventNotHandledErr) }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    delegate.toggleMenuBarVisibility()
    return noErr
}
