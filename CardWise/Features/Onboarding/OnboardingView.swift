import SwiftData
import SwiftUI

/// First launch: welcome, pick cards, pick a goal.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.modelContext) private var modelContext
    @State private var path: [Step] = []

    private enum Step: Hashable { case cards, goal }

    var body: some View {
        NavigationStack(path: $path) {
            welcome
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .cards: cardsStep
                    case .goal: goalStep
                    }
                }
        }
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                CardArtView(name: "", issuer: "", colorHex: "#2E5C9A", size: .medium)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -26, y: 8)
                CardArtView(name: "", issuer: "", colorHex: "#B8975A", size: .medium)
                    .rotationEffect(.degrees(8))
                    .offset(x: 22, y: -4)
            }
            .frame(height: 110)

            VStack(spacing: 10) {
                Text("CardWise")
                    .font(.largeTitle.weight(.bold))
                Text("Always know which card to use, wherever you're paying.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                feature("location.fill", "In person", "Finds the place you're at and picks the best card.")
                feature("magnifyingglass", "Online", "Search any store or app to see which card earns the most.")
                feature("lock.shield", "Private", "No card numbers or bank logins. Everything stays on your phone.")
            }
            .padding(.top, 8)

            Spacer()

            Button {
                path.append(.cards)
            } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var cardsStep: some View {
        CatalogPickerView(ownedIDs: [], title: "Your Cards", confirmTitle: { $0 == 0 ? "Select Your Cards" : "Continue with \($0) Card\($0 == 1 ? "" : "s")" }) { picked in
            for (index, card) in picked.enumerated() {
                modelContext.insert(UserCard(catalogCard: card, asOf: catalog.catalog.asOf, sortOrder: index))
            }
            path.append(.goal)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") { path.append(.goal) }
            }
        }
    }

    private var goalStep: some View {
        @Bindable var settings = settings
        return Form {
            Section {
            } header: {
                Text("What matters most to you? You can change this anytime in Settings.")
                    .textCase(nil)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            GoalPicker(goal: $settings.goal)
        }
        .navigationTitle("Your Goal")
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            Button {
                onFinish()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
    }
}
