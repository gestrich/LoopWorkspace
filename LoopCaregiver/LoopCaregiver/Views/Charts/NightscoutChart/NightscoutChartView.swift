//
//  NightscoutChartView.swift
//  LoopCaregiver
//
//  Created by Bill Gestrich on 11/13/22.
//

import SwiftUI
import Charts
import NightscoutClient
import LoopKit
import HealthKit

struct NightscoutChartScrollView: View {

    @ObservedObject var settings: CaregiverSettings
    private var remoteDataSource: RemoteDataServiceManager
    private let configuration = NightscoutChartConfiguration()
    
    private var minScale: CGFloat = 0.10
    private var maxScale: CGFloat = 3.0
    @State var currentScale: CGFloat = 1.0
    
    init(remoteDataSource: RemoteDataServiceManager, settings: CaregiverSettings) {
        self.settings = settings
        self.remoteDataSource = remoteDataSource
    }
    
    var body: some View {
        GeometryReader { containerReaderProxy in
            ScrollViewReader { scrollReaderProxy in
                ScrollView ([.horizontal]) {
                    NightscoutChartView(settings: settings, remoteDataSource: remoteDataSource)
                        .tag(configuration.graphTag)
                        .frame(width: containerReaderProxy.size.width * CGFloat(configuration.graphTotalDays) / configuration.daysPerVisbleScrollFrame * currentScale, height: containerReaderProxy.size.height, alignment: .center)
                        .animation(.none, value: currentScale)
                        .padding([.top, .bottom]) //Prevent top Y label from clipping
                        .id(configuration.graphTag)
                        .modifier(PinchToZoom(minScale: minScale, maxScale: maxScale, scale: $currentScale))
                        //TODO clean up scrolling to land at a nice place so you see mostly real BGs and ~1h of predicted BGs
                        .onAppear(perform: {
                            scrollReaderProxy.scrollTo(configuration.graphTag, anchor: .trailing)
                        })
                }
                
            }
        }
    }
}

struct NightscoutChartView: View {
    
    @ObservedObject var settings: CaregiverSettings
    @ObservedObject var remoteDataSource: RemoteDataServiceManager
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    func glucoseGraphItems() -> [GraphItem] {
        return remoteDataSource.glucoseSamples.map({$0.graphItem(displayUnit: settings.glucoseDisplayUnits)})
    }
    
    func predictionGraphItems() -> [GraphItem] {
        return remoteDataSource.predictedGlucose
            .map({$0.graphItem(displayUnit: settings.glucoseDisplayUnits)})
    }
    
    func bolusGraphItems() -> [GraphItem] {
        return remoteDataSource.bolusEntries
            .map({$0.graphItem(egvValues: glucoseGraphItems(), displayUnit: settings.glucoseDisplayUnits)})
    }
    
    func carbEntryGraphItems() -> [GraphItem] {
        return remoteDataSource.carbEntries
            .map({$0.graphItem(egvValues: glucoseGraphItems(), displayUnit: settings.glucoseDisplayUnits)})
    }
    
