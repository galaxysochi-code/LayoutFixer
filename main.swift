// LayoutFixer — личный аналог Punto Switcher для macOS (EN <-> RU).
//
// Принципы приватности:
//  * Нажатия клавиш НИКОГДА не пишутся на диск и не уходят в сеть (в коде нет ни одного сетевого вызова).
//  * В памяти хранится только текущее слово (коды клавиш) и последнее слово — для отмены.
//    Буфер очищается на границе слова, при клике мышью, смене приложения и т.п.
//  * Поля паролей (Secure Input / AXSecureTextField) и менеджеры паролей полностью игнорируются.
//  * Единственное, что сохраняется, — список слов-исключений (только буквы, 2–40 символов),
//    который пополняется, когда вы отменяете автозамену. Файл обычный текстовый — его можно открыть и проверить.

import Cocoa
import Carbon
import SwiftUI

// MARK: - Константы

let kOwnEventTag: Int64 = 0x4C_46_49_58 // метка наших собственных событий ("LFIX")

let kBackspace: UInt16 = 51, kSpace: UInt16 = 49, kReturn: UInt16 = 36, kTab: UInt16 = 48
let kEnter: UInt16 = 76, kEscape: UInt16 = 53
let resetKeys: Set<UInt16> = [123, 124, 125, 126, 115, 119, 116, 121, 117, 53] // стрелки, Home/End, PgUp/PgDn, Del, Esc

let modifierKeyNames: [UInt16: String] = [
    54: "Правый ⌘", 55: "Левый ⌘", 58: "Левый ⌥", 61: "Правый ⌥",
    59: "Левый ⌃", 62: "Правый ⌃", 56: "Левый ⇧", 60: "Правый ⇧", 63: "fn",
]

let excludedApps: Set<String> = [
    "com.apple.keychainaccess", "com.apple.Passwords",
    "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
    "com.lastpass.LastPass", "org.keepassxc.keepassxc", "com.dashlane.dashlanephonefinal",
]

// MARK: - Горячие клавиши

struct Hotkey: Codable, Hashable {
    var keyCode: UInt16
    var mods: UInt64        // только ⌘⌃⌥⇧
    var modifierOnly: Bool  // одиночное нажатие модификатора (например, правый ⌥)

    static let relevantMods: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    static func mods(of flags: CGEventFlags) -> UInt64 {
        flags.intersection(relevantMods).rawValue
    }

    var title: String {
        if modifierOnly { return (modifierKeyNames[keyCode] ?? "Модификатор \(keyCode)") + " (нажать и отпустить)" }
        let f = CGEventFlags(rawValue: mods)
        var s = ""
        if f.contains(.maskControl) { s += "⌃" }
        if f.contains(.maskAlternate) { s += "⌥" }
        if f.contains(.maskShift) { s += "⇧" }
        if f.contains(.maskCommand) { s += "⌘" }
        return s + keyName(keyCode)
    }
}

func keyName(_ code: UInt16) -> String {
    let special: [UInt16: String] = [
        49: "Пробел", 36: "Return", 48: "Tab", 51: "⌫", 53: "Esc", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]
    if let s = special[code] { return s }
    if let en = Layouts.shared.en { return en.char(KeyStroke(code: code, mods: 0)).uppercased() }
    return "#\(code)"
}

enum HotkeyAction: String, CaseIterable, Identifiable {
    case undo              // отменить только что сделанную замену
    case convert           // перевести текущее/последнее слово в другую раскладку
    case convertSelection  // перевести выделенный текст в другую раскладку
    case caseSelection     // инвертировать регистр выделенного текста
    case translitSelection // транслитерация выделенного текста

    var id: String { rawValue }

    var title: String {
        switch self {
        case .undo: return "Отменить замену"
        case .convert: return "Сменить раскладку слова"
        case .convertSelection: return "Сменить раскладку выделенного"
        case .caseSelection: return "Сменить регистр выделенного"
        case .translitSelection: return "Транслитерация выделенного"
        }
    }

    var hint: String {
        switch self {
        case .undo: return "Сразу после замены: вернуть как было и запомнить слово"
        case .convert: return "Принудительно: слово, которое набираете, или последнее слово"
        case .convertSelection: return "ghbdtn vbh → привет мир"
        case .caseSelection: return "пРИВЕТ → Привет"
        case .translitSelection: return "привет ↔ privet"
        }
    }

    var defaultHotkey: Hotkey? {
        switch self {
        case .undo: return Hotkey(keyCode: kSpace, mods: CGEventFlags.maskAlternate.rawValue, modifierOnly: false)
        case .convert: return Hotkey(keyCode: 61, mods: 0, modifierOnly: true)
        case .convertSelection: return Hotkey(keyCode: 54, mods: 0, modifierOnly: true)
        case .caseSelection, .translitSelection: return nil
        }
    }

    static let presets: [Hotkey] = [
        Hotkey(keyCode: kSpace, mods: CGEventFlags.maskAlternate.rawValue, modifierOnly: false),
        Hotkey(keyCode: kSpace, mods: CGEventFlags([.maskAlternate, .maskShift]).rawValue, modifierOnly: false),
        Hotkey(keyCode: kSpace, mods: CGEventFlags([.maskControl, .maskAlternate]).rawValue, modifierOnly: false),
        Hotkey(keyCode: 61, mods: 0, modifierOnly: true),
        Hotkey(keyCode: 54, mods: 0, modifierOnly: true),
        Hotkey(keyCode: 62, mods: 0, modifierOnly: true),
        Hotkey(keyCode: 60, mods: 0, modifierOnly: true),
        Hotkey(keyCode: kSpace, mods: CGEventFlags.maskCommand.rawValue, modifierOnly: false), // если Spotlight переназначен
    ]
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var autoFix: Bool {
        get { d.object(forKey: "autoFix") as? Bool ?? true }
        set { d.set(newValue, forKey: "autoFix") }
    }

