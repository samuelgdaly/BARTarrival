import SwiftUI
import ClockKit

// Simplified to be a standard ObservableObject for the app
class ExtensionDelegate: ObservableObject {
    
    init() {
        // Initialize the delegate
        print("BARTArrivals: ExtensionDelegate initializing")
        setupComplications()
        print("BARTArrivals: ExtensionDelegate initialized")
    }
    
    private func setupComplications() {
        // Create a new instance of the complication controller
        // The system will automatically discover it
        _ = BARTComplicationController()
        print("BARTArrivals: Created complication controller")
        
        // Register the complication data source class with ClockKit
        let complicationServer = CLKComplicationServer.sharedInstance()
        complicationServer.reloadComplicationDescriptors()
        print("BARTArrivals: Reloaded complication descriptors from ExtensionDelegate")
    }
    
    func refreshComplications() {
        // Update complications
        print("BARTArrivals: Refreshing complications from ExtensionDelegate")
        let complicationServer = CLKComplicationServer.sharedInstance()
        
        if let activeComplications = complicationServer.activeComplications, !activeComplications.isEmpty {
            print("BARTArrivals: Refreshing \(activeComplications.count) active complications")
            for complication in activeComplications {
                complicationServer.reloadTimeline(for: complication)
            }
        } else {
            print("BARTArrivals: No active complications to refresh")
            
            // Since there are no active complications, make sure descriptors are registered
            complicationServer.reloadComplicationDescriptors()
        }
    }
} 