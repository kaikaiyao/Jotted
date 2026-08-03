import CoreGraphics

public enum AdaptiveBoardMode: Sendable, Equatable {
    case full
    case condensed
}

public enum AdaptiveBoardLayout {
    public static func initialMode(
        for size: CGSize,
        fullReturnSize: CGSize
    ) -> AdaptiveBoardMode {
        size.width >= fullReturnSize.width && size.height >= fullReturnSize.height
            ? .full
            : .condensed
    }

    public static func resolvedMode(
        current: AdaptiveBoardMode,
        size: CGSize,
        condensedEntrySize: CGSize,
        fullReturnSize: CGSize
    ) -> AdaptiveBoardMode {
        switch current {
        case .full:
            return size.width < condensedEntrySize.width || size.height < condensedEntrySize.height
                ? .condensed
                : .full
        case .condensed:
            return size.width >= fullReturnSize.width && size.height >= fullReturnSize.height
                ? .full
                : .condensed
        }
    }
}
