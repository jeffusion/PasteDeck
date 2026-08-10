//
//  Localization.swift
//  PasteDeck
//

import Foundation

enum AppLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
    case russian = "ru"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let normalized = identifier.replacingOccurrences(of: "_", with: "-")
            let components = normalized.split(separator: "-").map(String.init)
            guard let languageCode = components.first?.lowercased() else { continue }

            switch languageCode {
            case "en":
                return .english
            case "ja":
                return .japanese
            case "ru":
                return .russian
            case "zh":
                let subtags = components.dropFirst().map { $0.lowercased() }
                if subtags.contains("hant") || subtags.contains("tw") || subtags.contains("hk") || subtags.contains("mo") {
                    continue
                }
                return .simplifiedChinese
            default:
                continue
            }
        }

        return .english
    }
}

enum L10n {
    static let language: AppLanguage = {
        let bundlePreferences = Bundle.main.preferredLocalizations
        let preferences = bundlePreferences.isEmpty ? Locale.preferredLanguages : bundlePreferences
        return AppLanguage.resolve(preferredLanguages: preferences)
    }()

    static let locale = language.locale

    static func string(_ key: String, language: AppLanguage? = nil) -> String {
        let requestedLanguage = language ?? self.language
        return resolve(
            key,
            primaryBundle: localizedBundle(for: requestedLanguage),
            fallbackBundle: requestedLanguage == .english ? nil : localizedBundle(for: .english)
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...,
        language: AppLanguage? = nil
    ) -> String {
        let resolvedLanguage = language ?? self.language
        return String(
            format: string(key, language: resolvedLanguage),
            locale: resolvedLanguage.locale,
            arguments: arguments
        )
    }

    static func plural(_ key: String, count: Int, language: AppLanguage? = nil) -> String {
        format(key, Int64(count), language: language)
    }

    static func relativeTime(
        from date: Date,
        relativeTo referenceDate: Date = Date(),
        language: AppLanguage? = nil
    ) -> String {
        let resolvedLanguage = language ?? self.language
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = resolvedLanguage.locale
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }

    static func byteCount(_ bytes: Int64, language: AppLanguage? = nil) -> String {
        let resolvedLanguage = language ?? self.language
        return bytes.formatted(
            .byteCount(style: .file)
                .locale(resolvedLanguage.locale)
        )
    }

    static func integer(_ value: Int, language: AppLanguage? = nil) -> String {
        let resolvedLanguage = language ?? self.language
        return value.formatted(.number.locale(resolvedLanguage.locale))
    }

    private static let resourceContainer: Bundle = {
        return Bundle.main
    }()

    private static let localizedBundles: [AppLanguage: Bundle] = {
        Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
            let candidates = [language.rawValue, language.rawValue.lowercased()]
            for candidate in candidates {
                if let path = resourceContainer.path(forResource: candidate, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return (language, bundle)
                }
            }
            return nil
        })
    }()

    static func localizedBundle(for language: AppLanguage) -> Bundle? {
        localizedBundles[language]
    }

    static func resolve(
        _ key: String,
        primaryBundle: Bundle?,
        fallbackBundle: Bundle?
    ) -> String {
        if let primaryBundle {
            let value = primaryBundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        if let fallbackBundle {
            let value = fallbackBundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key {
                return value
            }
        }

        return key
    }
}
