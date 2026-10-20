import SwiftUI

/// Settings controls for "notify me which card to use when I arrive somewhere".
struct ArrivalAlertsSection: View {
    @Environment(ArrivalMonitor.self) private var arrivals
    @Environment(\.openURL) private var openURL
    @State private var location = LocationService()
    @State private var isTesting = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { arrivals.isEnabled },
                set: { isOn in
                    if isOn { Task { await arrivals.enable() } } else { arrivals.disable() }
                }
            )) {
                Label("Notify Me on Arrival", systemImage: "bell.badge")
            }

            if arrivals.isEnabled {
                if !arrivals.hasAlwaysAccess {
                    problem("Needs location access set to Always.", button: "Open Settings")
                }
                if arrivals.notificationsDenied {
                    problem("Notifications are turned off for CardWise.", button: "Open Settings")
                }

                Button {
                    Task { await sendTest() }
                } label: {
                    HStack {
                        Text("Send a Test Alert for Here")
                        Spacer()
                        if isTesting { ProgressView() }
                    }
                }
                .disabled(isTesting)

                if !arrivals.mutedPlaces.isEmpty {
                    LabeledContent("Muted places", value: "\(arrivals.mutedPlaces.count)")
                    Button("Unmute All Places") { arrivals.clearMutedPlaces() }
                }
            }
        } header: {
            Text("Arrival alerts")
        } footer: {
            Text("When you arrive at a store or restaurant, CardWise sends a notification with the best card to use there. It can take a minute or two after you arrive. Tap and hold an alert to stop alerts for that place.")
        }
        .task { await arrivals.refreshNotificationStatus() }
    }

    private func problem(_ message: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
            Button(button) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.callout)
        }
    }

    private func sendTest() async {
        isTesting = true
        defer { isTesting = false }
        if let here = try? await location.currentLocation() {
            await arrivals.handleArrival(at: here, force: true)
        }
    }
}
