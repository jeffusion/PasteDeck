//
//  CardGridView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI

enum ClipCardAction {
    case select
    case copy
    case copyAndPaste
    case toggleFavorite
    case togglePin
    case delete
}

struct CardGridView: View {
    @EnvironmentObject var viewModel: ClipboardViewModel
    @EnvironmentObject var focusManager: FocusManager
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage(MotionStyle.preferenceKey) private var motionStylePreference = MotionStyle.nativeSnappy.rawValue
    @AppStorage(MotionSpeed.preferenceKey) private var motionSpeedPreference = MotionSpeed.normal.rawValue
    @Binding var selectedItem: ClipItem?
    @State private var drawerCardsVisible = true

    private let cardSpacing: CGFloat = 12
    private let cardSize: CGFloat = 180
    private let contentPadding: CGFloat = 16

    var body: some View {
        let filteredItems = viewModel.filteredItems
        let filteredItemIDs = filteredItems.map(\.id)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                // The transparent margins provide both content padding and reveal padding.
                LazyHStack(spacing: cardSpacing - (contentPadding * 2)) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 0) {
                            revealSpacer

                            ClipCardView(
                                item: item,
                                isSelected: selectedItem?.id == item.id,
                                onAction: { action in
                                    handle(action, for: item)
                                }
                            )
                            .equatable()

                            revealSpacer
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .id(item.id)
                        .opacity(drawerCardOpacity)
                        .offset(y: drawerCardOffset)
                        .animation(drawerCardAnimation(for: index), value: drawerCardsVisible)
                        .transition(cardTransition)
                    }
                }
                .padding(.vertical, contentPadding)
                .animation(gridLayoutAnimation, value: filteredItemIDs)
            }
            .frame(height: cardSize + (contentPadding * 2))
            .onChange(of: selectedItem) { newSelection in
                // A nil anchor scrolls only as far as needed to reveal the full card.
                if let item = newSelection {
                    reveal(item, using: proxy)
                }
            }
            .onChange(of: viewModel.filteredItems.map(\.id)) { _ in
                // Pinning reorders the list without necessarily changing the selection.
                DispatchQueue.main.async {
                    guard let item = selectedItem else { return }
                    reveal(item, using: proxy)
                }
            }
            .onChange(of: viewModel.selectFirstItemTrigger) { trigger in
                guard trigger != nil else { return }
                restartDrawerCardStagger()
            }
        }
    }

    private func reveal(_ item: ClipItem, using proxy: ScrollViewProxy) {
        if accessibilityReduceMotion {
            proxy.scrollTo(item.id)
        } else {
            withAnimation(.easeOut(duration: MotionTiming.cardReveal * durationMultiplier)) {
                proxy.scrollTo(item.id)
            }
        }
    }

    private var motionStyle: MotionStyle {
        MotionStyle(rawValue: motionStylePreference) ?? .nativeSnappy
    }

    private var durationMultiplier: Double {
        (MotionSpeed(rawValue: motionSpeedPreference) ?? .normal).durationMultiplier
    }

    private var gridLayoutAnimation: Animation? {
        guard !accessibilityReduceMotion else { return nil }

        switch motionStyle {
        case .nativeSnappy:
            return .easeOut(duration: MotionTiming.filter * durationMultiplier)
        case .spatialSpring:
            return .timingCurve(0.34, 1.36, 0.64, 1, duration: MotionTiming.filter * durationMultiplier)
        case .softMaterial:
            return .easeInOut(duration: MotionTiming.filter * durationMultiplier)
        }
    }

    private var cardTransition: AnyTransition {
        guard !accessibilityReduceMotion else { return .opacity }

        let transition: AnyTransition
        switch motionStyle {
        case .nativeSnappy:
            transition = .opacity
        case .spatialSpring:
            transition = .scale(scale: 0.8)
                .combined(with: .offset(y: 10))
                .combined(with: .opacity)
        case .softMaterial:
            transition = .modifier(
                active: SoftMaterialCardTransition(scale: 0.96, blurRadius: 4, opacity: 0),
                identity: SoftMaterialCardTransition(scale: 1, blurRadius: 0, opacity: 1)
            )
        }

        return transition.animation(cardTransitionAnimation)
    }

    private var cardTransitionAnimation: Animation {
        switch motionStyle {
        case .nativeSnappy:
            return .timingCurve(0.16, 1, 0.3, 1, duration: MotionTiming.cardTransition * durationMultiplier)
        case .spatialSpring:
            return .timingCurve(0.175, 0.885, 0.32, 1.075, duration: MotionTiming.cardTransition * durationMultiplier)
        case .softMaterial:
            return .easeInOut(duration: MotionTiming.cardTransition * durationMultiplier)
        }
    }

    private var shouldStaggerDrawerCards: Bool {
        !accessibilityReduceMotion && motionStyle == .spatialSpring
    }

    private var drawerCardOpacity: Double {
        shouldStaggerDrawerCards && !drawerCardsVisible ? 0 : 1
    }

    private var drawerCardOffset: CGFloat {
        shouldStaggerDrawerCards && !drawerCardsVisible ? 30 : 0
    }

    private func drawerCardAnimation(for index: Int) -> Animation? {
        guard shouldStaggerDrawerCards else { return nil }

        return .timingCurve(
            0.175,
            0.885,
            0.32,
            1.075,
            duration: MotionTiming.drawerCardEntrance * durationMultiplier
        )
            .delay(Double(index) * 0.03 * durationMultiplier)
    }

    private func restartDrawerCardStagger() {
        guard shouldStaggerDrawerCards else {
            drawerCardsVisible = true
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            drawerCardsVisible = false
        }

        DispatchQueue.main.async {
            guard shouldStaggerDrawerCards else {
                drawerCardsVisible = true
                return
            }
            drawerCardsVisible = true
        }
    }

    private func handle(_ action: ClipCardAction, for item: ClipItem) {
        switch action {
        case .select:
            focusManager.clearSearchFocus()
            selectedItem = item
        case .copy:
            viewModel.copyItem(item)
        case .copyAndPaste:
            focusManager.clearSearchFocus()
            viewModel.copyAndPaste(item)
        case .toggleFavorite:
            viewModel.toggleFavorite(item)
        case .togglePin:
            selectedItem = item
            viewModel.togglePin(item)
        case .delete:
            viewModel.deleteItem(item)
        }
    }

    private var revealSpacer: some View {
        Color.clear
            .frame(width: contentPadding)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SoftMaterialCardTransition: ViewModifier {
    let scale: CGFloat
    let blurRadius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blurRadius)
            .opacity(opacity)
    }
}

// MARK: - Preview

#if DEBUG
struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        CardGridView(selectedItem: .constant(nil))
            .environmentObject(ClipboardViewModel.preview)
            .environmentObject(FocusManager())
            .frame(height: 200)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
