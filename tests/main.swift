// Тесты логики LayoutFixer. Запуск: ./scripts/test.sh
// Интерфейс и перехват клавиш здесь не участвуют — проверяются только решения о замене.

import Cocoa

var failed = 0, passed = 0

func check(_ name: String, _ got: String, _ want: String) {
    if got == want {
        passed += 1
    } else {
        failed += 1
        print("  ПРОВАЛ: \(name)\n    получено: \(got)\n    ожидалось: \(want)")
    }
}

func section(_ title: String) { print("\n\(title)") }

// MARK: окружение

let layouts = Layouts.shared
guard let latin = layouts.latinMain, let cyrillic = layouts.cyrillicMain else {
    print("Нужны две раскладки: латинская и кириллическая. Тесты пропущены.")
    exit(0)
}
let speller = Speller()

/// Что получится, если набрать слово в другой раскладке.
func mistyped(_ word: String) -> String { TextTools.convertLayout(word).0 }

/// Решение программы для набранного слова, без учёта исключений и настроек.
func verdict(_ typed: String) -> String {
    guard let script = Script.of(word: typed) else { return "—" }
    let layout = script == .latin ? latin : cyrillic
    if let form = speller.knownForm(typed) { return "слово:\(form)" }
    let other = TextTools.convertLayout(typed).0
    if let form = speller.knownForm(other) { return "раскладка:\(form)" }
    if let fixed = speller.correction(typed, layout) { return "опечатка:\(fixed)" }
    return "нет"
}

func withDictionaries(_ codes: [String], _ body: () -> Void) {
    let saved = Settings.shared.spellLanguages
    Settings.shared.spellLanguages = codes
    speller.reload()
    body()
    Settings.shared.spellLanguages = saved
    speller.reload()
}

// MARK: раскладка

section("Смена раскладки")
withDictionaries(["ru", "en"]) {
    check("привет", verdict(mistyped("привет")), "раскладка:привет")
    check("hello", verdict(mistyped("hello")), "раскладка:hello")
    check("название с заглавной", verdict(mistyped("Нидерланды")), "раскладка:Нидерланды")
    check("правильное слово не трогаем", verdict("привет"), "слово:привет")
    check("логин не трогаем", verdict("vasya2024"), "нет")
}

section("Словари других языков")
withDictionaries(["ru", "en_GB"]) {
    check("colour при британском словаре", verdict(mistyped("colour")), "раскладка:colour")
}
withDictionaries(["ru", "es"]) {
    check("gracias при испанском словаре", verdict(mistyped("gracias")), "раскладка:gracias")
    check("mañana при испанском словаре", verdict(mistyped("mañana")), "раскладка:mañana")
}

// MARK: опечатки

section("Опечатки")
withDictionaries(["ru", "en"]) {
    check("менб", verdict("менб"), "опечатка:меню")          // Б рядом с Ю, а не «меня»
    check("првиет", verdict("првиет"), "опечатка:привет")     // перестановка букв
    check("recieve", verdict("recieve"), "опечатка:receive")
    check("набор букв не исправляем", verdict("гнпщ"), "нет")
    check("похоже на логин", verdict("vasya"), "нет")
}

// MARK: выделенный текст

section("Выделенный текст")
check("фраза в другой раскладке", TextTools.convertLayout("ghbdtn vbh").0, "привет мир")
check("знак в конце слова", TextTools.convertLayout("Ghbdtn, rfr ltkf?").0, "Привет, как дела?")
check("знак внутри слова", TextTools.convertLayout("pf,jnf").0, "забота")
check("обратно на латиницу", TextTools.convertLayout("руддщ цщкдв").0, "hello world")

check("транслит на латиницу", TextTools.translit("Привет, Щука, жёлтый"), "Privet, Shchuka, zhyoltyy")
check("транслит на кириллицу", TextTools.translit("zheltyy, novyy, kakoy, moy"), "желтый, новый, какой, мой")

// MARK: цена опечатки

section("Цена опечатки")
let near: (Character, Character) -> Bool = cyrillic.areNeighbors
check("соседняя клавиша дешевле", String(typoCost("менб", "меню", near: near)), "0.5")
check("далёкая замена дороже", String(typoCost("менб", "меня", near: near)), "1.0")
check("перестановка", String(typoCost("првиет", "привет", near: near)), "1.0")

// MARK: переводы интерфейса

section("Переводы интерфейса")
let missing = translations.filter { $0.value["en"] == nil || $0.value["zh"] == nil || $0.value["es"] == nil }
check("во всех строках есть три перевода", String(missing.count), "0")
check("строк в таблице не меньше ста", String(translations.count >= 100), "true")

// MARK: итог

print("\nПройдено: \(passed), провалено: \(failed)")
exit(failed == 0 ? 0 : 1)