    var typoFix: Bool {
        get { d.object(forKey: "typoFix") as? Bool ?? true }
        set { d.set(newValue, forKey: "typoFix") }
    }

    var sound: Bool {
        get { d.bool(forKey: "sound") }
        set { d.set(newValue, forKey: "sound") }
    }

    var autoTextOn: Bool {
        get { d.object(forKey: "autoTextOn") as? Bool ?? true }
        set { d.set(newValue, forKey: "autoTextOn") }
    }

    /// Сокращение (строчными) -> текст. Заполняется только вами вручную.
    var autoText: [String: String] {
        get { d.dictionary(forKey: "autoText") as? [String: String] ?? [:] }
        set { d.set(newValue, forKey: "autoText") }
    }

    /// Программы, в которых LayoutFixer ничего не делает (bundle id).
    var excludedApps: [String] {
        get { d.stringArray(forKey: "excludedApps") ?? [] }
        set { d.set(newValue, forKey: "excludedApps") }
    }

    func hotkey(_ a: HotkeyAction) -> Hotkey? {
        if d.bool(forKey: "hotkey.\(a.rawValue).off") { return nil }
        guard let data = d.data(forKey: "hotkey.\(a.rawValue)"),
              let hk = try? JSONDecoder().decode(Hotkey.self, from: data) else { return a.defaultHotkey }
        return hk
    }

    func setHotkey(_ hk: Hotkey?, for a: HotkeyAction) {
        d.set(hk == nil, forKey: "hotkey.\(a.rawValue).off")
        if let hk, let data = try? JSONEncoder().encode(hk) { d.set(data, forKey: "hotkey.\(a.rawValue)") }
    }
}

// MARK: - Раскладки

struct KeyStroke {
    let code: UInt16
    let mods: UInt32 // для UCKeyTranslate: 2 = Shift, 4 = Caps Lock

    init(code: UInt16, mods: UInt32) { self.code = code; self.mods = mods }
    init(_ e: CGEvent) {
        code = UInt16(e.getIntegerValueField(.keyboardEventKeycode))
        var m: UInt32 = 0
        if e.flags.contains(.maskShift) { m |= 2 }
        if e.flags.contains(.maskAlphaShift) { m |= 4 }
        mods = m
    }
}

final class Layout {
    let source: TISInputSource
    let id: String
    let lang: String
    private let data: Data

    init?(_ src: TISInputSource) {
        guard let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID),
              let langPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages),
              let dataPtr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let langs = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
        guard let first = langs.first else { return nil }
        source = src
        id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        lang = String(first.prefix(2))
        data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
    }

    /// Физические ряды клавиатуры (коды клавиш) и сдвиг ряда — чтобы знать, какие буквы соседние.
    private static let rows: [([UInt16], Double)] = [
        ([12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30], 0),
        ([0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 42], 0.25),
        ([6, 7, 8, 9, 11, 45, 46, 43, 47, 44], 0.75),
    ]

    private lazy var positions: [Character: (Double, Double)] = {
        var p: [Character: (Double, Double)] = [:]
        for (r, (codes, shift)) in Self.rows.enumerated() {
            for (c, code) in codes.enumerated() {
                if let ch = char(KeyStroke(code: code, mods: 0)).lowercased().first { p[ch] = (Double(r), Double(c) + shift) }
            }
        }
        return p
    }()

    func areNeighbors(_ a: Character, _ b: Character) -> Bool {
        guard let p = positions[a], let q = positions[b] else { return false }
        return abs(p.0 - q.0) <= 1 && abs(p.1 - q.1) <= 1
    }

    func char(_ k: KeyStroke) -> String {
        data.withUnsafeBytes { raw -> String in
            guard let base = raw.baseAddress else { return "" }
            var dead: UInt32 = 0
            var len = 0
            var buf = [UniChar](repeating: 0, count: 4)
            let st = UCKeyTranslate(base.assumingMemoryBound(to: UCKeyboardLayout.self), k.code,
                                    UInt16(kUCKeyActionDown), k.mods, UInt32(LMGetKbdType()),
                                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, 4, &len, &buf)
            return st == noErr ? String(utf16CodeUnits: buf, count: len) : ""
        }
    }
}

final class Layouts {
    static let shared = Layouts()
    private(set) var en: Layout?
    private(set) var ru: Layout?

    init() { reload() }

    func reload() {
        en = nil; ru = nil
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
                      kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        for src in list {
            guard let l = Layout(src) else { continue }
            if l.lang == "en", en == nil { en = l }
            if l.lang == "ru", ru == nil { ru = l }
        }
    }

    func current() -> Layout? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let p = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
        let id = Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
        if id == en?.id { return en }
        if id == ru?.id { return ru }
        return nil
    }

    func other(_ l: Layout) -> Layout? { l === en ? ru : en }
}

// MARK: - Словари (системная проверка орфографии macOS, всё локально)

final class Speller {
    private let checker = NSSpellChecker.shared
    private var codes: [String: String] = [:]

    init() {
        for lang in ["en", "ru"] {
            let avail = checker.availableLanguages
            codes[lang] = avail.first { $0 == lang } ?? avail.first { $0.hasPrefix(lang) }
        }
    }

