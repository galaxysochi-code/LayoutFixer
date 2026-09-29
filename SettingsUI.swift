// Окно настроек LayoutFixer. Журнала набранного текста здесь нет намеренно.

import SwiftUI
import ServiceManagement

// MARK: - Модель

final class SettingsModel: ObservableObject {
    private let s = Settings.shared
    var onChange: (() -> Void)?

    @Published var accessOK = false
    @Published var recording: HotkeyAction?
    @Published var exceptions: [String] = []
    @Published var autoText: [(key: String, value: String)] = []
    @Published var apps: [String] = []
    @Published var loginError: String?

    init() {
        refresh()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.accessOK != (switcher.tap != nil) { self.accessOK = switcher.tap != nil }
        }
    }

    func refresh() {
        switcher.refreshSettings()
        accessOK = switcher.tap != nil
        recording = switcher.recording
        exceptions = switcher.exceptions.words.sorted()
        autoText = s.autoText.sorted { $0.key < $1.key }.map { (key: $0.key, value: $0.value) }
        apps = s.excludedApps
        objectWillChange.send()
    }

    func toggle(_ get: @escaping () -> Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: { set($0); self.objectWillChange.send(); self.onChange?() })
    }

    var autoFix: Binding<Bool> { toggle({ self.s.autoFix }, { self.s.autoFix = $0 }) }
    var typoFix: Binding<Bool> { toggle({ self.s.typoFix }, { self.s.typoFix = $0 }) }
    var sound: Binding<Bool> { toggle({ self.s.sound }, { self.s.sound = $0 }) }
    var autoTextOn: Binding<Bool> { toggle({ self.s.autoTextOn }, { self.s.autoTextOn = $0 }) }

    var uiLanguage: Binding<UILanguage> {
        Binding(get: { UILanguage(rawValue: self.s.uiLanguage) ?? .auto },
                set: { self.s.uiLanguage = $0.rawValue; self.refresh(); self.onChange?() })
    }

    var launchAtLogin: Binding<Bool> {
        toggle({ SMAppService.mainApp.status == .enabled }, { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                self.loginError = nil
            } catch {
                self.loginError = "Не получилось: \(error.localizedDescription). Программа должна лежать в «Программах»."
            }
        })
    }

    // горячие клавиши
    func hotkey(_ a: HotkeyAction) -> Hotkey? { s.hotkey(a) }
    func setHotkey(_ hk: Hotkey?, _ a: HotkeyAction) { s.setHotkey(hk, for: a); refresh() }
    func startRecording(_ a: HotkeyAction) { switcher.recording = a; refresh() }
    func stopRecording() { switcher.recording = nil; refresh() }

    // слова-исключения
    func addException(_ w: String) -> Bool {
        let w = w.trimmingCharacters(in: .whitespaces)
        guard Exceptions.acceptable(w.lowercased()) else { return false }
        switcher.exceptions.add(w)
        refresh()
        return true
    }
    func removeException(_ w: String) { switcher.exceptions.remove(w); refresh() }

    // автозамена
    func addAutoText(_ key: String, _ value: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces).lowercased()
        guard (2...20).contains(k.count), k.allSatisfy(\.isLetter), !value.isEmpty else { return false }
        var t = s.autoText
        t[k] = value
        s.autoText = t
        refresh()
        return true
    }
    func removeAutoText(_ key: String) {
        var t = s.autoText
        t[key] = nil
        s.autoText = t
        refresh()
    }

    // словари
    func languageName(_ code: String) -> String {
        let locale = Locale(identifier: currentUILanguage())
        let name = locale.localizedString(forIdentifier: code) ?? Locale.current.localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    var availableLanguages: [String] {
        switcher.speller.available.sorted { languageName($0) < languageName($1) }
    }

    func isLanguageOn(_ code: String) -> Bool { s.spellLanguages.contains(code) }

    func setLanguage(_ code: String, _ on: Bool) {
        var list = s.spellLanguages
        if on { if !list.contains(code) { list.append(code) } } else { list.removeAll { $0 == code } }
        s.spellLanguages = list
        switcher.speller.reload()
        refresh()
    }

    // программы
    func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        var list = s.excludedApps
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !list.contains(id) { list.append(id) }
        }
        s.excludedApps = list
        refresh()
    }
    func removeApp(_ id: String) { s.excludedApps.removeAll { $0 == id }; refresh() }
}

