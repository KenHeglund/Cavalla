/*===========================================================================
 AppDelegate.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Cocoa

/*==========================================================================*/

@NSApplicationMain

/*==========================================================================*/
class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDelegate {
    
    static let openManagerButtonTitle = "Open HIDManager"
    static let closeManagerButtonTitle = "Close HIDManager"
    
    @objc dynamic var hidManager: CAVHIDManager? = nil
    @objc dynamic var openCloseManagerButtonTitle = AppDelegate.openManagerButtonTitle
    @objc dynamic var addressString = ""
    
    private var inhibitTableSelectionChange = false
    private var eventViewAttributes: [NSAttributedString.Key : Any] = [:]
    
    @IBOutlet var window: NSWindow? = nil
    @IBOutlet var eventView: NSTextView? = nil
    @IBOutlet var deviceArrayController: NSArrayController? = nil
    @IBOutlet var elementArrayController: NSArrayController? = nil
    
    @objc dynamic var deviceSelectionIndexes: IndexSet = IndexSet() {
        
        didSet {
            
            guard let arrangedObjects = self.deviceArrayController?.arrangedObjects as? [CAVHIDDevice] else { return }
            
            for index in 0..<arrangedObjects.count {
                
                if self.deviceSelectionIndexes.contains( index ) == false {
                    arrangedObjects[index].dequeueAllElements()
                }
            }
        }
    }
    
    // MARK: -
    
    /*==========================================================================*/
    override init() {
        ValueTransformer.setValueTransformer( IsNotZeroTransformer(), forName: IsNotZeroTransformer.name )
    }
    
    // MARK: - NSNibAwaking implementation
    
    /*==========================================================================*/
    override func awakeFromNib() {
        
        let deviceSortDescriptor = NSSortDescriptor( key: CAVHIDDevice.longProductNameKey, ascending: true, comparator: {
            ($0 as AnyObject).localizedCaseInsensitiveCompare( $1 as! String )
        })
        
        self.deviceArrayController?.sortDescriptors = [ deviceSortDescriptor ]
        
        NotificationCenter.default.addObserver( self, selector: #selector(AppDelegate.eventNotification(_:)), name: CAVHIDDevice.didReceiveValueNotification, object: nil )
        
        let font = NSFont( name: "Courier New", size: 13.0 ) ?? NSFont.userFixedPitchFont( ofSize: 13.0 )!
        
        self.eventViewAttributes = [ .font : font ]
    }
    
    // MARK: - IBAction implementations
    
    /*==========================================================================*/
    @IBAction func doOpenCloseHidManager( _ sender: AnyObject? ) {
        
        if let hidManager = self.hidManager {
            
            hidManager.close()
            self.hidManager = nil
            
            self.openCloseManagerButtonTitle = AppDelegate.openManagerButtonTitle
            self.addressString = ""
        }
        else {
            
            let hidManager = CAVHIDManager()
            let status = hidManager.open()
            
            if status != kIOReturnSuccess {
                self.addressString = String( format: "Error: 0x%08X (%d)", status, status )
            }
            
            self.openCloseManagerButtonTitle = AppDelegate.closeManagerButtonTitle
            self.hidManager = hidManager
        }
    }

    /*==========================================================================*/
    @IBAction func doChangeElementTableControl( _ sender: AnyObject? ) {
        
        guard let tableView = sender as? NSTableView else { return }
        guard let arrangedObjects = self.elementArrayController?.arrangedObjects as? NSArray else { return }
        
        let clickedColumn = tableView.clickedColumn
        let key = tableView.tableColumns[clickedColumn].identifier
        
        let clickedRow = tableView.clickedRow
        let newValue = (arrangedObjects[clickedRow] as AnyObject).value( forKey: key.rawValue )
        
        let selectedObjects = arrangedObjects.objects( at: tableView.selectedRowIndexes )
        for object in selectedObjects {
            (object as AnyObject).setValue( newValue, forKey: key.rawValue )
        }
        
        self.inhibitTableSelectionChange = true
    }
    
    /*==========================================================================*/
    @IBAction func doEnableAllElements( _ sender: AnyObject? ) {
        
        guard let elementArray = self.elementArrayController?.arrangedObjects as? [CAVHIDElement] else {
            return
        }
        
        elementArray.forEach({ $0.enabled = true })
    }
    
    /*==========================================================================*/
    @IBAction func doDisableAllElements( _ sender: AnyObject? ) {
        
        guard let elementArray = self.elementArrayController?.arrangedObjects as? [CAVHIDElement] else {
            return
        }
        
        elementArray.forEach({ $0.enabled = false })
    }
    
    /*==========================================================================*/
    @IBAction func doClearEvents( _ sender: AnyObject? ) {
        self.eventView?.string = ""
    }
    
    // MARK: - NSTableViewDelegate implementation
    
    /*==========================================================================*/
    func selectionShouldChange( in tableView: NSTableView ) -> Bool {
        
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
    
    /*==========================================================================*/
    @objc func eventNotification( _ notification: Notification ) {
        
        guard let stringValue = notification.userInfo?[CAVHIDDevice.valueAsStringKey] as? String else { return }
        guard let textStorage = self.eventView?.textStorage else { return }

        let attributedString = NSAttributedString( string: stringValue + "\n", attributes: self.eventViewAttributes )
        textStorage.append( attributedString )
        
        let lastCharacter = NSRange( location: ( textStorage.length - 1 ), length: 1 )
        self.eventView?.scrollRangeToVisible( lastCharacter )
    }
}