    var missing: [String] { ["en", "ru"].filter { codes[$0] == nil } }

    func isWord(_ w: String, _ lang: String) -> Bool {
        guard let code = codes[lang], isWordish(w) else { return false }
        let r = checker.checkSpelling(of: w, startingAt: 0, language: code, wrap: false,
                                      inSpellDocumentWithTag: 0, wordCount: nil)
        return r.location == NSNotFound
    }

    /// Как слово правильно пишется: само слово, либо с заглавной, если это название
    /// («нидерланды» -> «Нидерланды», «london» -> «London»). nil — такого слова нет.
    func knownForm(_ w: String, _ lang: String) -> String? {
        if isWord(w, lang) { return w }
        guard w == w.lowercased() else { return nil }
        let cap = w.prefix(1).uppercased() + w.dropFirst()
        return isWord(cap, lang) ? cap : nil
    }

    /// Исправление опечатки или nil.
    /// Срабатывает, только если macOS уверена, что это опечатка (есть автоисправление). Из её вариантов
    /// выбираем тот, что ближе по клавиатуре: «менб» -> «меню» (Б рядом с Ю), а не «меня».
    /// Допускается одна ошибка (или два промаха по соседним клавишам), иначе слово не трогаем.
    func correction(_ w: String, _ layout: Layout) -> String? {
        guard let code = codes[layout.lang], w.count >= 4, isWordish(w) else { return nil }
        let rest = w.dropFirst()
        guard rest == rest.lowercased() || w == w.uppercased() else { return nil } // «vAsYa», iPhone — не трогаем
        let lower = w.lowercased()
        let range = NSRange(location: 0, length: (lower as NSString).length)
        guard let auto = checker.correction(forWordRange: range, in: lower, language: code, inSpellDocumentWithTag: 0)
        else { return nil }
        let guesses = checker.guesses(forWordRange: range, in: lower, language: code, inSpellDocumentWithTag: 0) ?? []
        let candidates = ([auto] + guesses.prefix(6)).map { $0.lowercased() }
            .filter { $0 != lower && isWordish($0) }
            .filter { $0.count == lower.count || lower.count >= 6 } // лишнюю/пропущенную букву — только в длинных словах
        let scored = candidates.map { ($0, typoCost(lower, $0, near: layout.areNeighbors)) }
        guard let (fixed, cost) = scored.min(by: { $0.1 < $1.1 }), cost <= 1 else { return nil }
        if w == w.uppercased() { return fixed.uppercased() }
        if w.first!.isUppercase { return fixed.prefix(1).uppercased() + fixed.dropFirst() }
        return fixed
    }
}

/// «Цена» опечатки (Дамерау–Левенштейн с учётом клавиатуры):
/// промах по соседней клавише = 0.5, другая замена / лишняя / пропущенная буква = 1, перестановка соседних = 1.
func typoCost(_ a: String, _ b: String, near: (Character, Character) -> Bool) -> Double {
    let a = Array(a), b = Array(b)
    if a.isEmpty || b.isEmpty { return Double(max(a.count, b.count)) }
    var d = [[Double]](repeating: [Double](repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { d[i][0] = Double(i) }
    for j in 0...b.count { d[0][j] = Double(j) }
    for i in 1...a.count {
        for j in 1...b.count {
            let x = a[i - 1], y = b[j - 1]
            let sub: Double = x == y ? 0 : (near(x, y) ? 0.5 : 1)
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + sub)
            if i > 1, j > 1, x == b[j - 2], a[i - 2] == y { d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1) }
        }
    }
    return d[a.count][b.count]
}

/// Только буквы (внутри слова допускаются ' и -). Никаких цифр, @, точек и т.п.
func isWordish(_ s: String) -> Bool {
    guard let f = s.first, let l = s.last, f.isLetter, l.isLetter else { return false }
    return s.allSatisfy { $0.isLetter || $0 == "'" || $0 == "-" }
}

// MARK: - Исключения (единственное, что пишется на диск)

final class Exceptions {
    private(set) var words: Set<String> = []
    let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LayoutFixer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("exceptions.txt")
    }()

    init() { load() }

    func load() {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        words = Set(text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter(Self.acceptable))
    }

    static func acceptable(_ w: String) -> Bool { (2...40).contains(w.count) && isWordish(w) }

    func contains(_ w: String) -> Bool { words.contains(w.lowercased()) }

    func add(_ w: String) {
        let w = w.lowercased()
        guard Self.acceptable(w), !words.contains(w) else { return }
        words.insert(w)
        save()
    }

    func remove(_ w: String) {
        words.remove(w.lowercased())
        save()
    }

    func save() {
        let text = "# Слова, которые LayoutFixer не будет исправлять. По одному в строке.\n"
            + words.sorted().joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Отправка событий

enum Delim {
    case key(UInt16)   // пробел / Return / Tab — повторяем тем же кодом клавиши
    case text(String)  // знак препинания — печатаем как текст

    var length: Int {
        switch self {
        case .key: return 1
        case .text(let s): return s.count
        }
    }
}

enum Poster {
    static let source = CGEventSource(stateID: .privateState)

    static func key(_ code: UInt16, flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: kOwnEventTag)
            e.post(tap: .cghidEventTap)
        }
    }

    static func text(_ s: String) {
        let units = Array(s.utf16)
        var i = 0
        while i < units.count {
            let chunk = Array(units[i..<min(i + 16, units.count)])
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                e.flags = []
                chunk.withUnsafeBufferPointer { e.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: $0.baseAddress) }
                e.setIntegerValueField(.eventSourceUserData, value: kOwnEventTag)
                e.post(tap: .cghidEventTap)
            }
            i += 16
        }
    }

    static func backspaces(_ n: Int) { for _ in 0..<n { key(kBackspace) } }

    static func delim(_ d: Delim) {
        switch d {
        case .key(let c): key(c)
        case .text(let s): text(s)
        }
    }
}