func appInfo(_ bundleID: String) -> (name: String, icon: NSImage?) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return (bundleID, nil) }
    return (FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
            NSWorkspace.shared.icon(forFile: url.path))
}

// MARK: - Окно

struct SettingsView: View {
    @ObservedObject var m: SettingsModel

    var body: some View {
        TabView {
            GeneralTab(m: m).tabItem { Label(tr("Общие"), systemImage: "gearshape") }
            HotkeysTab(m: m).tabItem { Label(tr("Горячие клавиши"), systemImage: "keyboard") }
            RulesTab(m: m).tabItem { Label(tr("Правила"), systemImage: "character.book.closed") }
            AutoTextTab(m: m).tabItem { Label(tr("Автозамена"), systemImage: "text.insert") }
            AppsTab(m: m).tabItem { Label(tr("Программы"), systemImage: "square.grid.2x2") }
            LanguagesTab(m: m).tabItem { Label(tr("Языки"), systemImage: "character.book.closed.fill") }
            CheckTab().tabItem { Label(tr("Проверка"), systemImage: "stethoscope") }
            PrivacyTab().tabItem { Label(tr("Приватность"), systemImage: "lock.shield") }
        }
        .padding()
        .frame(width: 720, height: 520)
    }
}

// MARK: Общие

struct GeneralTab: View {
    @ObservedObject var m: SettingsModel

