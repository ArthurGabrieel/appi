import SwiftUI
import Foundation

struct ResponseBodyView: View {
    let response: Response

    var body: some View {
        ScrollView {
            Text(formattedBody)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .accessibilityLabel(String(localized: "response.bodyContent"))
    }

    private var formattedBody: String {
        guard !response.body.isEmpty else {
            return String(localized: "response.emptyBody")
        }

        if response.contentType?.contains("json") == true,
           let json = try? JSONSerialization.jsonObject(with: response.body),
           let prettyData = try? JSONSerialization.data(
               withJSONObject: json,
               options: [.prettyPrinted, .sortedKeys]
           ),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return String(data: response.body, encoding: .utf8)
            ?? String(localized: "response.binaryData")
    }
}