// MARK: - Выделенный текст (как «Shift+Break» в Punto)

enum TextTools {
    enum Kind { case layout, invertCase, translit }

    /// Копируем выделение (⌘C), меняем, вставляем (⌘V) и возвращаем прежний буфер обмена.
    /// Текст нигде не сохраняется — только в памяти на доли секунды.
    /// false — программа точно сообщила, что выделения нет. Если она не отвечает, считаем, что есть.
    static func hasSelection() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sys, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused, CFGetTypeID(el) == AXUIElementGetTypeID() else { return true }
        var sel: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el as! AXUIElement, kAXSelectedTextAttribute as CFString, &sel) == .success,
              let text = sel as? String else { return true }
        return !text.isEmpty
    }

    static func transformSelection(_ kind: Kind, after delay: TimeInterval = 0) {
        // Проверку выделения делаем в фоне: обращаться к Accessibility из обработчика клавиш нельзя.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            guard hasSelection() else { return } // ничего не выделено — не трогаем (иначе VS Code скопирует всю строку)
            DispatchQueue.main.async { copyChangePaste(kind) }
        }
    }

    private static func copyChangePaste(_ kind: Kind) {
        let pb = NSPasteboard.general
        let saved: [[(NSPasteboard.PasteboardType, Data)]] = (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        }
        let before = pb.changeCount
        Poster.key(8, flags: .maskCommand) // ⌘C
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard pb.changeCount != before, let text = pb.string(forType: .string), !text.isEmpty else { return }
            var target: Layout?
            let out: String
            switch kind {
            case .layout: (out, target) = convertLayout(text)
            case .invertCase: out = String(text.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) })
            case .translit: out = translit(text)
            }
            pb.clearContents()
            pb.setString(out, forType: .string)
            Poster.key(9, flags: .maskCommand) // ⌘V
            if let target { TISSelectInputSource(target.source) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pb.clearContents()
                let items = saved.map { pairs -> NSPasteboardItem in
                    let item = NSPasteboardItem()
                    for (t, d) in pairs { item.setData(d, forType: t) }
                    return item
                }
                if !items.isEmpty { pb.writeObjects(items) }
            }
        }
    }

    static func convertLayout(_ text: String) -> (String, Layout?) {
        guard let en = Layouts.shared.en, let ru = Layouts.shared.ru else { return (text, nil) }
        var enToRu: [Character: Character] = [:], ruToEn: [Character: Character] = [:]
        for code: UInt16 in 0...50 where ![36, 48, 49].contains(code) {
            for mods: UInt32 in [0, 2] {
                guard let e = en.char(KeyStroke(code: code, mods: mods)).first,
                      let r = ru.char(KeyStroke(code: code, mods: mods)).first, e != r else { continue }
                if enToRu[e] == nil { enToRu[e] = r }
                if ruToEn[r] == nil { ruToEn[r] = e }
            }
        }
        let cyr = text.filter { $0.isLetter && !$0.isASCII }.count
        let lat = text.filter { $0.isLetter && $0.isASCII }.count
        let map = cyr > lat ? ruToEn : enToRu
        // Буквы меняем всегда. Знак препинания становится буквой, только если он внутри слова
        // («pf,jnf» -> «забота»), а в конце слова остаётся знаком («ltkf,» -> «дела,»).
        let chars = Array(text)
        var out = ""
        for (i, ch) in chars.enumerated() {
            guard let m = map[ch] else { out.append(ch); continue }
            if ch.isLetter { out.append(m); continue }
            let prevLetter = i > 0 && chars[i - 1].isLetter
            let nextLetter = i + 1 < chars.count && chars[i + 1].isLetter
            out.append(m.isLetter && nextLetter && (prevLetter || i == 0 || !chars[i - 1].isLetter) ? m : ch)
        }
        return (out, cyr > lat ? en : ru)
    }

    static let ruLat: [Character: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "yo", "ж": "zh", "з": "z", "и": "i",
        "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t",
        "у": "u", "ф": "f", "х": "kh", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch", "ъ": "", "ы": "y", "ь": "",
        "э": "e", "ю": "yu", "я": "ya",
    ]

    static func translit(_ text: String) -> String {
        let hasCyr = text.contains { $0.isLetter && !$0.isASCII }
        if hasCyr {
            return text.map { ch -> String in
                guard let l = ruLat[Character(ch.lowercased())] else { return String(ch) }
                return ch.isUppercase ? l.prefix(1).uppercased() + l.dropFirst() : l
            }.joined()
        }
        // латиница -> кириллица: сначала длинные сочетания
        let pairs: [(String, String)] = [("shch", "щ"), ("zh", "ж"), ("kh", "х"), ("ts", "ц"), ("ch", "ч"), ("sh", "ш"),
                                         ("yo", "ё"), ("yu", "ю"), ("ya", "я"), ("a", "а"), ("b", "б"), ("v", "в"),
                                         ("g", "г"), ("d", "д"), ("e", "е"), ("z", "з"), ("i", "и"), ("y", "й"),
                                         ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"), ("o", "о"), ("p", "п"),
                                         ("r", "р"), ("s", "с"), ("t", "т"), ("u", "у"), ("f", "ф"), ("h", "х"),
                                         ("c", "ц"), ("w", "в"), ("x", "кс"), ("j", "дж"), ("q", "к")]
        var out = "", rest = Substring(text)
        outer: while let first = rest.first {
            for (lat, var cyr) in pairs where rest.lowercased().hasPrefix(lat) {
                // «y» после согласной — «ы» (novyy -> новый), иначе «й» (kakoy -> какой)
                if lat == "y", let prev = out.last, prev.isLetter, !"аеёиоуыэюяьъй".contains(Character(prev.lowercased())) { cyr = "ы" }
                out += first.isUppercase ? cyr.uppercased() : cyr
                rest = rest.dropFirst(lat.count)
                continue outer
            }
            out.append(first)
            rest = rest.dropFirst()
        }
        return out
    }
}

