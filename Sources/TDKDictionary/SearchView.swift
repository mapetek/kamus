import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [WordResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var popover: NSPopover?
    
    var body: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Kelime ara...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
            
            // Results
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Aranıyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            } else if let error = errorMessage {
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
                .frame(maxWidth: .infinity)
            } else if results.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("Kelime bulunamadı")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else if !results.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(results, id: \.madde_id) { result in
                            WordDetailView(result: result)
                        }
                    }
                    .padding(.horizontal, 12)
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
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("⌥⇧D - Aç/Kapat")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { popover?.performClose(nil) }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 400, height: 500)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                results = try await TDKAPIClient.searchWord(searchText)
                isLoading = false
            } catch {
                errorMessage = "Hata: \(error.localizedDescription)"
                isLoading = false
            }
        }
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
                            .foregroundColor(.gray)
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
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(anlam.anlam)
                                    .font(.body)
                                    .lineLimit(nil)
                                
                                // Part of speech
                                if let ozellik = anlam.ozelliklerListe?.first {
                                    Text(ozellik.kisa_adi)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(3)
                                }
                                
                                // Examples
                                if let ornekler = anlam.orneklerListe, !ornekler.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        ForEach(ornekler.prefix(2), id: \.ornek_id) { ornek in
                                            HStack(alignment: .top, spacing: 6) {
                                                Text("•")
                                                    .foregroundColor(.gray)
                                                Text(ornek.ornek)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
                    
                    Text(result.birlesikler)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .cornerRadius(6)
    }
}
