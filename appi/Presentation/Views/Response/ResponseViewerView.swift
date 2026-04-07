import SwiftUI

struct ResponseViewerView: View {
    let response: Response

    @State private var selectedTab: ResponseTab = .body

    enum ResponseTab: String, CaseIterable {
        case body, headers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Text("\(response.statusCode)")
                    .font(.headline)
                    .foregroundStyle(statusColor)
                Text(response.statusMessage)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(localized: "response.duration \(formattedDuration)"))
                    .foregroundStyle(.secondary)
                Text(String(localized: "response.size \(formattedSize)"))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityLabel(String(localized: "response.status"))

            Picker("", selection: $selectedTab) {
                Text(String(localized: "response.body")).tag(ResponseTab.body)
                Text(String(localized: "response.headers")).tag(ResponseTab.headers)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedTab {
            case .body:
                ResponseBodyView(response: response)
            case .headers:
                ResponseHeadersView(headers: response.headers)
            }
        }
    }

    private var statusColor: Color {
        switch response.statusCode {
        case 200..<300: return .green
        case 300..<400: return .orange
        case 400..<500: return .red
        default: return .red
        }
    }

    private var formattedDuration: String {
        if response.duration < 1 {
            return String(format: "%.0fms", response.duration * 1000)
        }
        return String(format: "%.2fs", response.duration)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(response.size), countStyle: .file)
    }
}