// MARK: - Основная логика

struct LastWord {
    var shown: String         // что сейчас на экране
    var other: String         // то же слово в другой раскладке
    var shownLayout: Layout
    var otherLayout: Layout
    var delim: Delim
    var wasAuto: Bool         // было ли это автозаменой
    var originalWord: String  // исходное слово (для списка исключений)
    var isTypo = false        // исправление опечатки (раскладка не менялась)
}

/// Снимок настроек в памяти: обработчик нажатий не должен лезть даже в UserDefaults.
struct SettingsSnapshot {
    var autoFix = true, typoFix = true, autoTextOn = true
    var hotkeys: [HotkeyAction: Hotkey] = [:]
}

/// Главное правило этого класса: в потоке обработчика нажатий нельзя делать ничего,
/// что ждёт ответа системы (проверка орфографии, Accessibility, смена раскладки, диск).
/// Любое ожидание там останавливает ввод во всей системе. Поэтому обработчик только
/// запоминает нажатия, а решения принимаются потом, в главном потоке.
final class Switcher {
    var tap: CFMachPort?
    let layouts = Layouts.shared
    let speller = Speller()
    let exceptions = Exceptions()
    let settings = Settings.shared

    private let lock = NSLock()
    private var current: [KeyStroke] = []
    private var lastWord: LastWord?
    private var manualLocked = false
    private var generation = 0
    private var snapshot = SettingsSnapshot()
    private var pendingModifier: UInt16?
    private var cachedFieldIsSecure = false
    private var _recording: HotkeyAction?

    var onRecorded: (() -> Void)?

    var recording: HotkeyAction? {
        get { lock.lock(); defer { lock.unlock() }; return _recording }
        set { lock.lock(); _recording = newValue; lock.unlock() }
    }

    // MARK: настройки и фоновые проверки (главный поток)

    func refreshSettings() {
        var s = SettingsSnapshot()
        s.autoFix = settings.autoFix
        s.typoFix = settings.typoFix
        s.autoTextOn = settings.autoTextOn
        for a in HotkeyAction.allCases { s.hotkeys[a] = settings.hotkey(a) }
        lock.lock(); snapshot = s; lock.unlock()
    }

    /// Поле пароля проверяет отдельный поток: этот запрос ждёт ответа активной программы.
    func startSecureMonitor() {
        Thread.detachNewThread { [weak self] in
            Thread.current.name = "secure-field-monitor"
            while true {
                let v = Switcher.focusedFieldIsSecure()
                self?.lock.lock()
                self?.cachedFieldIsSecure = v
                self?.lock.unlock()
                Thread.sleep(forTimeInterval: 0.4)
            }
        }
    }

