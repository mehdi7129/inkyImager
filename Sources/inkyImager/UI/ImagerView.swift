import SwiftUI
import AppKit
import ImagerCore

private typealias L10n = ImagerLocalization

@MainActor
struct ImagerView: View {
    @ObservedObject var model: ImagerModel
    @Environment(\.openURL) private var openURL
    @State private var passwordVisible = false
    @State private var checkingForUpdates = false
    @State private var updateFeedback: UpdateFeedback?

    private let ink = Color(red: 0.10, green: 0.11, blue: 0.12)
    private let canvas = Color(red: 0.96, green: 0.96, blue: 0.95)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                imageCard
                wifiCard
                storageCard
                footer
            }
            .padding(24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(canvas)
        .foregroundStyle(ink)
        .tint(ink)
        .preferredColorScheme(.light)
        .environment(\.locale, L10n.locale)
        .environment(\.layoutDirection, L10n.language == .ar ? .rightToLeft : .leftToRight)
        .frame(minWidth: 660, minHeight: 620)
        .onChange(of: canCheckForUpdates) { _, canCheck in
            if !canCheck { updateFeedback = nil }
        }
        .alert(item: $updateFeedback, content: updateAlert)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "sdcard")
                .font(.system(size: 25, weight: .medium))
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("inkyImager")
                    .font(.system(size: 29, weight: .semibold))
                    .tracking(-0.8)
                Text(L10n.text("Préparez la carte SD de votre cadre."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            Button(action: checkForUpdates) {
                if checkingForUpdates {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L10n.text("Recherche…"))
                    }
                } else {
                    Label(L10n.text("Mise à jour"), systemImage: "arrow.down.circle")
                }
            }
            .disabled(checkingForUpdates || !canCheckForUpdates)
            .help(L10n.text("Rechercher une mise à jour d’inkyImager"))
            .accessibilityLabel(checkingForUpdates ? L10n.text("Recherche de mise à jour en cours") : L10n.text("Rechercher une mise à jour d’inkyImager"))
        }
        .padding(.bottom, 2)
    }

    private var canCheckForUpdates: Bool {
        !model.isBusy && !model.ejectPending
    }

    private func checkForUpdates() {
        guard canCheckForUpdates, !checkingForUpdates else { return }
        checkingForUpdates = true
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        Task {
            defer { checkingForUpdates = false }
            let feedback: UpdateFeedback
            do {
                if let update = try await ImagerUpdateChecker.check(installedVersion: version) {
                    feedback = .available(update)
                } else {
                    feedback = .upToDate
                }
            } catch is URLError {
                feedback = .failed(L10n.text("Vérifiez votre connexion, puis réessayez."))
            } catch {
                feedback = .failed(error.localizedDescription)
            }
            guard canCheckForUpdates else { return }
            updateFeedback = feedback
        }
    }

    private func updateAlert(_ feedback: UpdateFeedback) -> Alert {
        switch feedback {
        case .available(let update):
            return Alert(
                title: Text(L10n.format("inkyImager %@ est disponible", update.version)),
                message: Text(L10n.text("Téléchargez le DMG, puis glissez inkyImager dans Applications.")),
                primaryButton: .default(Text(L10n.text("Télécharger le DMG"))) {
                    guard canCheckForUpdates else { return }
                    openURL(update.downloadURL)
                },
                secondaryButton: .cancel(Text(L10n.text("Plus tard")))
            )
        case .upToDate:
            return Alert(title: Text(L10n.text("inkyImager est à jour")), dismissButton: .default(Text("OK")))
        case .failed(let message):
            return Alert(title: Text(L10n.text("Impossible de vérifier la mise à jour")), message: Text(message),
                         dismissButton: .default(Text("OK")))
        }
    }

    private enum UpdateFeedback: Identifiable {
        case available(ImagerUpdate)
        case upToDate
        case failed(String)

        var id: String {
            switch self {
            case .available: return "available"
            case .upToDate: return "upToDate"
            case .failed: return "failed"
            }
        }
    }

    private var imageCard: some View {
        card {
            HStack(spacing: 14) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 23, weight: .regular))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(ink, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("InkyOS")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.text("Le système de votre cadre photo."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(L10n.text("Image intégrée"))
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(canvas, in: Capsule())
                    if !model.imageVersion.isEmpty {
                        Text(model.imageVersion)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var wifiCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(L10n.text("Votre Wi-Fi"), symbol: "wifi")

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel(L10n.text("Nom du réseau"))
                        TextField(L10n.text("Nom du Wi-Fi"), text: $model.ssid)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L10n.text("Nom du réseau Wi-Fi"))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel(L10n.text("Mot de passe"))
                        HStack(spacing: 6) {
                            Group {
                                if passwordVisible {
                                    TextField(L10n.text("Mot de passe du Wi-Fi"), text: $model.password)
                                } else {
                                    SecureField(L10n.text("Mot de passe du Wi-Fi"), text: $model.password)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel(L10n.text("Mot de passe du Wi-Fi"))

                            Button {
                                passwordVisible.toggle()
                            } label: {
                                Image(systemName: passwordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help(passwordVisible ? L10n.text("Masquer le mot de passe") : L10n.text("Afficher le mot de passe"))
                            .accessibilityLabel(passwordVisible ? L10n.text("Masquer le mot de passe") : L10n.text("Afficher le mot de passe"))
                        }
                    }
                }
                .disabled(model.isBusy || model.ejectPending)

                HStack(spacing: 6) {
                    Image(systemName: "globe.europe.africa")
                        .accessibilityHidden(true)
                    Text(L10n.format("Pays : %@", countryName))
                    Spacer(minLength: 12)
                    Text(L10n.text("Wi-Fi 2,4 GHz"))
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var storageCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle(L10n.text("Votre carte SD"), symbol: "sdcard")
                    Spacer()
                    Button {
                        model.refreshDevices()
                    } label: {
                        Label(L10n.text("Actualiser"), systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.isBusy || model.ejectPending)
                    .help(L10n.text("Rechercher les cartes SD connectées"))
                }

                Picker(L10n.text("Carte SD"), selection: $model.selectedDeviceID) {
                    Text(model.devices.isEmpty ? L10n.text("Insérez une carte SD") : L10n.text("Choisir une carte SD"))
                        .tag(Optional<String>.none)
                    ForEach(model.devices) { device in
                        Text(verbatim: "\(device.name == "Carte SD" ? L10n.text("Carte SD") : device.name) · \(capacity(device.capacity))")
                            .tag(Optional(device.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(model.isBusy || model.ejectPending || model.devices.isEmpty)
                .accessibilityLabel(L10n.text("Carte SD à installer"))

                if model.devices.isEmpty {
                    Text(L10n.text("Branchez votre carte, puis cliquez sur Actualiser."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func confirmErase(_ card: SDCard) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("Effacer et flasher ce support ?")
        let name = card.name == "Carte SD" ? L10n.text("Carte SD") : card.name
        let bytes = card.capacity.formatted(.number.grouping(.never).locale(L10n.locale))
        alert.informativeText = "\(name) · \(card.id) · \(L10n.format("%@ octets", bytes))\n\n"
            + L10n.text("Toutes les données du support sélectionné seront effacées.")
        alert.addButton(withTitle: L10n.text("Annuler l’effacement")).keyEquivalent = "\r"
        let erase = alert.addButton(withTitle: L10n.text("Flasher la carte"))
        erase.hasDestructiveAction = true
        erase.keyEquivalent = ""
        return alert.runModal() == .alertSecondButtonReturn
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.isBusy && !model.ejectPending && model.phase != .finished {
                Label(L10n.text("Toutes les données de la carte choisie seront effacées."), systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Button {
                passwordVisible = false
                model.requestFlash(confirm: confirmErase)
            } label: {
                HStack(spacing: 9) {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: model.ejectPending ? "eject" : "arrow.down.to.line")
                    }
                    Text(model.isBusy ? phaseTitle : (model.ejectPending ? L10n.text("Éjecter la carte vérifiée") : L10n.text("Flasher la carte")))
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(ink.opacity(model.canFlash || model.isBusy ? 1 : 0.30),
                            in: RoundedRectangle(cornerRadius: 13))
                .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(!model.canFlash || model.isBusy)
            .accessibilityHint(model.ejectPending ? L10n.text("Termine l’éjection de la carte déjà vérifiée.") : L10n.text("Efface la carte choisie et installe InkyOS avec votre Wi-Fi."))

            if model.isBusy {
                VStack(alignment: .leading, spacing: 7) {
                    ProgressView(value: min(max(model.progress, 0), 1))
                        .accessibilityLabel(L10n.text("Progression de l’installation"))
                    HStack {
                        Text(model.statusMessage.isEmpty ? phaseTitle : model.statusMessage)
                        Spacer(minLength: 8)
                        Text(min(max(model.progress, 0), 1).formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale)))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            } else if model.ejectPending {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Carte vérifiée, éjection à terminer."))
                            .font(.system(size: 13, weight: .semibold))
                        Text(L10n.text("Terminez l’éjection avant de retirer la carte."))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.66, green: 0.43, blue: 0.12))
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            } else if model.phase == .finished {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Votre carte est prête."))
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.statusMessage.isEmpty ? L10n.text("Vous pouvez la retirer et allumer votre cadre.") : model.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 0.18, green: 0.46, blue: 0.32))
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            } else if let error = model.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.68, green: 0.19, blue: 0.17))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityElement(children: .combine)
            } else if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var phaseTitle: String {
        switch model.phase {
        case .idle: L10n.text("Prête à installer")
        case .preparing: L10n.text("Préparation de l’image…")
        case .writing: L10n.text("Écriture de la carte…")
        case .verifying: L10n.text("Vérification de la carte…")
        case .configuring: L10n.text("Configuration du Wi-Fi…")
        case .ejecting: L10n.text("Éjection de la carte…")
        case .finished: model.ejectPending ? L10n.text("Carte vérifiée") : L10n.text("Carte prête")
        case .failed: L10n.text("Installation interrompue")
        }
    }

    private var countryName: String {
        L10n.locale.localizedString(forRegionCode: model.country.uppercased())
            ?? model.country.uppercased()
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 15, weight: .semibold))
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(ink.opacity(0.07), lineWidth: 1)
            }
    }

    private func capacity(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file).locale(L10n.locale))
    }
}
