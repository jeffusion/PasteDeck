import XCTest
@testable import PasteDeck

final class LocalizationTests: XCTestCase {
    func testSupportedLanguageResolution() {
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["ru-RU"]), .russian)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLanguages: ["zh-Hant-TW", "ja-JP"]), .japanese)
    }

    func testCoreTranslationsResolveInEverySupportedLanguage() {
        let expected: [AppLanguage: String] = [
            .english: "Settings",
            .simplifiedChinese: "设置",
            .japanese: "設定",
            .russian: "Настройки"
        ]

        for language in AppLanguage.allCases {
            XCTAssertEqual(
                L10n.string("window.settings.title", language: language),
                expected[language]
            )
        }
    }

    func testRussianPluralCategories() {
        XCTAssertEqual(L10n.plural("count.items", count: 1, language: .russian), "1 элемент")
        XCTAssertEqual(L10n.plural("count.items", count: 2, language: .russian), "2 элемента")
        XCTAssertEqual(L10n.plural("count.items", count: 5, language: .russian), "5 элементов")
        XCTAssertEqual(L10n.plural("count.items", count: 21, language: .russian), "21 элемент")
    }

    func testEnglishAndChinesePluralFormatting() {
        XCTAssertEqual(L10n.plural("count.files", count: 1, language: .english), "1 file")
        XCTAssertEqual(L10n.plural("count.files", count: 2, language: .english), "2 files")
        XCTAssertEqual(L10n.plural("count.files", count: 2, language: .simplifiedChinese), "2 个文件")
        XCTAssertEqual(L10n.plural("count.files", count: 2, language: .japanese), "2 ファイル")
    }

    func testMissingPrimaryTranslationFallsBackToEnglish() throws {
        let english = try XCTUnwrap(L10n.localizedBundle(for: .english))
        XCTAssertEqual(
            L10n.resolve(
                "window.settings.title",
                primaryBundle: nil,
                fallbackBundle: english
            ),
            "Settings"
        )
    }

    func testRelativeTimeAndUnitsUseRequestedLanguage() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let earlierDate = referenceDate.addingTimeInterval(-3_600)

        let relativeTimes = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { language in
            (language, L10n.relativeTime(from: earlierDate, relativeTo: referenceDate, language: language))
        })

        XCTAssertEqual(relativeTimes.values.filter { !$0.isEmpty }.count, AppLanguage.allCases.count)
        XCTAssertEqual(Set(relativeTimes.values).count, AppLanguage.allCases.count)
        XCTAssertEqual(L10n.byteCount(1_024, language: .english), "1 kB")
        XCTAssertEqual(L10n.byteCount(1_024, language: .russian), "1 кБ")
        XCTAssertEqual(L10n.plural("duration.days", count: 21, language: .russian), "21 день")
        XCTAssertNotEqual(
            L10n.integer(12_345, language: .english),
            L10n.integer(12_345, language: .russian)
        )
    }

    func testLocalizationResourcesHaveMatchingKeysAndNonemptyValues() throws {
        let englishKeys = try allKeys(for: .english)
        XCTAssertFalse(englishKeys.isEmpty)

        for language in AppLanguage.allCases {
            let bundle = try XCTUnwrap(L10n.localizedBundle(for: language))
            let keys = try allKeys(for: language)
            XCTAssertEqual(keys, englishKeys, "Mismatched localization keys for \(language.rawValue)")

            let stringsURL = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let stringsdictURL = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "stringsdict"))
            let ordinary = try dictionary(at: stringsURL)
            let plural = try dictionary(at: stringsdictURL)

            XCTAssertEqual(try sourceKeys(at: stringsURL, pattern: #"(?m)^\s*\"((?:\\.|[^\"])*)\"\s*="#).count, ordinary.count)
            XCTAssertEqual(try sourceKeys(at: stringsdictURL, pattern: #"(?m)^    <key>([^<]+)</key>"#).count, plural.count)
            for (key, value) in ordinary {
                XCTAssertFalse(key.isEmpty)
                XCTAssertFalse((value as? String)?.isEmpty ?? true, "Empty translation for \(key)")
            }
            XCTAssertTrue(allStringValuesAreNonempty(plural))
        }
    }

    func testFormatArgumentsMatchEnglishResources() throws {
        let englishBundle = try XCTUnwrap(L10n.localizedBundle(for: .english))
        let englishStrings = try dictionary(
            at: XCTUnwrap(englishBundle.url(forResource: "Localizable", withExtension: "strings"))
        )
        let englishPlural = try dictionary(
            at: XCTUnwrap(englishBundle.url(forResource: "Localizable", withExtension: "stringsdict"))
        )

        for language in AppLanguage.allCases where language != .english {
            let bundle = try XCTUnwrap(L10n.localizedBundle(for: language))
            let localizedStrings = try dictionary(
                at: XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            )
            let localizedPlural = try dictionary(
                at: XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "stringsdict"))
            )

            for key in englishStrings.keys {
                XCTAssertEqual(
                    formatTokens(in: englishStrings[key]),
                    formatTokens(in: localizedStrings[key]),
                    "Incompatible format arguments for \(key) in \(language.rawValue)"
                )
            }
            for key in englishPlural.keys {
                XCTAssertEqual(
                    formatTokens(in: englishPlural[key]),
                    formatTokens(in: localizedPlural[key]),
                    "Incompatible plural format arguments for \(key) in \(language.rawValue)"
                )
            }
        }
    }

    private func allKeys(for language: AppLanguage) throws -> Set<String> {
        let bundle = try XCTUnwrap(L10n.localizedBundle(for: language))
        let strings = try dictionary(
            at: XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        )
        let stringsdict = try dictionary(
            at: XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "stringsdict"))
        )
        return Set(strings.keys).union(stringsdict.keys)
    }

    private func dictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func sourceKeys(at url: URL, pattern: String) throws -> Set<String> {
        let source = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, range: range)
        let keys = matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[range])
        }
        XCTAssertEqual(Set(keys).count, keys.count, "Duplicate localization keys in \(url.path)")
        return Set(keys)
    }

    private func allStringValuesAreNonempty(_ value: Any) -> Bool {
        if let string = value as? String {
            return !string.isEmpty
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.values.allSatisfy(allStringValuesAreNonempty)
        }
        if let array = value as? [Any] {
            return array.allSatisfy(allStringValuesAreNonempty)
        }
        return true
    }

    private func formatTokens(in value: Any?) -> Set<String> {
        let pattern = #"%#@[^@]+@|%(?:\d+\$)?(?:@|lld|ld|d|f|s)"#
        let regex = try! NSRegularExpression(pattern: pattern)

        func tokens(in currentValue: Any?) -> [String] {
            if let string = currentValue as? String {
                let range = NSRange(string.startIndex..., in: string)
                return regex.matches(in: string, range: range).compactMap { match in
                    guard let range = Range(match.range, in: string) else { return nil }
                    return String(string[range])
                }
            }
            if let dictionary = currentValue as? [String: Any] {
                return dictionary.values.flatMap(tokens)
            }
            if let array = currentValue as? [Any] {
                return array.flatMap(tokens)
            }
            return []
        }

        return Set(tokens(in: value))
    }
}