    static func focusedFieldIsSecure() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sys, 0.2)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused, CFGetTypeID(el) == AXUIElementGetTypeID() else { return false }
        var sub: CFTypeRef?
        AXUIElementCopyAttributeValue(el as! AXUIElement, kAXSubroleAttribute as CFString, &sub)
        return (sub as? String) == kAXSecureTextFieldSubrole
    }

    private func secureContext() -> Bool {
        if IsSecureEventInputEnabled() { return true }
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedApps.contains(id) || settings.excludedApps.contains(id) || id == Bundle.main.bundleIdentifier { return true }
        lock.lock(); defer { lock.unlock() }
        return cachedFieldIsSecure
    }

    func reset() {
        lock.lock()
        current = []
        lastWord = nil
        manualLocked = false
        pendingModifier = nil
        generation &+= 1
        lock.unlock()
    }

    // MARK: обработчик нажатий (отдельный поток, без ожиданий)

    private func pass(_ e: CGEvent) -> Unmanaged<CGEvent>? { Unmanaged.passUnretained(e) }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            reset()
            return pass(event)
        case .flagsChanged:
            return handleFlags(event)
        case .keyDown:
            if event.getIntegerValueField(.eventSourceUserData) == kOwnEventTag { return pass(event) }
            return handleKey(event)
        default:
            return pass(event)
        }
    }

    private func handleFlags(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == kOwnEventTag { return pass(event) }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard modifierKeyNames[code] != nil else { return pass(event) }
        let pressed = !event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn]).isEmpty

        if pressed {
            let others = event.flags.intersection(Hotkey.relevantMods).rawValue & ~modifierMask(code)
            lock.lock(); pendingModifier = others == 0 ? code : nil; lock.unlock()
            return pass(event)
        }
        lock.lock()
        let wasClean = pendingModifier == code
        pendingModifier = nil
        let rec = _recording
        lock.unlock()
        guard wasClean else { return pass(event) }

        let hk = Hotkey(keyCode: code, mods: 0, modifierOnly: true)
        if let action = rec {
            finishRecording(action, hk)
        } else if let action = matchHotkey(hk) {
            _ = trigger(action)
        }
        return pass(event)
    }

    private func modifierMask(_ code: UInt16) -> UInt64 {
        switch code {
        case 54, 55: return CGEventFlags.maskCommand.rawValue
        case 58, 61: return CGEventFlags.maskAlternate.rawValue
        case 59, 62: return CGEventFlags.maskControl.rawValue
        case 56, 60: return CGEventFlags.maskShift.rawValue
        default: return 0
        }
    }

    private func matchHotkey(_ hk: Hotkey) -> HotkeyAction? {
        lock.lock(); defer { lock.unlock() }
        for a in HotkeyAction.allCases where snapshot.hotkeys[a] == hk { return a }
        return nil
    }

    private func finishRecording(_ action: HotkeyAction, _ hk: Hotkey) {
        lock.lock(); _recording = nil; lock.unlock()
        DispatchQueue.main.async {
            self.settings.setHotkey(hk, for: action)
            self.refreshSettings()
            self.onRecorded?()
        }
    }

    private func handleKey(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let mods = Hotkey.mods(of: flags)

        lock.lock(); pendingModifier = nil; let rec = _recording; lock.unlock()

        if let action = rec { // запись своего сочетания
            if code == kEscape && mods == 0 {
                lock.lock(); _recording = nil; lock.unlock()
                DispatchQueue.main.async { self.onRecorded?() }
                return nil
            }
            let name = keyName(code)
            let isFKey = name.hasPrefix("F") && name.count <= 3
            if mods & ~CGEventFlags.maskShift.rawValue != 0 || isFKey {
                finishRecording(action, Hotkey(keyCode: code, mods: mods, modifierOnly: false))
                return nil
            }
            return pass(event)
        }

        if let action = matchHotkey(Hotkey(keyCode: code, mods: mods, modifierOnly: false)) {
            if trigger(action) { return nil } // сработало — клавишу съедаем
            return pass(event)
        }

        if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            reset()
            return pass(event)
        }

        if code == kBackspace {
            lock.lock()
            if current.isEmpty { lastWord = nil } else { current.removeLast() }
            generation &+= 1
            lock.unlock()
            return pass(event)
        }
        if resetKeys.contains(code) {
            reset()
            return pass(event)
        }
        if code == kSpace { finishWord(.key(kSpace), keepLast: true); return pass(event) }
        if code == kReturn || code == kEnter || code == kTab {
            // менять текст после Enter поздно (сообщение уже отправлено) — просто забываем слово
            reset()
            return pass(event)
        }

        let ks = KeyStroke(event)
        let en = layouts.en.map { $0.char(ks) } ?? ""   // UCKeyTranslate — локальная таблица, без ожиданий
        let ru = layouts.ru.map { $0.char(ks) } ?? ""
        if [en, ru].contains(where: { $0.count == 1 && $0.first!.isLetter }) {
            lock.lock()
            if current.isEmpty { lastWord = nil }
            if current.count < 40 { current.append(ks) } else { current = []; manualLocked = true }
            generation &+= 1
            lock.unlock()
            return pass(event)
        }

        var len = 0
        var buf = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &len, unicodeString: &buf)
        let s = String(utf16CodeUnits: buf, count: len)
        if !s.isEmpty, s.allSatisfy({ $0.isPunctuation || $0.isSymbol }) {
            finishWord(.text(s), keepLast: true)
        } else {
            reset() // цифры и прочее: слово «испорчено» (логины, коды) — не трогаем
        }
        return pass(event)
    }

    /// Слово закончено. Клавиша уже ушла в программу; решение принимаем следом, в главном потоке.
    private func finishWord(_ delim: Delim, keepLast: Bool) {
        lock.lock()
        let keys = current
        let locked = manualLocked
        current = []
        manualLocked = false
        generation &+= 1
        let gen = generation
        if keys.isEmpty { lastWord = nil }
        lock.unlock()
        guard !keys.isEmpty, !locked else { return }
        DispatchQueue.main.async { self.evaluate(keys, delim, gen) }
    }

    private func trigger(_ action: HotkeyAction) -> Bool {
        switch action {
        case .undo:
            lock.lock()
            let ok = current.isEmpty && (lastWord?.wasAuto ?? false)
            lock.unlock()
            guard ok else { return false }
            DispatchQueue.main.async { self.performSwap() }
            return true
        case .convert:
            lock.lock()
            let ok = !current.isEmpty || lastWord != nil
            lock.unlock()
            guard ok else { return false }
            DispatchQueue.main.async { self.performConvert() }
            return true
        case .convertSelection:
            DispatchQueue.main.async { TextTools.transformSelection(.layout) }
            return true
        case .caseSelection:
            DispatchQueue.main.async { TextTools.transformSelection(.invertCase) }
            return true
        case .translitSelection:
            DispatchQueue.main.async { TextTools.transformSelection(.translit) }
            return true
        }
    }

    // MARK: решения (главный поток — здесь можно обращаться к словарям и раскладкам)

    /// Ещё не поздно править? (пользователь не успел набрать что-то ещё)
    private func stillFresh(_ gen: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == gen && current.isEmpty
    }

    private func setLast(_ lw: LastWord?) {
        lock.lock(); lastWord = lw; lock.unlock()
    }

    private func evaluate(_ keys: [KeyStroke], _ delim: Delim, _ gen: Int) {
        guard let cur = layouts.current(), let alt = layouts.other(cur) else { setLast(nil); return }
        let shown = keys.map(cur.char).joined()
        let other = keys.map(alt.char).joined()
        lock.lock(); let snap = snapshot; lock.unlock()

        if !secureContext(), stillFresh(gen) {
            if snap.autoTextOn {
                let table = settings.autoText
                if let expansion = table[shown.lowercased()] ?? table[other.lowercased()] {
                    replace(shown.count + delim.length, with: expansion, delim: delim, switchTo: nil)
                    setLast(LastWord(shown: expansion, other: shown, shownLayout: cur, otherLayout: cur,
                                     delim: delim, wasAuto: true, originalWord: "", isTypo: true))
                    return
                }
            }
            if snap.autoFix, let (fixed, original) = decide(keys, cur: cur, alt: alt) {
                replace(shown.count + delim.length, with: fixed, delim: delim, switchTo: alt)
                if settings.sound { NSSound(named: "Tink")?.play() }
                setLast(LastWord(shown: fixed, other: shown, shownLayout: alt, otherLayout: cur,
                                 delim: delim, wasAuto: true, originalWord: original))
                return
            }
            if snap.typoFix, let (fixed, original) = decideTypo(keys, cur: cur) {
                replace(shown.count + delim.length, with: fixed, delim: delim, switchTo: nil)
                setLast(LastWord(shown: fixed, other: shown, shownLayout: cur, otherLayout: cur,
                                 delim: delim, wasAuto: true, originalWord: original, isTypo: true))
                return
            }
        }
        setLast(LastWord(shown: shown, other: other, shownLayout: cur, otherLayout: alt,
                         delim: delim, wasAuto: false, originalWord: ""))
    }

    private func replace(_ count: Int, with text: String, delim: Delim, switchTo: Layout?) {
        Poster.backspaces(count)
        Poster.text(text)
        Poster.delim(delim)
        if let switchTo { TISSelectInputSource(switchTo.source) }
    }

    /// Сколько последних клавиш — знаки препинания в текущей раскладке ("ghbdtn," -> "привет,")
    private func tailLength(_ c: [String]) -> Int {
        var tail = 0
        while tail < 3, c.count - tail > 2, !(c[c.count - 1 - tail].first?.isLetter ?? false) { tail += 1 }
        return tail
    }

    private func decide(_ keys: [KeyStroke], cur: Layout, alt: Layout) -> (String, String)? {
        guard keys.count >= 2 else { return nil }
        let c = keys.map(cur.char), a = keys.map(alt.char)
        let tail = tailLength(c)
        let n = keys.count - tail
        let curWord = c[..<n].joined(), curTail = c[n...].joined()

        if exceptions.contains(curWord) || speller.knownForm(curWord, cur.lang) != nil { return nil }

        let altAll = a.joined()
        if tail > 0, let w = speller.knownForm(altAll, alt.lang) { return (w, curWord) }
        let altWord = a[..<n].joined()
        if altWord.count >= 2, let w = speller.knownForm(altWord, alt.lang) { return (w + curTail, curWord) }
        return nil
    }

    /// Опечатка в правильной раскладке: «менб» -> «меню».
    private func decideTypo(_ keys: [KeyStroke], cur: Layout) -> (String, String)? {
        let c = keys.map(cur.char)
        let n = keys.count - tailLength(c)
        let word = c[..<n].joined(), tail = c[n...].joined()
        guard !exceptions.contains(word), speller.knownForm(word, cur.lang) == nil,
              let fixed = speller.correction(word, cur) else { return nil }
        return (fixed + tail, word)
    }

    /// Объяснение для раздела «Проверка»: что программа сделает с таким словом и почему.
    func explain(_ typed: String) -> String {
        let word = typed.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return "" }
        guard let cur = layouts.current(), let alt = layouts.other(cur) else {
            return "Сейчас активна раскладка, которую программа не знает (нужны английская и русская)."
        }
        if word.count < 2 { return "Слишком короткое слово — такие не заменяются." }
        if exceptions.contains(word) { return "«\(word)» в списке исключений (раздел «Правила») — не заменяется." }
        if let form = speller.knownForm(word, cur.lang) {
            return "«\(form)» — обычное слово в текущей раскладке, заменять нечего."
        }
        let (other, _) = TextTools.convertLayout(word)
        if let form = speller.knownForm(other, alt.lang) { return "Заменит на «\(form)» и переключит раскладку." }
        if let fixed = speller.correction(word, cur) { return "Опечатка: исправит на «\(fixed)»." }
        var why = "Не заменит: «\(other)» в другой раскладке — не слово из словаря."
        if !isWordish(other) { why += " В нём есть цифры или знаки, а такие слова программа не трогает." }
        return why
    }

    // MARK: действия по горячим клавишам (главный поток)

    private func performConvert() {
        lock.lock()
        let keys = current
        let lw = lastWord
        lock.unlock()
        guard let cur = layouts.current(), let alt = layouts.other(cur) else { return }
        if !keys.isEmpty {
            Poster.backspaces(keys.count)
            Poster.text(keys.map(alt.char).joined())
            TISSelectInputSource(alt.source)
            lock.lock(); manualLocked = true; lock.unlock()
            return
        }
        if lw != nil { performSwap(); return }

        // Программа это слово не отслеживала (был клик мышью, Enter, переход в другое окно).
        // Тогда выделяем последнее слово сами (⇧⌥←) и переводим его принудительно, без словаря.
        Poster.key(123, flags: [.maskShift, .maskAlternate])
        TextTools.transformSelection(.layout, after: 0.12)
    }

    private func performSwap() {
        lock.lock()
        guard let lw = lastWord else { lock.unlock(); return }
        lock.unlock()
        Poster.backspaces(lw.shown.count + lw.delim.length)
        Poster.text(lw.other)
        Poster.delim(lw.delim)
        TISSelectInputSource(lw.otherLayout.source)
        if lw.wasAuto { exceptions.add(lw.originalWord) } // запоминаем: это слово исправлять не надо
        setLast(lw.isTypo ? nil
                : LastWord(shown: lw.other, other: lw.shown, shownLayout: lw.otherLayout,
                           otherLayout: lw.shownLayout, delim: lw.delim, wasAuto: false, originalWord: ""))
    }
}

