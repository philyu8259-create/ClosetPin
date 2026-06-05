import SwiftData
import SwiftUI
import UIKit

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clothingItems: [ClothingItem]
    @Query private var preferences: [UserPreference]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var debugSeedReady = false
    @State private var selectedTab: AppTab = .today
    @State private var closetAddItemRequest: AddClosetItemRequest?
    @State private var debugSheet: DebugSheet?
    @State private var isKeyboardVisible = false

    var body: some View {
        Group {
            if shouldAutoSeedDebugSampleCapsule {
                Group {
                    if debugSeedReady {
                        tabShell
                    } else {
                        debugBootstrapView
                    }
                }
                .task {
                    prepareDebugSampleCapsuleIfNeeded()
                }
            } else {
                if shouldShowOnboarding {
                    WorkCapsuleOnboardingView(
                        onCompleted: completeOnboarding,
                        onStartAdding: startAddingFromOnboarding
                    )
                } else {
                    tabShell
                }
            }
        }
        .sheet(item: $debugSheet) { sheet in
            switch sheet {
            case .addItem:
                AddEditItemView()
            }
        }
        .task {
            presentDebugSheetIfNeeded()
        }
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            TodayView(onOpenLooks: {
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .looks
                }
            }, onOpenCloset: {
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .closet
                }
            }, onAddClosetItem: { initialType in
                closetAddItemRequest = AddClosetItemRequest(initialType: initialType)
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .closet
                }
            }, onOpenSettings: {
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .settings
                }
            })
                .tag(AppTab.today)

            ClosetView(openAddItemRequest: closetAddItemRequest, onOpenToday: {
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .today
                }
            })
                .tag(AppTab.closet)

            LooksView(onOpenToday: {
                withAnimation(.snappy(duration: 0.28)) {
                    selectedTab = .today
                }
            })
                .tag(AppTab.looks)

            SettingsView()
                .tag(AppTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                EditorialTabBar(selection: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.snappy(duration: 0.2)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy(duration: 0.2)) {
                isKeyboardVisible = false
            }
        }
    }

    private var shouldAutoSeedDebugSampleCapsule: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["CLOSETPIN_DEBUG_PRESEED_SAMPLE_CAPSULE"] == "1"
#else
        false
#endif
    }

    private var shouldShowOnboarding: Bool {
        clothingItems.isEmpty && !effectiveHasCompletedOnboarding
    }

    private var effectiveHasCompletedOnboarding: Bool {
#if DEBUG
        if ProcessInfo.processInfo.environment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] == "1" {
            return ProcessInfo.processInfo.environment["CLOSETPIN_DEBUG_HAS_COMPLETED_ONBOARDING"] == "1"
        }
#endif
        return hasCompletedOnboarding
    }

    private var debugBootstrapView: some View {
        ZStack {
            DesignSystem.background
                .ignoresSafeArea()

            ProgressView()
                .tint(DesignSystem.accent)
        }
    }

    @MainActor
    private func prepareDebugSampleCapsuleIfNeeded() {
#if DEBUG
        guard shouldAutoSeedDebugSampleCapsule else { return }
        guard !debugSeedReady else { return }

        if clothingItems.isEmpty {
            _ = try? WorkCapsuleSeeder.insertSampleCapsule(in: modelContext)
        }

        applyDebugPreferenceOverridesIfNeeded()
        debugSeedReady = true
#endif
    }

    @MainActor
    private func applyDebugPreferenceOverridesIfNeeded() {
#if DEBUG
        guard ProcessInfo.processInfo.environment["CLOSETPIN_DEBUG_TOMORROW_WEATHER_ENABLED"] == "1" else {
            return
        }

        let locationName = ProcessInfo.processInfo.environment["CLOSETPIN_DEBUG_TOMORROW_WEATHER_LOCATION"] ?? ""
        if let preference = preferences.first {
            preference.tomorrowWeatherEnabled = true
            preference.tomorrowWeatherLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
            preference.updatedAt = Date()
        } else {
            modelContext.insert(UserPreference(tomorrowWeatherEnabled: true, tomorrowWeatherLocationName: locationName))
        }
#endif
    }

    @MainActor
    private func presentDebugSheetIfNeeded() {
#if DEBUG
        guard ProcessInfo.processInfo.environment["CLOSETPIN_DEBUG_PRESENT_ADD_ITEM"] == "1" else { return }
        guard debugSheet == nil else { return }
        debugSheet = .addItem
#endif
    }

    @MainActor
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    @MainActor
    private func startAddingFromOnboarding() {
        hasCompletedOnboarding = true
    }
}

struct AddClosetItemRequest: Identifiable, Equatable {
    let id = UUID()
    let initialType: ClothingType?
}

private enum DebugSheet: Identifiable {
    case addItem

    var id: String {
        switch self {
        case .addItem:
            "addItem"
        }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case today
    case closet
    case looks
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .today:
            "tab.today"
        case .closet:
            "tab.closet"
        case .looks:
            "tab.looks"
        case .settings:
            "tab.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            "sparkles"
        case .closet:
            "square.grid.2x2.fill"
        case .looks:
            "calendar"
        case .settings:
            "gearshape.fill"
        }
    }

    var accessibilityIdentifier: String {
        "appTab_\(rawValue)"
    }
}

private struct EditorialTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .semibold))

                        Text(L10n.text(tab.titleKey))
                            .font(DesignSystem.tabLabelFont)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? DesignSystem.ink : DesignSystem.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(DesignSystem.surfaceElevated.opacity(0.92))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(DesignSystem.premiumGold.opacity(0.35), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                                .matchedGeometryEffect(id: "tabSelection", in: selectionAnimation)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DesignSystem.surface.opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.32)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(DesignSystem.border.opacity(0.85), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 10)
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