    var body: some View {
        
        Chart() {
            ForEach(glucoseGraphItems()){
                PointMark(
                    x: .value("Time", $0.displayTime),
                    y: .value("Reading", $0.value)
                )
                .foregroundStyle(by: .value("Reading", $0.colorType))
            }
            if settings.timelinePredictionEnabled {
                ForEach(predictionGraphItems()){
                    PointMark(
                        x: .value("Time", $0.displayTime),
                        y: .value("Reading", $0.value)
                    )
                    .foregroundStyle(Color(uiColor: .magenta.withAlphaComponent(0.5)))
                }
            }
            ForEach(bolusGraphItems()) { graphItem in
                PointMark(
                    x: .value("Time", graphItem.displayTime),
                    y: .value("Reading", graphItem.value)
                )
                .foregroundStyle(by: .value("Reading", graphItem.colorType))
                .annotation(position: .overlay, alignment: .center, spacing: 0) {
                    return TreatmentAnnotationView(graphItem: graphItem)
                }
            }
            ForEach(carbEntryGraphItems()) { graphItem in
                PointMark(
                    x: .value("Time", graphItem.displayTime),
                    y: .value("Reading", graphItem.value)
                )
                .foregroundStyle(by: .value("Reading", graphItem.colorType))
                .annotation(position: .overlay, alignment: .center, spacing: 0) {
                    return TreatmentAnnotationView(graphItem: graphItem)
                }
            }
        }
        //Make sure the domain values line up with what is in foregroundStyle above.
        .chartForegroundStyleScale(domain: ColorType.membersAsRange(), range: ColorType.allCases.map({$0.color}), type: .none)
        .chartYScale(domain: chartYRange())
        .chartXAxis{
            AxisMarks(position: .bottom, values: .stride(by: xAxisStride, count: xAxisStrideCount)) { date in
                AxisValueLabel(format: xAxisLabelFormatStyle(for: date.as(Date.self) ?? Date()))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle()) //For taps
                    .onTapGesture { tapPosition in
                        guard let (date, value) = proxy.value(at: tapPosition, as: (Date, Int).self) else {
                            print("Could not convert")
                            return
                        }
                        print("Location: \(date), \(value)")
                    }
            }
        }
    }
    
    func chartYRange() -> ClosedRange<Double> {
        return minYValue()...maxYValue()
    }
    
    func minYValue() -> Double {
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 0).doubleValue(for: settings.glucoseDisplayUnits)
    }
    
    func maxYValue() -> Double {
        return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 300).doubleValue(for: settings.glucoseDisplayUnits)
    }
    
    func formatGlucoseQuantity(_ quantity: HKQuantity) -> Double {
        return quantity.doubleValue(for: settings.glucoseDisplayUnits)
    }
    

    //MARK: Experimental time range things
    
    //See https://mobile.blog/2022/07/04/an-adventure-with-swift-charts
    
    var timeRange: TimeRange {
        return .today
    }
    
    enum TimeRange {
        case today
        case thisWeek
        case thisMonth
        case thisYear
    }
    
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .today:
            return .hour
        case .thisWeek, .thisMonth:
            return .day
        case .thisYear:
            return .month
        }
    }
     
    private var xAxisStrideCount: Int {
        switch timeRange {
        case .today:
            return 1
        case .thisWeek:
            return 1
        case .thisMonth:
            return 5
        case .thisYear:
            return 3
        }
    }
     
    private func xAxisLabelFormatStyle(for date: Date) -> Date.FormatStyle {
        switch timeRange {
        case .today:
            return .dateTime.hour()
        case .thisWeek, .thisMonth:
            if date == glucoseGraphItems().first?.displayTime {
                return .dateTime.month(.abbreviated).day(.twoDigits)
            }
            return .dateTime.day(.twoDigits)
        case .thisYear:
            return .dateTime.month(.abbreviated)
        }
    }
}

enum GraphItemType {
    case egv
    case predictedBG
    case bolus(WGBolusEntry)
    case carb(WGCarbEntry)
}

struct GraphItem: Identifiable, Equatable {
    
    var id = UUID()
    var type: GraphItemType
    var displayTime: Date
    var displayUnit: HKUnit
    private var quantity: HKQuantity
    
    var value: Double {
        return quantity.doubleValue(for: displayUnit)
    }
    
    var colorType: ColorType {
        return ColorType(quantity: quantity)
    }
    
    init(type: GraphItemType, displayTime: Date, quantity: HKQuantity, displayUnit: HKUnit) {
        self.type = type
        self.displayTime = displayTime
        self.displayUnit = displayUnit
        self.quantity = quantity
    }
    
    func annotationWidth() -> CGFloat {
        var width: CGFloat = 0.0
        switch self.type {
        case .bolus(let bolusEntry):
            width = CGFloat(bolusEntry.amount) * 5.0
        case .carb(let carbEntry):
            width = CGFloat(carbEntry.amount) * 0.5
        default:
            width = 0.5
        }
        
        let minWidth = 8.0
        let maxWidth = 50.0
        
        if width < minWidth {
            return minWidth
        } else if width > maxWidth {
            return maxWidth
        } else {
            return width
        }
    }
    
    func annotationHeight() -> CGFloat {
        return annotationWidth() //same
    }
    
    func fontSize() -> Double {
        
        var size = 0.0
        switch self.type {
        case .bolus(let bolusEntry):
            size = Double(3 * bolusEntry.amount)
        case .carb(let carbEntry):
            size = Double(carbEntry.amount / 2)
        default:
            size = 10
        }
        
        let minSize = 8.0
        let maxSize = 12.0
        
        if size < minSize {
            return minSize
        } else if size > maxSize {
            return maxSize
        } else {
            return size
        }
    }
    
    func annotationFillStyle() -> TreatmentAnnotationView.HalfFilledAnnotationView.FillStyle {
        switch self.type {
        case .bolus:
            return .bottomFill
        case .carb:
            return .topFill
        default:
            return .fullFill
        }
    }
    
    func annotationFillColor() -> Color {
        switch self.type {
        case .bolus:
            return .blue
        case .carb:
            return .brown
        default:
            return .black
        }
    }
    
    func formattedValue() -> String {
        switch self.type {
        case .bolus(let bolusEntry):
            
            var maxFractionalDigits = 0
            if bolusEntry.amount > 1 {
                maxFractionalDigits = 1
            } else {
                maxFractionalDigits = 2
            }
            
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = maxFractionalDigits
            formatter.numberStyle = .decimal
            let bolusQuantityString = formatter.string(from: bolusEntry.amount as NSNumber) ?? ""
            return bolusQuantityString + "u"
        case .carb(let carbEntry):
            return "\(carbEntry.amount)g"
        case .egv:
            return "\(self.value)"
        case .predictedBG:
            return "\(self.value)"
        }
    }
    