// MARK: - Меню в строке меню

/// Значок-клавиша «A / Ф», как на клавиатуре Mac. Шаблонное изображение: macOS сама красит его под тему.
func keycapImage(warning: Bool) -> NSImage {
    let size = NSSize(width: 20, height: 18)
    let img = NSImage(size: size, flipped: false) { _ in
        let key = NSRect(x: 1, y: 1, width: 18, height: 16)
        NSColor.black.setFill()
        NSColor.black.setStroke()
        let font = NSFont.systemFont(ofSize: 8.5, weight: .heavy)
        if warning { // нет доступа — пустая клавиша-контур
            let outline = NSBezierPath(roundedRect: key.insetBy(dx: 0.75, dy: 0.75), xRadius: 3.5, yRadius: 3.5)
            outline.lineWidth = 1.5
            outline.stroke()
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            NSAttributedString(string: "A", attributes: attrs).draw(at: NSPoint(x: 3.5, y: 6.5))
            NSAttributedString(string: "Ф", attributes: attrs).draw(at: NSPoint(x: 9.5, y: 1))
            return true
        }
        NSBezierPath(roundedRect: key, xRadius: 4, yRadius: 4).fill()

        // буквы «вырезаем» из клавиши
        let ctx = NSGraphicsContext.current!
        ctx.compositingOperation = .destinationOut
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        NSAttributedString(string: "A", attributes: attrs).draw(at: NSPoint(x: 3.5, y: 6.5))
        NSAttributedString(string: "Ф", attributes: attrs).draw(at: NSPoint(x: 9.5, y: 1))
        ctx.compositingOperation = .sourceOver
        return true
    }
    img.isTemplate = true
    img.accessibilityDescription = "LayoutFixer"
    return img
}

