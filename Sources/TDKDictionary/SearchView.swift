import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [WordResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locale = Locale(identifier: "tr_TR")
    
    func clearSearch() {
        searchText = ""
        results = []
        errorMessage = nil
        isLoading = false
    }
    
    func setQueryAndSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchText = trimmed.lowercased(with: locale)
        performSearch()
    }
    
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        let normalized = query.lowercased(with: locale)
        if searchText != normalized {
            searchText = normalized
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // Kayıtlı kelimeyi anında veritabanından göster (çevrimdışı da çalışır).
            var servedFromCache = false
            if let cached = await DictionaryStore.shared.cachedResponse(for: normalized),
               let decoded = try? JSONDecoder().decode([WordResult].self, from: cached),
               !decoded.isEmpty {
                guard self.searchText == normalized else { return }
                self.results = decoded
                self.isLoading = false
                servedFromCache = true
            }

            do {
                let response = try await TDKAPIClient.searchWord(normalized)
                // Bu yanıt gelene kadar yeni bir arama başladıysa sonucu ezme.
                guard self.searchText == normalized else { return }
                self.results = response.results
                self.isLoading = false
                if !response.results.isEmpty {
                    await DictionaryStore.shared.save(word: normalized, responseJSON: response.raw)
                }
            } catch {
                guard self.searchText == normalized else { return }
                if servedFromCache {
                    // Çevrimdışı ama önbellekte var: sonuçlar ekranda kalsın, hata gösterme.
                    await DictionaryStore.shared.touch(word: normalized)
                } else {
                    self.errorMessage = "Hata: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @AppStorage("shortcutKeyCode") private var shortcutKeyCode: Int = ShortcutDefaults.keyCodeInt
    @AppStorage("shortcutModifiers") private var shortcutModifiers: Int = ShortcutDefaults.modifiersInt
    @FocusState private var isSearchFocused: Bool
    @State private var isShowingSettings = false
    
    var popover: NSPopover?
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Kelime ara...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .onSubmit {
                            viewModel.performSearch()
                        }

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                Divider()
                
                resultsView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                Divider()
                
                HStack {
                    Text("\(shortcutDisplay) - Aç/Kapat")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Ayarlar")
                    Button(action: { popover?.performClose(nil) }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Kapat")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(width: 400, height: 500)
            .onAppear {
                DispatchQueue.main.async {
                    isSearchFocused = true
                }
            }
            
            if isShowingSettings {
                Color.black
                    .opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowingSettings = false
                    }
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Ayarlar")
                            .font(.headline)
                        Spacer()
                        Button(action: { isShowingSettings = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(12)
                    
                    Divider()
                    
                    ScrollView {
                        SettingsView()
                    }
                    .frame(maxHeight: 260)
                }
                .frame(width: 360)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isShowingSettings)
    }

    @ViewBuilder
    private var resultsView: some View {
        if viewModel.isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Aranıyor...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.title2)
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "book.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Kelime bulunamadı")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else if !viewModel.results.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.results, id: \.madde_id) { result in
                        WordDetailView(result: result)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("TDK Sözlük")
                    .font(.headline)
                Text("Bir kelime yazarak başlayın")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(height: 120)
        }
    }
    
    private var shortcutDisplay: String {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(shortcutModifiers))
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option) { s += "⌥" }
        if mods.contains(.shift) { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        s += KeyCodeFormatter.displayString(for: UInt16(shortcutKeyCode))
        return s
    }
}

struct WordDetailView: View {
    let result: WordResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Word header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.madde)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !result.lisan.isEmpty {
                        Text(result.lisan)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // Meanings
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(result.anlamlarListe.enumerated()), id: \.offset) { index, anlam in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(anlam.anlam)
                                    .font(.body)
                                    .lineLimit(nil)
                                
                                // Part of speech
                                if let ozellik = anlam.ozelliklerListe?.first {
                                    Text(ozellik.kisa_adi)
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 7)
                                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                                }
                                
                                // Examples
                                if let ornekler = anlam.orneklerListe, !ornekler.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        ForEach(ornekler.prefix(2), id: \.ornek_id) { ornek in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("•")
                                                    .foregroundColor(.secondary)
                                                Text(ornek.ornek)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
            }
            
            // Compound words
            if !result.birlesikler.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Birleşikler")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(result.birlesikler)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}
