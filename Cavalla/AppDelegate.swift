/*===========================================================================
 AppDelegate.swift
 Cavalla
 Copyright (c) 2015-2019 Ken Heglund. All rights reserved.
===========================================================================*/

import Cocoa

@NSApplicationMain

/// Application delegate.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// The title of the Open/Close button when a HID Manager is closed.
    static let openManagerButtonTitle = NSLocalizedString("Open HIDManager", comment: "Title of Open/Close button when the HIDManager is closed")
    
    /// The title of the Open/Close button when a HID Manager is open.
    static let closeManagerButtonTitle = NSLocalizedString("Close HIDManager", comment: "Title of Open/Close button when the HIDManager is open")
    
    /// The current HID Manager instance.
    @objc dynamic var hidManager: CAVHIDManager? = nil
    
    /// The current title of the Open/Close button.
    @objc dynamic var openCloseManagerButtonTitle = AppDelegate.openManagerButtonTitle
    
    /// The status reported when failing to open  a HID Manager.
    @objc dynamic var statusString = ""
    
    /// When `true`, a table selection change should not be allowed.
    private var inhibitTableSelectionChange = false
    
    /// Attributed string attributes for the event window.
    private var eventViewAttributes: [NSAttributedString.Key : Any] = [:]
    
    /// The main application window.
    @IBOutlet private var window: NSWindow? = nil
    
    /// The view that contains event descriptions.
    @IBOutlet private var eventView: NSTextView? = nil
    
    /// An array controller for devices.
    @IBOutlet private var deviceArrayController: NSArrayController? = nil
    
    /// An array controller for elements.
    @IBOutlet private var elementArrayController: NSArrayController? = nil
    
    /// The index of the selected device.
    @objc dynamic var deviceSelectionIndexes = IndexSet() {
        
        didSet {
            
            guard let arrangedObjects = self.deviceArrayController?.arrangedObjects as? [CAVHIDDevice] else {
                assertionFailure()
                return
            }
            
            for index in 0..<arrangedObjects.count {
                
                if self.deviceSelectionIndexes.contains(index) == false {
                    arrangedObjects[index].dequeueAllElements()
                }
            }
        }
    }
    
    
    // MARK: -
    
    /// Initializer.
    override init() {
        ValueTransformer.setValueTransformer(IsNotZeroTransformer(), forName: IsNotZeroTransformer.name)
    }
    
    
    // MARK: - NSNibAwaking implementation
    
    /// Called when the application's nib loaded.
    override func awakeFromNib() {
        
        super.awakeFromNib()
        
        let deviceSortDescriptor = NSSortDescriptor(key: CAVHIDDevice.longProductNameKey, ascending: true, comparator: {
            guard let secondString = $1 as? String else {
                assertionFailure()
                return .orderedSame
            }
            return ($0 as AnyObject).localizedCaseInsensitiveCompare(secondString)
        })
        
        self.deviceArrayController?.sortDescriptors = [deviceSortDescriptor]
        
        NotificationCenter.default.addObserver(self, selector: #selector(AppDelegate.eventNotification(_:)), name: CAVHIDDevice.didReceiveValueNotification, object: nil)
        
        let font = NSFont(name: "Courier New", size: 13.0) ?? NSFont.userFixedPitchFont(ofSize: 13.0) ?? NSFont.systemFont(ofSize: 13.0)
        
        let color: NSColor
        if #available(macOS 10.10, *) {
           color = NSColor.labelColor
        }
        else {
           color = NSColor.black
        }

        self.eventViewAttributes = [
           .font : font,
           .foregroundColor : color,
        ]
    }
    
    
    // MARK: - IBAction implementations
    
    /// Open a HID Manager in one is not open, close the HID Manager if there is one open.
    @IBAction private func doOpenCloseHidManager(_ sender: AnyObject?) {
        
        if let hidManager = self.hidManager {
            
            hidManager.close()
            self.hidManager = nil
            
            self.openCloseManagerButtonTitle = AppDelegate.openManagerButtonTitle
            self.statusString = ""
        }
        else {
            
            let hidManager = CAVHIDManager()
            let status = hidManager.open()
            
            if status != kIOReturnSuccess {
                self.statusString = String(format: "Error: 0x%08X (%d)", status, status)
            }
            
            self.openCloseManagerButtonTitle = AppDelegate.closeManagerButtonTitle
            self.hidManager = hidManager
        }
    }
    
    /// A control in the element table was changed.
    @IBAction private func doChangeElementTableControl(_ sender: AnyObject?) {
        
        guard let tableView = sender as? NSTableView else {
            assertionFailure()
            return
        }
        guard let arrangedObjects = self.elementArrayController?.arrangedObjects as? NSArray else {
            assertionFailure()
            return
        }
        
        let clickedColumn = tableView.clickedColumn
        let key = tableView.tableColumns[clickedColumn].identifier
        
        let clickedRow = tableView.clickedRow
        let newValue = (arrangedObjects[clickedRow] as AnyObject).value(forKey: key.rawValue)
        
        let selectedObjects = arrangedObjects.objects(at: tableView.selectedRowIndexes)
        for object in selectedObjects {
            (object as AnyObject).setValue(newValue, forKey: key.rawValue)
        }
        
        self.inhibitTableSelectionChange = true
    }
    
    /// Enable all elements.
    @IBAction private func doEnableAllElements(_ sender: AnyObject?) {
        
        guard let elementArray = self.elementArrayController?.arrangedObjects as? [CAVHIDElement] else {
            assertionFailure()
            return
        }
        
        elementArray.forEach({ $0.isEnabled = true })
    }
    
    /// Disable all elements.
    @IBAction private func doDisableAllElements(_ sender: AnyObject?) {
        
        guard let elementArray = self.elementArrayController?.arrangedObjects as? [CAVHIDElement] else {
            assertionFailure()
            return
        }
        
        elementArray.forEach({ $0.isEnabled = false })
    }
    
    /// Clear the event view.
    @IBAction private func doClearEvents(_ sender: AnyObject?) {
        self.eventView?.string = ""
    }
    
    
    // MARK: - NSTableViewDelegate implementation
    
    /// Returns `true` if the selection should change in the element table.
    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        
        // After changing a cell in an NSTableView, a delayed message is sent to the table to change its selection to just the row containing the edited cell.  The following code defeats that selection change and allows all rows that were selected at the time of the value change to remain selected thereafter.  A table's selection belongs to the user, not AppKit.
        
        if RunLoop.current.currentMode == nil {
            return true
        }
        
        if self.inhibitTableSelectionChange == false {
            return true
        }
        
        self.inhibitTableSelectionChange = false
        
        return false
    }
    
    
    // MARK: - AppDelegate implementation
    
    /// Responds to a new event from the currently selected device.
    @objc func eventNotification(_ notification: Notification) {
        
        guard let stringValue = notification.userInfo?[CAVHIDDevice.valueAsStringKey] as? String else {
            assertionFailure()
            return
        }
        guard let textStorage = self.eventView?.textStorage else {
            assertionFailure()
            return
        }

        let attributedString = NSAttributedString(string: stringValue + "\n", attributes: self.eventViewAttributes)
        textStorage.append(attributedString)
        
        let lastCharacter = NSRange(location: (textStorage.length - 1), length: 1)
        self.eventView?.scrollRangeToVisible(lastCharacter)
    }
}
