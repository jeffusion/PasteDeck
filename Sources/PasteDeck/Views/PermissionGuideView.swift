//
//  PermissionGuideView.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import ApplicationServices

/// Modern step-by-step SwiftUI view for accessibility permission guidance
struct PermissionGuideView: View {
    // MARK: - Properties

    @State private var currentStep = 1
    @State private var hasPermission = false
    @State private var showSuccessAnimation = false
    @State private var pollingTimer: Timer?

    var onClose: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                switch currentStep {
                case 1:
                    WelcomeStepView(onNext: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentStep = 2
                        }
                    })
                case 2:
                    InstructionStepView(
                        onBack: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStep = 1
                            }
                        },
                        onOpenSettings: {
                            openAccessibilitySettings()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStep = 3
                            }
                        }
                    )
                case 3:
                    WaitingStepView(
                        hasPermission: $hasPermission,
                        showSuccessAnimation: $showSuccessAnimation,
                        onBack: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStep = 2
                            }
                        },
                        onComplete: {
                            closeWindow()
                        }
                    )
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Divider()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { step in
                    Circle()
                        .fill(currentStep == step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentStep == step ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 480)
        .onAppear {
            checkPermission()
            startPermissionPolling()
        }
        .onDisappear {
            stopPermissionPolling()
        }
    }

    // MARK: - Helper Methods

    private func checkPermission() {
        hasPermission = AccessibilityPermissionGuide.shared.hasPermission
    }

    private func startPermissionPolling() {
        // Check permission status every 2 seconds
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                let newStatus = AccessibilityPermissionGuide.shared.hasPermission

                if newStatus && !hasPermission {
                    // Permission was just granted
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        hasPermission = true
                        showSuccessAnimation = true
                    }

                    // Auto-close after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        closeWindow()
                    }

                    stopPermissionPolling()
                }
            }
        }
    }

    private func stopPermissionPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            print("🔒 PermissionGuideView: 打开系统设置")
        }
    }

    private func closeWindow() {
        onClose?()

        // Close the window
        if let window = NSApp.windows.first(where: { $0.contentViewController is NSHostingController<PermissionGuideView> }) {
            window.close()
        }
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            // Title
            Text(L10n.string("permission.welcome.title"))
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(L10n.string("permission.welcome.description"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature comparison
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "checkmark.circle.fill",
                    text: L10n.string("permission.welcome.enabled"),
                    color: .green
                )
                FeatureRow(
                    icon: "info.circle.fill",
                    text: L10n.string("permission.welcome.disabled"),
                    color: .blue
                )
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal, 40)

            Spacer()

            // Next button
            Button(action: onNext) {
                Text(L10n.string("permission.welcome.start"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 2: Instructions

struct InstructionStepView: View {
    let onBack: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text(L10n.string("permission.instructions.title"))
                .font(.title2)
                .fontWeight(.bold)

            // Steps
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(
                    number: "1",
                    icon: "hand.tap",
                    title: L10n.string("permission.instructions.step1"),
                    iconColor: .blue
                )

                InstructionRow(
                    number: "2",
                    icon: "gearshape.2",
                    title: L10n.string("permission.instructions.step2"),
                    iconColor: .purple
                )

                InstructionRow(
                    number: "3",
                    icon: "checkmark.circle",
                    title: L10n.string("permission.instructions.step3"),
                    iconColor: .green
                )
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal, 40)

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button(L10n.string("common.back"), action: onBack)
                    .keyboardShortcut(.cancelAction)

                Button(action: onOpenSettings) {
                    Text(L10n.string("permission.open_settings"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 3: Waiting/Success

struct WaitingStepView: View {
    @Binding var hasPermission: Bool
    @Binding var showSuccessAnimation: Bool
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with animation
            Image(systemName: hasPermission ? "checkmark.circle.fill" : "hourglass")
                .font(.system(size: 60))
                .foregroundColor(hasPermission ? .green : .orange)
                .scaleEffect(showSuccessAnimation ? 1.1 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSuccessAnimation)
                .symbolRenderingMode(.hierarchical)

            // Title
            Text(L10n.string(
                hasPermission ? "permission.success.title" : "permission.waiting.title"
            ))
                .font(.title2)
                .fontWeight(.bold)

            // Description
            if hasPermission {
                Text(L10n.string("permission.success.description"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(L10n.string("permission.success.closing"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 12) {
                    Text(L10n.string("permission.waiting.description"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.blue)
                        Text(L10n.string("permission.waiting.checking"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                if !hasPermission {
                    Button(L10n.string("common.back"), action: onBack)
                        .keyboardShortcut(.cancelAction)

                    Spacer()
                } else {
                    Spacer()

                    Button(action: onComplete) {
                        Text(L10n.string("common.done"))
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Helper Components

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct InstructionRow: View {
    let number: String
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
            }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // Title
            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PermissionGuideView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionGuideView()
                .previewDisplayName(L10n.string("permission.welcome.title"))
        }
    }
}
#endif
