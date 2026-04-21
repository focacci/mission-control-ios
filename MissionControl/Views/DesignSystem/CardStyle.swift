import SwiftUI

enum CardChrome {
    case standard
    case compact
}

struct CardStyle: ViewModifier {
    let chrome: CardChrome

    func body(content: Content) -> some View {
        switch chrome {
        case .standard:
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        case .compact:
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension View {
    func cardStyle(_ chrome: CardChrome = .standard) -> some View {
        modifier(CardStyle(chrome: chrome))
    }
}
