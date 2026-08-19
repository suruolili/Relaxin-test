import CoreGraphics

enum HomeContentLayout {
    static let minimumTopSpacing: CGFloat = 32
    static let terminalHeight: CGFloat = 300
    static let creditsTerminalHeight: CGFloat = terminalHeight
    static let minimumMenuViewportHeight: CGFloat = 150
    static let minimumBottomSpacing: CGFloat = 32

    static var minimumMenuLayoutHeight: CGFloat {
        minimumTopSpacing
            + terminalHeight
            + minimumMenuViewportHeight
            + minimumBottomSpacing
    }
}