let switcher = Switcher()

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    switcher.handle(type, event)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    let model = SettingsModel()

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = keycapImage(warning: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        switcher.onRecorded = { [weak self] in self?.model.refresh() }
        model.onChange = { [weak self] in
            switcher.refreshSettings()
            self?.updateTitle()
        }

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in
            switcher.reset()
        }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main) { _ in Layouts.shared.reload() }

        switcher.refreshSettings()
        switcher.startSecureMonitor()

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        if !startTap() {
            showSettings(nil) // нет доступа — сразу показываем окно с подсказкой
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
                if self?.startTap() == true { t.invalidate() }
            }
        }
        updateTitle()
    }

    /// Повторный запуск из «Программ» / Finder / Dock — открываем настройки.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings(nil)
        return true
    }

    /// Перехват живёт в собственном потоке со своим циклом событий.
    /// В главном потоке ему делать нечего: любая задержка там останавливала бы ввод в системе.
    func startTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask: CGEventMask = [CGEventType.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        let ready = DispatchSemaphore(value: 0)
        var created = false
        Thread.detachNewThread {
            Thread.current.name = "key-tap"
            guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                              eventsOfInterest: mask, callback: tapCallback, userInfo: nil) else {
                ready.signal()
                return
            }
            switcher.tap = tap
            let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            created = true
            ready.signal()
            CFRunLoopRun()
        }
        ready.wait()
        guard created else { return false }
        updateTitle()
        model.refresh()
        return true
    }

    func updateTitle() {
        guard let button = statusItem?.button else { return }
        let working = switcher.tap != nil
        button.image = keycapImage(warning: !working)
        button.appearsDisabled = working && !Settings.shared.autoFix
        button.toolTip = !working ? "LayoutFixer: нет доступа"
            : (Settings.shared.autoFix ? "LayoutFixer" : "LayoutFixer: автопереключение выключено")
    }

    @objc func showSettings(_ sender: Any?) {
        model.refresh()
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(m: model)))
            w.title = "LayoutFixer"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if switcher.tap == nil {
            menu.addItem(disabled("⚠︎ Нет доступа — откройте настройки"))
            menu.addItem(.separator())
        }
        let auto = item("Автопереключение раскладки", #selector(toggleAuto))
        auto.state = Settings.shared.autoFix ? .on : .off
        menu.addItem(auto)
        let typo = item("Исправлять опечатки", #selector(toggleTypo))
        typo.state = Settings.shared.typoFix ? .on : .off
        menu.addItem(typo)
        menu.addItem(.separator())
        menu.addItem(item("Настройки…", #selector(showSettings(_:)), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Выйти", #selector(quit), key: "q"))
    }

    private func item(_ t: String, _ s: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: t, action: s, keyEquivalent: key)
        i.target = self
        return i
    }

    private func disabled(_ t: String) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    @objc func toggleAuto() { Settings.shared.autoFix.toggle(); switcher.refreshSettings(); updateTitle(); model.refresh() }
    @objc func toggleTypo() { Settings.shared.typoFix.toggle(); switcher.refreshSettings(); model.refresh() }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
