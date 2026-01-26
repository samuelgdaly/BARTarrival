import ClockKit
import SwiftUI
import WatchKit

// Simple complication controller for BART app
class BARTComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        // Simple descriptor for BART app launcher
        let descriptor = CLKComplicationDescriptor(
            identifier: "com.samueldaly.bartarrivals.bart",
            displayName: "BART",
            supportedFamilies: [
                .modularSmall,
                .circularSmall,
                .utilitarianSmall,
                .utilitarianSmallFlat
            ]
        )
        
        print("BARTArrivals: getComplicationDescriptors called - providing descriptor to system")
        handler([descriptor])
    }
    
    // MARK: - Timeline Data
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        print("BARTArrivals: getCurrentTimelineEntry called for family: \(complication.family.rawValue)")
        
        // Simple template that just shows the BART app icon
        let template = createTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        print("BARTArrivals: getTimelineEntries called")
        handler(nil) // No future entries needed
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date())
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date().addingTimeInterval(24 * 60 * 60)) // 24 hours from now
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            template.imageProvider = getAppIconProvider()
            return template
            
        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            template.imageProvider = getAppIconProvider()
            return template
            
        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallSquare()
            template.imageProvider = getAppIconProvider()
            return template
            
        case .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            template.textProvider = CLKSimpleTextProvider(text: "BART")
            return template
            
        default:
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            template.imageProvider = getAppIconProvider()
            return template
        }
    }
    
    // MARK: - App Icon Provider
    
    private func getAppIconProvider() -> CLKImageProvider {
        // Use the app icon from the bundle
        if let appIcon = UIImage(named: "AppIcon") {
            return CLKImageProvider(onePieceImage: appIcon)
        }
        // Fallback to a train icon if app icon not found
        return CLKImageProvider(onePieceImage: UIImage(systemName: "tram.fill") ?? UIImage())
    }
    
    // MARK: - Sample Data
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        print("BARTArrivals: getLocalizableSampleTemplate called")
        let template = createTemplate(for: complication.family)
        handler(template)
    }
} 