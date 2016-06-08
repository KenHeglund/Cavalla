/*===========================================================================
 AppDelegate.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Cocoa

/*==========================================================================*/

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDelegate {
    
    static let OpenManagerButtonTitle = "Open HIDManager"
    static let CloseManagerButtonTitle = "Close HIDManager"
    
    dynamic var hidManager: CAVHIDManager? = nil
    dynamic var openCloseManagerButtonTitle = AppDelegate.OpenManagerButtonTitle
    dynamic var addressString = ""
    
    private var inhibitTableSelectionChange = false
    private var eventViewAttributes: [String:AnyObject] = [:]
    
    @IBOutlet var window: NSWindow? = nil
    @IBOutlet var eventView: NSTextView? = nil
    @IBOutlet var deviceArrayController: NSArrayController? = nil
    @IBOutlet var elementArrayController: NSArrayController? = nil
    
    dynamic var deviceSelectionIndexes: NSIndexSet = NSIndexSet() {
        
        didSet {
            
            guard let arrangedObjects = self.deviceArrayController?.arrangedObjects as? [CAVHIDDevice] else { return }
            
            for index in 0..<arrangedObjects.count {
                
                if self.deviceSelectionIndexes.containsIndex( index ) == false {
                    arrangedObjects[index].dequeueAllElements()
                }
            }
        }
    }
    
    // MARK: - NSNibAwaking implementation
    
    /*==========================================================================*/
    override func awakeFromNib() {
        
        let deviceSortDescriptor = NSSortDescriptor( key: CAVHIDDeviceLongProductNameKey, ascending: true, comparator: {
            $0.localizedCaseInsensitiveCompare( $1 as! String )
        })
        
        self.deviceArrayController?.sortDescriptors = [ deviceSortDescriptor ]
        
        NSNotificationCenter.defaultCenter().addObserver( self, selector: #selector(AppDelegate.eventNotification(_:)), name: CAVHIDDeviceDidReceiveValueNotification, object: nil )
        
        let font = NSFont( name: "Courier New", size: 13.0 ) ?? NSFont.userFixedPitchFontOfSize( 13.0 )!
        
        self.eventViewAttributes = [ NSFontAttributeName : font ]
    }
    
    // MARK: - IBAction implementations
    
    /*==========================================================================*/
    @IBAction func doOpenCloseHidManager( sender: AnyObject? ) {
        
        if let hidManager = self.hidManager {
            
            hidManager.close()
            self.hidManager = nil
            
            self.openCloseManagerButtonTitle = AppDelegate.OpenManagerButtonTitle
            self.addressString = ""
        }
        else {
            
            let hidManager = CAVHIDManager()
            let status = hidManager.open()
            
            if status != kIOReturnSuccess {
                self.addressString = String( format: "Error: 0x%08X (%d)", status, status )
            }
            
            self.openCloseManagerButtonTitle = AppDelegate.CloseManagerButtonTitle
            self.hidManager = hidManager
        }
    }

    /*==========================================================================*/
    @IBAction func doChangeElementTableControl( sender: AnyObject? ) {
        
        guard let tableView = sender as? NSTableView else { return }
        guard let arrangedObjects = self.elementArrayController?.arrangedObjects as? NSArray else { return }
        
        let clickedColumn = tableView.clickedColumn
        let key = tableView.tableColumns[clickedColumn].identifier
        
        let clickedRow = tableView.clickedRow
        let newValue = arrangedObjects[clickedRow].valueForKey( key )
        
        let selectedObjects = arrangedObjects.objectsAtIndexes( tableView.selectedRowIndexes )
        for object in selectedObjects {
            object.setValue( newValue, forKey: key )
        }
        
        self.inhibitTableSelectionChange = true
    }
    
    /*==========================================================================*/
    @IBAction func doClearEvents( sender: AnyObject? ) {
        self.eventView?.string = ""
    }
    
    // MARK: - NSTableViewDelegate implementation
    
    /*==========================================================================*/
    func selectionShouldChangeInTableView( tableView: NSTableView ) -> Bool {
        
        if NSRunLoop.currentRunLoop().currentMode == nil {
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
    func eventNotification( notification: NSNotification ) {
        
        guard let stringValue = notification.userInfo?[CAVHIDDeviceValueAsStringKey] as? String else { return }
        guard let textStorage = self.eventView?.textStorage else { return }

        let attributedString = NSAttributedString( string: stringValue + "\n", attributes: self.eventViewAttributes )
        textStorage.appendAttributedString( attributedString )
        
        let lastCharacter = NSRange( location: ( textStorage.length - 1 ), length: 1 )
        self.eventView?.scrollRangeToVisible( lastCharacter )
    }
}