    var body: some View {
        Form {
            Section(tr("Состояние")) {
                HStack {
                    Image(systemName: m.accessOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(m.accessOK ? .green : .orange)
                    Text(m.accessOK ? tr("Работает") : tr("Нет доступа к клавиатуре"))
                    Spacer()
                    if !m.accessOK {
                        Button(tr("Открыть «Универсальный доступ»")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                }
                if !m.accessOK {
                    Text(tr("Нажмите «+», выберите Программы → LayoutFixer и включите переключатель. Если программа уже в списке — удалите её «−» и добавьте заново."))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                statusRow(tr("Раскладки"), ok: Layouts.shared.latinMain != nil && Layouts.shared.cyrillicMain != nil,
                          good: Layouts.shared.all.compactMap { $0.localizedName }.joined(separator: ", "),
                          bad: tr("Нужны две раскладки: латинская и кириллическая"))
                statusRow(tr("Словари"), ok: switcher.speller.missingScripts.isEmpty,
                          good: switcher.speller.languages.map { m.languageName($0) }.joined(separator: ", "),
                          bad: tr("Выберите словари обоих алфавитов в разделе «Языки»"))
            }
            Section(tr("Исправление")) {
                Toggle(tr("Автоматически переключать раскладку (ghbdtn → привет)"), isOn: m.autoFix)
                Toggle(tr("Исправлять опечатки (менб → меню)"), isOn: m.typoFix)
                Toggle(tr("Автозамена сокращений (см. раздел «Автозамена»)"), isOn: m.autoTextOn)
            }
            Section(tr("Прочее")) {
                Toggle(tr("Звук при переключении раскладки"), isOn: m.sound)
                Toggle(tr("Запускать при входе в систему"), isOn: m.launchAtLogin)
                if let e = m.loginError { Text(e).font(.callout).foregroundStyle(.red) }
            }
            Section(tr("Язык интерфейса")) {
                Picker(tr("Язык интерфейса"), selection: m.uiLanguage) {
                    ForEach(UILanguage.allCases) { l in Text(l.title).tag(l) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            Section(tr("О программе")) {
                HStack {
                    Text("LayoutFixer")
                    Spacer()
                    Text("версия \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(tr("Разработчик"))
                    Spacer()
                    Text("Vladislav Tolmachev").foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    func statusRow(_ title: String, ok: Bool, good: String, bad: String) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
            Text(title)
            Spacer()
            Text(ok ? good : bad).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
        }
    }
}

// MARK: Горячие клавиши

struct HotkeysTab: View {
    @ObservedObject var m: SettingsModel

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { a in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title)
                            Text(a.hint).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if m.recording == a {
                            Text(tr("Нажмите сочетание…")).foregroundStyle(Color.accentColor)
                            Button(tr("Отмена")) { m.stopRecording() }
                        } else {
                            Menu(m.hotkey(a)?.title ?? tr("Не задано")) {
                                ForEach(HotkeyAction.presets, id: \.self) { hk in
                                    Button(hk.title) { m.setHotkey(hk, a) }
                                }
                                Divider()
                                Button(tr("Записать своё сочетание…")) { m.startRecording(a) }
                                    .disabled(!m.accessOK)
                                Button(tr("Выключить")) { m.setHotkey(nil, a) }
                            }
                            .frame(width: 260)
                        }
                    }
                }
            } footer: {
                Text(tr("Своё сочетание: нажмите клавиши с ⌘, ⌃ или ⌥, F-клавишу, либо нажмите и отпустите один модификатор (например, правый ⌘). Esc — отмена.\n⌘Пробел и ⌃Пробел macOS по умолчанию забирает себе (Spotlight и смена раскладки). «Отменить замену» срабатывает только сразу после замены — в остальное время сочетание работает как обычно."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}


// MARK: Правила

struct RulesTab: View {
    @ObservedObject var m: SettingsModel
    @State private var newWord = ""
    @State private var bad = false

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField(tr("Новое слово"), text: $newWord)
                        .textFieldStyle(.roundedBorder).labelsHidden().onSubmit(add)
                    Button("Добавить", action: add).disabled(newWord.isEmpty)
                }
                if bad { Text(tr("Только буквы, от 2 до 40 символов")).font(.caption).foregroundStyle(.red) }
            } header: {
                Text(tr("Слова, которые не исправлять"))
            } footer: {
                Text(tr("Слово попадает сюда само, когда вы отменяете замену. Хранится только список этих слов."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Список (\(m.exceptions.count))") {
                if m.exceptions.isEmpty { Text("Пока пусто").foregroundStyle(.secondary) }
                ForEach(m.exceptions, id: \.self) { w in
                    HStack {
                        Text(w)
                        Spacer()
                        Button { m.removeException(w) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func add() {
        bad = !m.addException(newWord)
        if !bad { newWord = "" }
    }
}

// MARK: Автозамена

struct AutoTextTab: View {
    @ObservedObject var m: SettingsModel
    @State private var key = ""
    @State private var value = ""
    @State private var bad = false

    var body: some View {
        Form {
            Section {
                Toggle(tr("Включить автозамену"), isOn: m.autoTextOn)
                HStack {
                    TextField(tr("Сокращение"), text: $key)
                        .textFieldStyle(.roundedBorder).labelsHidden().frame(width: 140)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    TextField(tr("Текст"), text: $value)
                        .textFieldStyle(.roundedBorder).labelsHidden().onSubmit(add)
                    Button(tr("Добавить"), action: add).disabled(key.isEmpty || value.isEmpty)
                }
                if bad { Text(tr("Сокращение — только буквы, 2–20 символов")).font(.caption).foregroundStyle(.red) }
            } header: {
                Text(tr("Сокращения"))
            } footer: {
                Text(tr("Наберите сокращение и пробел — оно заменится текстом. Работает в любой раскладке: «спс» и «cgc» — одно и то же. ⌥Пробел сразу после — отменить."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Список (\(m.autoText.count))") {
                if m.autoText.isEmpty { Text(tr("Например: спс → Спасибо!")).foregroundStyle(.secondary) }
                ForEach(m.autoText, id: \.key) { item in
                    HStack {
                        Text(item.key).bold().frame(width: 120, alignment: .leading)
                        Text(item.value).lineLimit(1).foregroundStyle(.secondary)
                        Spacer()
                        Button { m.removeAutoText(item.key) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func add() {
        bad = !m.addAutoText(key, value)
        if !bad { key = ""; value = "" }
    }
}

// MARK: Программы

struct AppsTab: View {
    @ObservedObject var m: SettingsModel

    var body: some View {
        Form {
            Section {
                if m.apps.isEmpty { Text(tr("Пока пусто")).foregroundStyle(.secondary) }
                ForEach(m.apps, id: \.self) { id in
                    let info = appInfo(id)
                    HStack {
                        if let icon = info.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
                        Text(info.name)
                        Spacer()
                        Button { m.removeApp(id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                Button(tr("Добавить программу…")) { m.addApp() }
            } header: {
                Text(tr("В этих программах LayoutFixer ничего не делает"))
            } footer: {
                Text(tr("Удобно для игр, Терминала, удалённого рабочего стола."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Всегда исключены")) {
                Text(tr("Поля паролей во всех программах, а также менеджеры паролей: Пароли, Связка ключей, 1Password, Bitwarden, LastPass, KeePassXC, Dashlane."))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Языки

struct LanguagesTab: View {
    @ObservedObject var m: SettingsModel

    var body: some View {
        Form {
            Section {
                ForEach(m.availableLanguages, id: \.self) { code in
                    Toggle(isOn: Binding(get: { m.isLanguageOn(code) }, set: { m.setLanguage(code, $0) })) {
                        HStack {
                            Text(m.languageName(code))
                            Text(code).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(tr("Словари для проверки слов"))
            } footer: {
                Text(tr("Нужен хотя бы один словарь с латиницей (английский, испанский…) и русский для кириллицы. Слово считается правильным, если оно есть хотя бы в одном выбранном словаре своего алфавита. Чем больше словарей, тем реже срабатывает замена: слова из разных языков начинают считаться правильными.\n\nКитайского здесь нет: в macOS нет такого словаря, и китайский набирается методом ввода, а не раскладкой — подменять буквы там нечего."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Проверка

struct CheckTab: View {
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Наберите слово так, как набрали его в программе:"))
                        .font(.callout).foregroundStyle(.secondary)
                    TextField(tr("например, ghbdtn"), text: $text)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .font(.title3)
                    if !text.isEmpty {
                        Text(switcher.explain(text))
                            .font(.headline).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(tr("Что программа сделает со словом"))
            } footer: {
                Text(tr("Набирайте в той же раскладке, в которой печатали. Слово нигде не сохраняется."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(tr("Если замена не срабатывает при обычном наборе")) {
                Text(tr("1. Проверьте слово здесь. Если тут написано «заменит», а в программе не заменяет — дело в той программе, где вы печатаете. Попробуйте «Заметки» или TextEdit."))
                Text(tr("2. Замена происходит после пробела, Enter или знака препинания, а не во время набора слова."))
                Text(tr("3. Заменяются только слова из словаря macOS. Сленг, имена и сокращения остаются как есть — для них правый ⌥."))
                Text(tr("4. Программы из раздела «Программы» пропускаются целиком."))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: Приватность

struct PrivacyTab: View {
    var body: some View {
        Form {
            Section(tr("Что программа НЕ делает")) {
                Label(tr("Не записывает набранный текст — журнала набора здесь нет намеренно"), systemImage: "xmark.circle")
                Label(tr("Не видит пароли: в полях паролей macOS скрывает нажатия, а программа их пропускает"), systemImage: "xmark.circle")
                Label(tr("Не выходит в интернет — в коде нет ни одного сетевого запроса"), systemImage: "xmark.circle")
                Label(tr("Не трогает логины: слова с цифрами, @, точками не исправляются"), systemImage: "xmark.circle")
            }
            Section(tr("Что хранится")) {
                Label(tr("Текущее слово — только в памяти, стирается после пробела"), systemImage: "memorychip")
                Label(tr("Слова-исключения — ~/Library/Application Support/LayoutFixer/exceptions.txt"), systemImage: "doc.text")
                Label(tr("Настройки и ваши сокращения — ~/Library/Preferences/local.layoutfixer.plist"), systemImage: "gearshape")
                Button(tr("Показать папку в Finder")) {
                    if !FileManager.default.fileExists(atPath: switcher.exceptions.url.path) { switcher.exceptions.save() }
                    NSWorkspace.shared.activateFileViewerSelecting([switcher.exceptions.url])
                }
            }
        }
        .formStyle(.grouped)
    }
}
