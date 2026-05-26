import Foundation

enum L10n {
    static func text(_ key: String, bundle: Bundle = .main) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func string(_ key: String, bundle: Bundle = .main) -> String {
        text(key, bundle: bundle)
    }

    static func string(_ key: String, bundle: Bundle = .main, arguments: CVarArg...) -> String {
        let format = text(key, bundle: bundle)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
