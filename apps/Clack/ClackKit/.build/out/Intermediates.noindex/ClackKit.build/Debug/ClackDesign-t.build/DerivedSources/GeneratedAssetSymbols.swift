import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "accent" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "accent", bundle: resourceBundle)

    /// The "accent-ink" asset catalog color resource.
    static let accentInk = DeveloperToolsSupport.ColorResource(name: "accent-ink", bundle: resourceBundle)

    /// The "accent-line" asset catalog color resource.
    static let accentLine = DeveloperToolsSupport.ColorResource(name: "accent-line", bundle: resourceBundle)

    /// The "accent-soft" asset catalog color resource.
    static let accentSoft = DeveloperToolsSupport.ColorResource(name: "accent-soft", bundle: resourceBundle)

    /// The "bg" asset catalog color resource.
    static let bg = DeveloperToolsSupport.ColorResource(name: "bg", bundle: resourceBundle)

    /// The "error-bg" asset catalog color resource.
    static let errorBg = DeveloperToolsSupport.ColorResource(name: "error-bg", bundle: resourceBundle)

    /// The "error-text" asset catalog color resource.
    static let errorText = DeveloperToolsSupport.ColorResource(name: "error-text", bundle: resourceBundle)

    /// The "fill-soft" asset catalog color resource.
    static let fillSoft = DeveloperToolsSupport.ColorResource(name: "fill-soft", bundle: resourceBundle)

    /// The "flap-bottom" asset catalog color resource.
    static let flapBottom = DeveloperToolsSupport.ColorResource(name: "flap-bottom", bundle: resourceBundle)

    /// The "flap-hinge" asset catalog color resource.
    static let flapHinge = DeveloperToolsSupport.ColorResource(name: "flap-hinge", bundle: resourceBundle)

    /// The "flap-text" asset catalog color resource.
    static let flapText = DeveloperToolsSupport.ColorResource(name: "flap-text", bundle: resourceBundle)

    /// The "flap-top" asset catalog color resource.
    static let flapTop = DeveloperToolsSupport.ColorResource(name: "flap-top", bundle: resourceBundle)

    /// The "glass" asset catalog color resource.
    static let glass = DeveloperToolsSupport.ColorResource(name: "glass", bundle: resourceBundle)

    /// The "glass-strong" asset catalog color resource.
    static let glassStrong = DeveloperToolsSupport.ColorResource(name: "glass-strong", bundle: resourceBundle)

    /// The "hairline" asset catalog color resource.
    static let hairline = DeveloperToolsSupport.ColorResource(name: "hairline", bundle: resourceBundle)

    /// The "late" asset catalog color resource.
    static let late = DeveloperToolsSupport.ColorResource(name: "late", bundle: resourceBundle)

    /// The "late-ink" asset catalog color resource.
    static let lateInk = DeveloperToolsSupport.ColorResource(name: "late-ink", bundle: resourceBundle)

    /// The "launch-bg" asset catalog color resource.
    static let launchBg = DeveloperToolsSupport.ColorResource(name: "launch-bg", bundle: resourceBundle)

    /// The "map-bg" asset catalog color resource.
    static let mapBg = DeveloperToolsSupport.ColorResource(name: "map-bg", bundle: resourceBundle)

    /// The "marker-ring" asset catalog color resource.
    static let markerRing = DeveloperToolsSupport.ColorResource(name: "marker-ring", bundle: resourceBundle)

    /// The "on-accent" asset catalog color resource.
    static let onAccent = DeveloperToolsSupport.ColorResource(name: "on-accent", bundle: resourceBundle)

    /// The "on-time" asset catalog color resource.
    static let onTime = DeveloperToolsSupport.ColorResource(name: "on-time", bundle: resourceBundle)

    /// The "on-time-ink" asset catalog color resource.
    static let onTimeInk = DeveloperToolsSupport.ColorResource(name: "on-time-ink", bundle: resourceBundle)

    /// The "scrim" asset catalog color resource.
    static let scrim = DeveloperToolsSupport.ColorResource(name: "scrim", bundle: resourceBundle)

    /// The "slight" asset catalog color resource.
    static let slight = DeveloperToolsSupport.ColorResource(name: "slight", bundle: resourceBundle)

    /// The "slight-ink" asset catalog color resource.
    static let slightInk = DeveloperToolsSupport.ColorResource(name: "slight-ink", bundle: resourceBundle)

    /// The "surface" asset catalog color resource.
    static let surface = DeveloperToolsSupport.ColorResource(name: "surface", bundle: resourceBundle)

    /// The "surface-raised" asset catalog color resource.
    static let surfaceRaised = DeveloperToolsSupport.ColorResource(name: "surface-raised", bundle: resourceBundle)

    /// The "text" asset catalog color resource.
    static let text = DeveloperToolsSupport.ColorResource(name: "text", bundle: resourceBundle)

    /// The "text-2" asset catalog color resource.
    static let text2 = DeveloperToolsSupport.ColorResource(name: "text-2", bundle: resourceBundle)

    /// The "text-3" asset catalog color resource.
    static let text3 = DeveloperToolsSupport.ColorResource(name: "text-3", bundle: resourceBundle)

    /// The "tflap-bottom" asset catalog color resource.
    static let tflapBottom = DeveloperToolsSupport.ColorResource(name: "tflap-bottom", bundle: resourceBundle)

    /// The "tflap-hinge" asset catalog color resource.
    static let tflapHinge = DeveloperToolsSupport.ColorResource(name: "tflap-hinge", bundle: resourceBundle)

    /// The "tflap-text" asset catalog color resource.
    static let tflapText = DeveloperToolsSupport.ColorResource(name: "tflap-text", bundle: resourceBundle)

    /// The "tflap-top" asset catalog color resource.
    static let tflapTop = DeveloperToolsSupport.ColorResource(name: "tflap-top", bundle: resourceBundle)

    /// The "unknown" asset catalog color resource.
    static let unknown = DeveloperToolsSupport.ColorResource(name: "unknown", bundle: resourceBundle)

    /// The "very-late" asset catalog color resource.
    static let veryLate = DeveloperToolsSupport.ColorResource(name: "very-late", bundle: resourceBundle)

    /// The "very-late-ink" asset catalog color resource.
    static let veryLateInk = DeveloperToolsSupport.ColorResource(name: "very-late-ink", bundle: resourceBundle)

    /// The "warn-bg" asset catalog color resource.
    static let warnBg = DeveloperToolsSupport.ColorResource(name: "warn-bg", bundle: resourceBundle)

    /// The "warn-text" asset catalog color resource.
    static let warnText = DeveloperToolsSupport.ColorResource(name: "warn-text", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "lucide-accessibility" asset catalog image resource.
    static let lucideAccessibility = DeveloperToolsSupport.ImageResource(name: "lucide-accessibility", bundle: resourceBundle)

    /// The "lucide-activity" asset catalog image resource.
    static let lucideActivity = DeveloperToolsSupport.ImageResource(name: "lucide-activity", bundle: resourceBundle)

    /// The "lucide-armchair" asset catalog image resource.
    static let lucideArmchair = DeveloperToolsSupport.ImageResource(name: "lucide-armchair", bundle: resourceBundle)

    /// The "lucide-arrow-down-up" asset catalog image resource.
    static let lucideArrowDownUp = DeveloperToolsSupport.ImageResource(name: "lucide-arrow-down-up", bundle: resourceBundle)

    /// The "lucide-arrow-left" asset catalog image resource.
    static let lucideArrowLeft = DeveloperToolsSupport.ImageResource(name: "lucide-arrow-left", bundle: resourceBundle)

    /// The "lucide-baby" asset catalog image resource.
    static let lucideBaby = DeveloperToolsSupport.ImageResource(name: "lucide-baby", bundle: resourceBundle)

    /// The "lucide-banknote" asset catalog image resource.
    static let lucideBanknote = DeveloperToolsSupport.ImageResource(name: "lucide-banknote", bundle: resourceBundle)

    /// The "lucide-bed-double" asset catalog image resource.
    static let lucideBedDouble = DeveloperToolsSupport.ImageResource(name: "lucide-bed-double", bundle: resourceBundle)

    /// The "lucide-bike" asset catalog image resource.
    static let lucideBike = DeveloperToolsSupport.ImageResource(name: "lucide-bike", bundle: resourceBundle)

    /// The "lucide-bus" asset catalog image resource.
    static let lucideBus = DeveloperToolsSupport.ImageResource(name: "lucide-bus", bundle: resourceBundle)

    /// The "lucide-car-taxi-front" asset catalog image resource.
    static let lucideCarTaxiFront = DeveloperToolsSupport.ImageResource(name: "lucide-car-taxi-front", bundle: resourceBundle)

    /// The "lucide-check" asset catalog image resource.
    static let lucideCheck = DeveloperToolsSupport.ImageResource(name: "lucide-check", bundle: resourceBundle)

    /// The "lucide-chevron-down" asset catalog image resource.
    static let lucideChevronDown = DeveloperToolsSupport.ImageResource(name: "lucide-chevron-down", bundle: resourceBundle)

    /// The "lucide-chevron-right" asset catalog image resource.
    static let lucideChevronRight = DeveloperToolsSupport.ImageResource(name: "lucide-chevron-right", bundle: resourceBundle)

    /// The "lucide-chevron-up" asset catalog image resource.
    static let lucideChevronUp = DeveloperToolsSupport.ImageResource(name: "lucide-chevron-up", bundle: resourceBundle)

    /// The "lucide-clock" asset catalog image resource.
    static let lucideClock = DeveloperToolsSupport.ImageResource(name: "lucide-clock", bundle: resourceBundle)

    /// The "lucide-coffee" asset catalog image resource.
    static let lucideCoffee = DeveloperToolsSupport.ImageResource(name: "lucide-coffee", bundle: resourceBundle)

    /// The "lucide-compass" asset catalog image resource.
    static let lucideCompass = DeveloperToolsSupport.ImageResource(name: "lucide-compass", bundle: resourceBundle)

    /// The "lucide-compass-thin" asset catalog image resource.
    static let lucideCompassThin = DeveloperToolsSupport.ImageResource(name: "lucide-compass-thin", bundle: resourceBundle)

    /// The "lucide-crown" asset catalog image resource.
    static let lucideCrown = DeveloperToolsSupport.ImageResource(name: "lucide-crown", bundle: resourceBundle)

    /// The "lucide-door-open" asset catalog image resource.
    static let lucideDoorOpen = DeveloperToolsSupport.ImageResource(name: "lucide-door-open", bundle: resourceBundle)

    /// The "lucide-download" asset catalog image resource.
    static let lucideDownload = DeveloperToolsSupport.ImageResource(name: "lucide-download", bundle: resourceBundle)

    /// The "lucide-external-link" asset catalog image resource.
    static let lucideExternalLink = DeveloperToolsSupport.ImageResource(name: "lucide-external-link", bundle: resourceBundle)

    /// The "lucide-eye" asset catalog image resource.
    static let lucideEye = DeveloperToolsSupport.ImageResource(name: "lucide-eye", bundle: resourceBundle)

    /// The "lucide-eye-off" asset catalog image resource.
    static let lucideEyeOff = DeveloperToolsSupport.ImageResource(name: "lucide-eye-off", bundle: resourceBundle)

    /// The "lucide-flag" asset catalog image resource.
    static let lucideFlag = DeveloperToolsSupport.ImageResource(name: "lucide-flag", bundle: resourceBundle)

    /// The "lucide-gauge" asset catalog image resource.
    static let lucideGauge = DeveloperToolsSupport.ImageResource(name: "lucide-gauge", bundle: resourceBundle)

    /// The "lucide-globe" asset catalog image resource.
    static let lucideGlobe = DeveloperToolsSupport.ImageResource(name: "lucide-globe", bundle: resourceBundle)

    /// The "lucide-info" asset catalog image resource.
    static let lucideInfo = DeveloperToolsSupport.ImageResource(name: "lucide-info", bundle: resourceBundle)

    /// The "lucide-layers" asset catalog image resource.
    static let lucideLayers = DeveloperToolsSupport.ImageResource(name: "lucide-layers", bundle: resourceBundle)

    /// The "lucide-list" asset catalog image resource.
    static let lucideList = DeveloperToolsSupport.ImageResource(name: "lucide-list", bundle: resourceBundle)

    /// The "lucide-locate-fixed" asset catalog image resource.
    static let lucideLocateFixed = DeveloperToolsSupport.ImageResource(name: "lucide-locate-fixed", bundle: resourceBundle)

    /// The "lucide-luggage" asset catalog image resource.
    static let lucideLuggage = DeveloperToolsSupport.ImageResource(name: "lucide-luggage", bundle: resourceBundle)

    /// The "lucide-map" asset catalog image resource.
    static let lucideMap = DeveloperToolsSupport.ImageResource(name: "lucide-map", bundle: resourceBundle)

    /// The "lucide-map-pin" asset catalog image resource.
    static let lucideMapPin = DeveloperToolsSupport.ImageResource(name: "lucide-map-pin", bundle: resourceBundle)

    /// The "lucide-maximize-2" asset catalog image resource.
    static let lucideMaximize2 = DeveloperToolsSupport.ImageResource(name: "lucide-maximize-2", bundle: resourceBundle)

    /// The "lucide-moon" asset catalog image resource.
    static let lucideMoon = DeveloperToolsSupport.ImageResource(name: "lucide-moon", bundle: resourceBundle)

    /// The "lucide-navigation" asset catalog image resource.
    static let lucideNavigation = DeveloperToolsSupport.ImageResource(name: "lucide-navigation", bundle: resourceBundle)

    /// The "lucide-paw-print" asset catalog image resource.
    static let lucidePawPrint = DeveloperToolsSupport.ImageResource(name: "lucide-paw-print", bundle: resourceBundle)

    /// The "lucide-pill" asset catalog image resource.
    static let lucidePill = DeveloperToolsSupport.ImageResource(name: "lucide-pill", bundle: resourceBundle)

    /// The "lucide-plug" asset catalog image resource.
    static let lucidePlug = DeveloperToolsSupport.ImageResource(name: "lucide-plug", bundle: resourceBundle)

    /// The "lucide-plus" asset catalog image resource.
    static let lucidePlus = DeveloperToolsSupport.ImageResource(name: "lucide-plus", bundle: resourceBundle)

    /// The "lucide-radar" asset catalog image resource.
    static let lucideRadar = DeveloperToolsSupport.ImageResource(name: "lucide-radar", bundle: resourceBundle)

    /// The "lucide-refresh-cw" asset catalog image resource.
    static let lucideRefreshCw = DeveloperToolsSupport.ImageResource(name: "lucide-refresh-cw", bundle: resourceBundle)

    /// The "lucide-repeat" asset catalog image resource.
    static let lucideRepeat = DeveloperToolsSupport.ImageResource(name: "lucide-repeat", bundle: resourceBundle)

    /// The "lucide-route" asset catalog image resource.
    static let lucideRoute = DeveloperToolsSupport.ImageResource(name: "lucide-route", bundle: resourceBundle)

    /// The "lucide-search" asset catalog image resource.
    static let lucideSearch = DeveloperToolsSupport.ImageResource(name: "lucide-search", bundle: resourceBundle)

    /// The "lucide-settings" asset catalog image resource.
    static let lucideSettings = DeveloperToolsSupport.ImageResource(name: "lucide-settings", bundle: resourceBundle)

    /// The "lucide-share-2" asset catalog image resource.
    static let lucideShare2 = DeveloperToolsSupport.ImageResource(name: "lucide-share-2", bundle: resourceBundle)

    /// The "lucide-shopping-bag" asset catalog image resource.
    static let lucideShoppingBag = DeveloperToolsSupport.ImageResource(name: "lucide-shopping-bag", bundle: resourceBundle)

    /// The "lucide-shopping-basket" asset catalog image resource.
    static let lucideShoppingBasket = DeveloperToolsSupport.ImageResource(name: "lucide-shopping-basket", bundle: resourceBundle)

    /// The "lucide-sliders-horizontal" asset catalog image resource.
    static let lucideSlidersHorizontal = DeveloperToolsSupport.ImageResource(name: "lucide-sliders-horizontal", bundle: resourceBundle)

    /// The "lucide-smartphone" asset catalog image resource.
    static let lucideSmartphone = DeveloperToolsSupport.ImageResource(name: "lucide-smartphone", bundle: resourceBundle)

    /// The "lucide-stamp" asset catalog image resource.
    static let lucideStamp = DeveloperToolsSupport.ImageResource(name: "lucide-stamp", bundle: resourceBundle)

    /// The "lucide-stamp-thin" asset catalog image resource.
    static let lucideStampThin = DeveloperToolsSupport.ImageResource(name: "lucide-stamp-thin", bundle: resourceBundle)

    /// The "lucide-star" asset catalog image resource.
    static let lucideStar = DeveloperToolsSupport.ImageResource(name: "lucide-star", bundle: resourceBundle)

    /// The "lucide-ticket" asset catalog image resource.
    static let lucideTicket = DeveloperToolsSupport.ImageResource(name: "lucide-ticket", bundle: resourceBundle)

    /// The "lucide-toilet" asset catalog image resource.
    static let lucideToilet = DeveloperToolsSupport.ImageResource(name: "lucide-toilet", bundle: resourceBundle)

    /// The "lucide-train-front" asset catalog image resource.
    static let lucideTrainFront = DeveloperToolsSupport.ImageResource(name: "lucide-train-front", bundle: resourceBundle)

    /// The "lucide-train-front-thin" asset catalog image resource.
    static let lucideTrainFrontThin = DeveloperToolsSupport.ImageResource(name: "lucide-train-front-thin", bundle: resourceBundle)

    /// The "lucide-trash" asset catalog image resource.
    static let lucideTrash = DeveloperToolsSupport.ImageResource(name: "lucide-trash", bundle: resourceBundle)

    /// The "lucide-triangle-alert" asset catalog image resource.
    static let lucideTriangleAlert = DeveloperToolsSupport.ImageResource(name: "lucide-triangle-alert", bundle: resourceBundle)

    /// The "lucide-utensils-crossed" asset catalog image resource.
    static let lucideUtensilsCrossed = DeveloperToolsSupport.ImageResource(name: "lucide-utensils-crossed", bundle: resourceBundle)

    /// The "lucide-volume-x" asset catalog image resource.
    static let lucideVolumeX = DeveloperToolsSupport.ImageResource(name: "lucide-volume-x", bundle: resourceBundle)

    /// The "lucide-wifi" asset catalog image resource.
    static let lucideWifi = DeveloperToolsSupport.ImageResource(name: "lucide-wifi", bundle: resourceBundle)

    /// The "lucide-wifi-off" asset catalog image resource.
    static let lucideWifiOff = DeveloperToolsSupport.ImageResource(name: "lucide-wifi-off", bundle: resourceBundle)

    /// The "lucide-x" asset catalog image resource.
    static let lucideX = DeveloperToolsSupport.ImageResource(name: "lucide-x", bundle: resourceBundle)

}