    func annotationLabelPosition() -> GraphItemLabelPosition {
        switch self.type {
        case .bolus:
            return .bottom
        case .carb:
            return .top
        default:
            return .top
        }
    }
    
    func shouldShowLabel() -> Bool {
        switch self.type {
        case .bolus:
            return true
        default:
            return true
        }
    }
    
    enum GraphItemLabelPosition {
        case top
        case bottom
    }
    
    
    //Equatable
    
    static func == (lhs: GraphItem, rhs: GraphItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ColorType: Int, Plottable, CaseIterable, Comparable {
    
    var primitivePlottable: Int {
        return self.rawValue
    }
    
    typealias PrimitivePlottable = Int
    
    case gray
    case green
    case yellow
    case red
    
    init?(primitivePlottable: Int){
        self.init(rawValue: primitivePlottable)
    }
    
    init(quantity: HKQuantity) {
        let glucose = quantity.doubleValue(for:.milligramsPerDeciliter)
        switch glucose {
        case 0..<55:
            self = ColorType.red
        case 55..<70:
            self = ColorType.yellow
        case 70..<180:
            self = ColorType.green
        case 180..<250:
            self = ColorType.yellow
        case 250...:
            self = ColorType.red
        default:
            assertionFailure("Unexpected quantity: \(quantity)")
            self = ColorType.gray
        }
    }
    
    var color: Color {
        switch self {
        case .gray:
            return Color.gray
        case .green:
            return Color.green
        case .yellow:
            return Color.yellow
        case .red:
            return Color.red
        }
    }
    
    static func membersAsRange() -> ClosedRange<ColorType> {
        return ColorType.allCases.first!...ColorType.allCases.last!
    }
    
    //Comparable
    static func < (lhs: ColorType, rhs: ColorType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
}

extension WGCarbEntry {
    
    func graphItem(egvValues: [GraphItem], displayUnit: HKUnit) -> GraphItem {
        let relativeEgvValue = interpolateEGVValue(egvs: egvValues, atDate: date)
        return GraphItem(type: .carb(self), displayTime: date, quantity: HKQuantity(unit: displayUnit, doubleValue: relativeEgvValue), displayUnit: displayUnit)
    }
}

extension WGBolusEntry {
    
    func graphItem(egvValues: [GraphItem], displayUnit: HKUnit) -> GraphItem {
        let relativeEgvValue = interpolateEGVValue(egvs: egvValues, atDate: date)
        return GraphItem(type: .bolus(self), displayTime: date, quantity: HKQuantity(unit: displayUnit, doubleValue: relativeEgvValue), displayUnit: displayUnit)
    }
}

func interpolateEGVValue(egvs: [GraphItem], atDate date: Date ) -> Double {
    
    switch egvs.count {
    case 0:
        return 0
    case 1:
        return egvs[0].value
    default:
        let priorEGVs = egvs.filter({$0.displayTime < date})
        guard let greatestPriorEGV = priorEGVs.last else {
            //All after, use first
            return egvs.first!.value
        }
        
        let laterEGVs = egvs.filter({$0.displayTime > date})
        guard let leastFollowingEGV = laterEGVs.first else {
            //All prior, use last
            return egvs.last!.value
        }
        
        return interpolateYValueInRange(yRange: (y1: greatestPriorEGV.value, y2: leastFollowingEGV.value), referenceXRange: (x1: greatestPriorEGV.displayTime, x2: leastFollowingEGV.displayTime), referenceXValue: date)
    }
}

//Given a known value x in a range (x1, x2), interpolate value y, in range (y1, y2)
func interpolateYValueInRange(yRange: (y1: Double, y2: Double), referenceXRange: (x1: Date, x2: Date), referenceXValue: Date) -> Double {
    let referenceRangeDistance = referenceXRange.x2.timeIntervalSince1970 - referenceXRange.x1.timeIntervalSince1970
    let lowerRangeToValueDifference = referenceXValue.timeIntervalSince1970 - referenceXRange.x1.timeIntervalSince1970
    let scaleFactor = lowerRangeToValueDifference / referenceRangeDistance
    
    let rangeDifference = abs(yRange.y1 - yRange.y2)
    return yRange.y1 + (rangeDifference * scaleFactor)
    
}

struct NightscoutChartConfiguration {
    let graphTotalDays = 1
    let daysPerVisbleScrollFrame = 3.0 / 24.0 //zoom to 3 hours
    let graphTag = 1000
}
