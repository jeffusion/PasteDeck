//
//  RetentionSlider.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import AppKit

struct RetentionScale {
    struct Option: Equatable {
        let days: Int
        let visualValue: Double
    }

    struct MajorTick: Identifiable {
        let id: String
        let days: Int
        let visualValue: Double
    }

    static let options: [Option] = {
        var result: [Option] = []

        for day in 1...6 {
            result.append(Option(
                days: day,
                visualValue: Double(day - 1) * 0.04
            ))
        }

        for week in 1...3 {
            result.append(Option(
                days: week * 7,
                visualValue: 0.25 + Double(week - 1) * 0.075
            ))
        }

        for month in 1...11 {
            result.append(Option(
                days: month * 30,
                visualValue: 0.45 + Double(month - 1) * 0.04
            ))
        }

        result.append(Option(days: 365, visualValue: 0.9))
        result.append(Option(days: -1, visualValue: 1.0))
        return result
    }()

    static let majorTicks: [MajorTick] = [
        MajorTick(id: "day", days: 1, visualValue: 0),
        MajorTick(id: "week", days: 7, visualValue: 0.25),
        MajorTick(id: "month", days: 30, visualValue: 0.45),
        MajorTick(id: "year", days: 365, visualValue: 0.9),
        MajorTick(id: "forever", days: -1, visualValue: 1)
    ]

    static var supportedDays: [Int] {
        options.map(\.days)
    }

    static func index(forDays days: Int) -> Int {
        if let exactIndex = options.firstIndex(where: { $0.days == days }) {
            return exactIndex
        }

        let finiteIndices = options.indices.filter { options[$0].days >= 0 }
        return finiteIndices.min {
            abs(options[$0].days - days) < abs(options[$1].days - days)
        } ?? 0
    }

    static func nearestIndex(to visualValue: Double) -> Int {
        options.indices.min {
            abs(options[$0].visualValue - visualValue) <
                abs(options[$1].visualValue - visualValue)
        } ?? 0
    }

    static func days(at index: Int) -> Int {
        options[clamped(index)].days
    }

    static func visualValue(at index: Int) -> Double {
        options[clamped(index)].visualValue
    }

    static func visualValue(forDays days: Int) -> Double {
        visualValue(at: index(forDays: days))
    }

    static func days(closestTo visualValue: Double) -> Int {
        days(at: nearestIndex(to: visualValue))
    }

    private static func clamped(_ index: Int) -> Int {
        max(options.startIndex, min(index, options.index(before: options.endIndex)))
    }
}

struct RetentionSlider: View {
    @Binding var retentionDays: Int
    @State private var selectedIndex = 0
    @State private var isEditing = false

    private let trackInset: CGFloat = 8
    private let tickLabelWidth: CGFloat = 78

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayText(for: RetentionScale.days(at: selectedIndex)))
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()

            ZStack {
                Slider(
                    value: sliderValue,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isEditing = editing
                        if !editing {
                            retentionDays = RetentionScale.days(at: selectedIndex)
                        }
                    }
                )
                .controlSize(.small)
                .accessibilityLabel(L10n.string("settings.general.retention"))
                .accessibilityValue(displayText(for: RetentionScale.days(at: selectedIndex)))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        selectAdjacentOption(offset: 1)
                    case .decrement:
                        selectAdjacentOption(offset: -1)
                    @unknown default:
                        break
                    }
                }

                GeometryReader { geometry in
                    ForEach(RetentionScale.majorTicks) { tick in
                        Capsule()
                            .fill(Color.primary.opacity(0.24))
                            .frame(width: 1, height: 7)
                            .position(
                                x: trackX(tick.visualValue, width: geometry.size.width),
                                y: geometry.size.height / 2
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(height: 18)

            GeometryReader { geometry in
                ForEach(RetentionScale.majorTicks) { tick in
                    Text(displayText(for: tick.days))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(
                            width: tickLabelWidth,
                            alignment: labelAlignment(for: tick.visualValue)
                        )
                        .position(
                            x: labelCenterX(tick.visualValue, width: geometry.size.width),
                            y: 7
                        )
                }
            }
            .frame(height: 14)
        }
        .onAppear {
            selectedIndex = RetentionScale.index(forDays: retentionDays)
        }
        .onChange(of: retentionDays) { newDays in
            guard !isEditing else { return }
            selectedIndex = RetentionScale.index(forDays: newDays)
        }
        .onChange(of: selectedIndex) { newIndex in
            guard !isEditing else { return }
            retentionDays = RetentionScale.days(at: newIndex)
        }
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { RetentionScale.visualValue(at: selectedIndex) },
            set: { value in
                let newIndex = RetentionScale.nearestIndex(to: value)
                guard newIndex != selectedIndex else { return }
                selectedIndex = newIndex

                if isEditing {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .alignment,
                        performanceTime: .default
                    )
                }
            }
        )
    }

    private func selectAdjacentOption(offset: Int) {
        selectedIndex = max(
            RetentionScale.options.startIndex,
            min(
                selectedIndex + offset,
                RetentionScale.options.index(before: RetentionScale.options.endIndex)
            )
        )
    }

    private func trackX(_ visualValue: Double, width: CGFloat) -> CGFloat {
        trackInset + CGFloat(visualValue) * max(0, width - trackInset * 2)
    }

    private func labelCenterX(_ visualValue: Double, width: CGFloat) -> CGFloat {
        let x = trackX(visualValue, width: width)
        if visualValue == 0 {
            return x + tickLabelWidth / 2
        }
        if visualValue == 1 {
            return x - tickLabelWidth / 2
        }
        return x
    }

    private func labelAlignment(for visualValue: Double) -> Alignment {
        if visualValue == 0 {
            return .leading
        }
        if visualValue == 1 {
            return .trailing
        }
        return .center
    }

    private func displayText(for days: Int) -> String {
        if days == -1 {
            return L10n.string("retention.forever")
        }
        if days < 7 {
            return L10n.plural("duration.days", count: days)
        }
        if days <= 21, days.isMultiple(of: 7) {
            return L10n.plural("duration.weeks", count: days / 7)
        }
        if days <= 330, days.isMultiple(of: 30) {
            return L10n.plural("duration.months", count: days / 30)
        }
        if days == 365 {
            return L10n.plural("duration.years", count: 1)
        }
        return L10n.plural("duration.days", count: days)
    }
}

#if DEBUG
struct RetentionSlider_Previews: PreviewProvider {
    static var previews: some View {
        RetentionSlider(retentionDays: .constant(30))
            .padding()
            .frame(width: 440)
    }
}
#endif
