// Переводы интерфейса. Ключ — русский текст, он же запасной вариант.
// Язык берётся из настроек, а по умолчанию — из языка системы.

import Foundation

enum UILanguage: String, CaseIterable, Identifiable {
    case auto, ru, en, zh, es
    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return tr("Как в системе")
        case .ru: return "Русский"
        case .en: return "English"
        case .zh: return "简体中文"
        case .es: return "Español"
        }
    }
}

/// Текущий язык интерфейса: выбранный вручную или подходящий язык системы.
func currentUILanguage() -> String {
    let chosen = Settings.shared.uiLanguage
    if chosen != "auto" { return chosen }
    for code in Locale.preferredLanguages.map({ String($0.prefix(2)) }) {
        if ["ru", "en", "zh", "es"].contains(code) { return code }
    }
    return "en"
}

func tr(_ ru: String) -> String {
    let lang = currentUILanguage()
    if lang == "ru" { return ru }
    return translations[ru]?[lang] ?? ru
}

func tr(_ ru: String, _ args: CVarArg...) -> String {
    String(format: tr(ru), arguments: args)
}

let translations: [String: [String: String]] = [
    "Общие": ["en": "General", "zh": "通用", "es": "General"],
    "Горячие клавиши": ["en": "Shortcuts", "zh": "快捷键", "es": "Atajos"],
    "Правила": ["en": "Rules", "zh": "规则", "es": "Reglas"],
    "Автозамена": ["en": "Snippets", "zh": "缩写替换", "es": "Abreviaturas"],
    "Программы": ["en": "Apps", "zh": "应用", "es": "Apps"],
    "Языки": ["en": "Languages", "zh": "语言", "es": "Idiomas"],
    "Проверка": ["en": "Check", "zh": "检查", "es": "Comprobar"],
    "Приватность": ["en": "Privacy", "zh": "隐私", "es": "Privacidad"],
    "Состояние": ["en": "Status", "zh": "状态", "es": "Estado"],
    "Исправление": ["en": "Correction", "zh": "修正", "es": "Corrección"],
    "Прочее": ["en": "Other", "zh": "其他", "es": "Otros"],
    "О программе": ["en": "About", "zh": "关于", "es": "Acerca de"],
    "Работает": ["en": "Working", "zh": "运行中", "es": "Funcionando"],
    "Нет доступа к клавиатуре": ["en": "No keyboard access", "zh": "无键盘访问权限", "es": "Sin acceso al teclado"],
    "Открыть «Универсальный доступ»": ["en": "Open Accessibility settings", "zh": "打开“辅助功能”", "es": "Abrir Accesibilidad"],
    "Нажмите «+», выберите Программы → LayoutFixer и включите переключатель. Если программа уже в списке — удалите её «−» и добавьте заново.": ["en": "Click +, choose Applications → LayoutFixer and turn the switch on. If the app is already listed, remove it with − and add it again.", "zh": "点按 +，选择“应用程序 → LayoutFixer”，然后打开开关。如果列表中已有该应用，请先用 − 移除再重新添加。", "es": "Haz clic en +, elige Aplicaciones → LayoutFixer y activa el interruptor. Si ya está en la lista, quítala con − y añádela de nuevo."],
    "Раскладки": ["en": "Layouts", "zh": "键盘布局", "es": "Distribuciones"],
    "Нужны две раскладки: латинская и кириллическая": ["en": "Two layouts are needed: Latin and Cyrillic", "zh": "需要两种布局：拉丁字母和西里尔字母", "es": "Hacen falta dos distribuciones: latina y cirílica"],
    "Словари": ["en": "Dictionaries", "zh": "词典", "es": "Diccionarios"],
    "Выберите словари обоих алфавитов в разделе «Языки»": ["en": "Choose dictionaries for both alphabets in Languages", "zh": "请在“语言”中为两种字母各选一个词典", "es": "Elige diccionarios de ambos alfabetos en Idiomas"],
    "Автоматически переключать раскладку (ghbdtn → привет)": ["en": "Fix the keyboard layout automatically (ghbdtn → привет)", "zh": "自动修正键盘布局（ghbdtn → привет）", "es": "Corregir la distribución automáticamente (ghbdtn → привет)"],
    "Исправлять опечатки (менб → меню)": ["en": "Fix typos (менб → меню)", "zh": "修正拼写错误（менб → меню）", "es": "Corregir erratas (менб → меню)"],
    "Автозамена сокращений (см. раздел «Автозамена»)": ["en": "Expand snippets (see the Snippets tab)", "zh": "展开缩写（见“缩写替换”）", "es": "Expandir abreviaturas (ver Abreviaturas)"],
    "Звук при переключении раскладки": ["en": "Sound when the layout switches", "zh": "切换布局时播放提示音", "es": "Sonido al cambiar la distribución"],
    "Запускать при входе в систему": ["en": "Launch at login", "zh": "登录时启动", "es": "Abrir al iniciar sesión"],
    "Не получилось: %@. Программа должна лежать в «Программах».": ["en": "Failed: %@. The app must be in the Applications folder.", "zh": "失败：%@。应用必须位于“应用程序”文件夹中。", "es": "No se pudo: %@. La app debe estar en Aplicaciones."],
    "Разработчик": ["en": "Developer", "zh": "开发者", "es": "Desarrollador"],
    "версия %@": ["en": "version %@", "zh": "版本 %@", "es": "versión %@"],
    "Отменить замену": ["en": "Undo the replacement", "zh": "撤销替换", "es": "Deshacer el reemplazo"],
    "Сменить раскладку слова": ["en": "Convert the word", "zh": "转换单词布局", "es": "Convertir la palabra"],
    "Сменить раскладку выделенного": ["en": "Convert the selection", "zh": "转换选中文本", "es": "Convertir la selección"],
    "Сменить регистр выделенного": ["en": "Invert case of the selection", "zh": "反转选中文本大小写", "es": "Invertir mayúsculas de la selección"],
    "Транслитерация выделенного": ["en": "Transliterate the selection", "zh": "选中文本转写", "es": "Transliterar la selección"],
    "Сразу после замены: вернуть как было и запомнить слово": ["en": "Right after a replacement: put it back and remember the word", "zh": "替换后立即使用：还原并记住该词", "es": "Justo después de un reemplazo: restaurarlo y recordar la palabra"],
    "Принудительно: слово, которое набираете, или последнее слово": ["en": "Forced: the word you are typing, or the last one", "zh": "强制转换：正在输入的词或上一个词", "es": "Forzado: la palabra que escribes o la anterior"],
    "пРИВЕТ → Привет": ["en": "hELLO → Hello", "zh": "hELLO → Hello", "es": "hOLA → Hola"],
    "Не задано": ["en": "Not set", "zh": "未设置", "es": "Sin asignar"],
    "Нажмите сочетание…": ["en": "Press the combination…", "zh": "请按下组合键…", "es": "Pulsa la combinación…"],
    "Отмена": ["en": "Cancel", "zh": "取消", "es": "Cancelar"],
    "Записать своё сочетание…": ["en": "Record your own combination…", "zh": "录制自定义组合键…", "es": "Grabar tu combinación…"],
    "Выключить": ["en": "Turn off", "zh": "关闭", "es": "Desactivar"],
    "Своё сочетание: нажмите клавиши с ⌘, ⌃ или ⌥, F-клавишу, либо нажмите и отпустите один модификатор (например, правый ⌘). Esc — отмена.\n⌘Пробел и ⌃Пробел macOS по умолчанию забирает себе (Spotlight и смена раскладки). «Отменить замену» срабатывает только сразу после замены — в остальное время сочетание работает как обычно.": ["en": "Your own combination: press keys with ⌘, ⌃ or ⌥, an F-key, or press and release a single modifier (the right ⌘, for example). Esc cancels.\n⌘Space and ⌃Space are taken by macOS by default (Spotlight and input sources). Undo only fires right after a replacement — the rest of the time the combination works as usual.", "zh": "自定义组合键：按下带 ⌘、⌃ 或 ⌥ 的按键、F 键，或者按下并松开单个修饰键（例如右 ⌘）。Esc 取消。\n⌘空格和 ⌃空格默认由 macOS 占用（聚焦搜索与输入法切换）。“撤销替换”仅在替换后立即生效，其余时间按键照常工作。", "es": "Tu combinación: pulsa teclas con ⌘, ⌃ o ⌥, una tecla F, o pulsa y suelta un solo modificador (por ejemplo el ⌘ derecho). Esc cancela.\n⌘Espacio y ⌃Espacio los usa macOS por omisión (Spotlight y fuentes de entrada). Deshacer solo actúa justo después de un reemplazo; el resto del tiempo la combinación funciona como siempre."],
    " (нажать и отпустить)": ["en": " (press and release)", "zh": "（按下并松开）", "es": " (pulsar y soltar)"],
    "Левый ⌘": ["en": "Left ⌘", "zh": "左 ⌘", "es": "⌘ izquierdo"],
    "Правый ⌘": ["en": "Right ⌘", "zh": "右 ⌘", "es": "⌘ derecho"],
    "Левый ⌥": ["en": "Left ⌥", "zh": "左 ⌥", "es": "⌥ izquierdo"],
    "Правый ⌥": ["en": "Right ⌥", "zh": "右 ⌥", "es": "⌥ derecho"],
    "Левый ⌃": ["en": "Left ⌃", "zh": "左 ⌃", "es": "⌃ izquierdo"],
    "Правый ⌃": ["en": "Right ⌃", "zh": "右 ⌃", "es": "⌃ derecho"],
    "Левый ⇧": ["en": "Left ⇧", "zh": "左 ⇧", "es": "⇧ izquierdo"],
    "Правый ⇧": ["en": "Right ⇧", "zh": "右 ⇧", "es": "⇧ derecho"],
    "Пробел": ["en": "Space", "zh": "空格", "es": "Espacio"],
    "Модификатор %@": ["en": "Modifier %@", "zh": "修饰键 %@", "es": "Modificador %@"],
    "Слова, которые не исправлять": ["en": "Words to leave alone", "zh": "不修改的词", "es": "Palabras que no se corrigen"],
    "Новое слово": ["en": "New word", "zh": "新词", "es": "Nueva palabra"],
    "Добавить": ["en": "Add", "zh": "添加", "es": "Añadir"],
    "Только буквы, от 2 до 40 символов": ["en": "Letters only, 2 to 40 characters", "zh": "仅限字母，2 到 40 个字符", "es": "Solo letras, de 2 a 40 caracteres"],
    "Слово попадает сюда само, когда вы отменяете замену. Хранится только список этих слов.": ["en": "A word lands here on its own when you undo a replacement. Only this list is stored.", "zh": "撤销替换时，该词会自动加入此列表。只有这份列表会被保存。", "es": "Una palabra llega aquí sola cuando deshaces un reemplazo. Solo se guarda esta lista."],
    "Список (%@)": ["en": "List (%@)", "zh": "列表（%@）", "es": "Lista (%@)"],
    "Пока пусто": ["en": "Empty for now", "zh": "暂时为空", "es": "De momento, vacío"],
    "Сокращения": ["en": "Snippets", "zh": "缩写", "es": "Abreviaturas"],
    "Включить автозамену": ["en": "Enable snippets", "zh": "启用缩写替换", "es": "Activar abreviaturas"],
    "Сокращение": ["en": "Abbreviation", "zh": "缩写", "es": "Abreviatura"],
    "Текст": ["en": "Text", "zh": "文本", "es": "Texto"],
    "Сокращение — только буквы, 2–20 символов": ["en": "The abbreviation must be letters only, 2–20 characters", "zh": "缩写仅限字母，2–20 个字符", "es": "La abreviatura solo admite letras, 2–20 caracteres"],
    "Наберите сокращение и пробел — оно заменится текстом. Работает в любой раскладке: «спс» и «cgc» — одно и то же. ⌥Пробел сразу после — отменить.": ["en": "Type the abbreviation and a space — it turns into the text. Works in either layout: «спс» and «cgc» are the same thing. ⌥Space right after undoes it.", "zh": "输入缩写后按空格，即可替换为文本。任意布局均可使用：“спс”和“cgc”等价。随后按 ⌥空格可撤销。", "es": "Escribe la abreviatura y un espacio: se convierte en el texto. Funciona en cualquier distribución. ⌥Espacio justo después lo deshace."],
    "Например: спс → Спасибо!": ["en": "For example: спс → Спасибо!", "zh": "例如：спс → Спасибо!", "es": "Por ejemplo: спс → Спасибо!"],
    "В этих программах LayoutFixer ничего не делает": ["en": "LayoutFixer does nothing in these apps", "zh": "在这些应用中 LayoutFixer 不做任何事", "es": "LayoutFixer no hace nada en estas apps"],
    "Добавить программу…": ["en": "Add an app…", "zh": "添加应用…", "es": "Añadir una app…"],
    "Удобно для игр, Терминала, удалённого рабочего стола.": ["en": "Handy for games, Terminal and remote desktops.", "zh": "适合游戏、终端和远程桌面。", "es": "Útil para juegos, Terminal y escritorios remotos."],
    "Всегда исключены": ["en": "Always excluded", "zh": "始终排除", "es": "Siempre excluidos"],
    "Поля паролей во всех программах, а также менеджеры паролей: Пароли, Связка ключей, 1Password, Bitwarden, LastPass, KeePassXC, Dashlane.": ["en": "Password fields in every app, plus password managers: Passwords, Keychain Access, 1Password, Bitwarden, LastPass, KeePassXC, Dashlane.", "zh": "所有应用中的密码输入框，以及密码管理器：“密码”、钥匙串访问、1Password、Bitwarden、LastPass、KeePassXC、Dashlane。", "es": "Los campos de contraseña de todas las apps, además de gestores de contraseñas: Contraseñas, Acceso a Llaveros, 1Password, Bitwarden, LastPass, KeePassXC, Dashlane."],
    "Словари для проверки слов": ["en": "Dictionaries used to check words", "zh": "用于检查单词的词典", "es": "Diccionarios para comprobar palabras"],
    "Нужен хотя бы один словарь с латиницей (английский, испанский…) и русский для кириллицы. Слово считается правильным, если оно есть хотя бы в одном выбранном словаре своего алфавита. Чем больше словарей, тем реже срабатывает замена: слова из разных языков начинают считаться правильными.\n\nКитайского здесь нет: в macOS нет такого словаря, и китайский набирается методом ввода, а не раскладкой — подменять буквы там нечего.": ["en": "You need at least one Latin dictionary (English, Spanish…) and Russian for Cyrillic. A word counts as correct if any enabled dictionary of its alphabet knows it. The more dictionaries are on, the less often a replacement happens: words from different languages start counting as correct.\n\nChinese is not here: macOS has no such dictionary, and Chinese is typed with an input method rather than a layout, so there are no letters to swap.", "zh": "至少需要一个拉丁字母词典（英语、西班牙语……）以及用于西里尔字母的俄语词典。只要所选的同字母词典中有该词，就视为正确。启用的词典越多，替换发生得越少：不同语言的词都会被视为正确。\n\n这里没有中文：macOS 没有中文拼写词典，而且中文通过输入法输入，不是键盘布局，没有可替换的字母。", "es": "Necesitas al menos un diccionario latino (inglés, español…) y el ruso para el cirílico. Una palabra se considera correcta si aparece en cualquier diccionario activado de su alfabeto. Cuantos más diccionarios, menos reemplazos: palabras de otros idiomas pasan a ser correctas.\n\nEl chino no está: macOS no tiene ese diccionario y el chino se escribe con un método de entrada, no con una distribución, así que no hay letras que intercambiar."],
    "Что программа сделает со словом": ["en": "What the app will do with a word", "zh": "应用会如何处理这个词", "es": "Qué hará la app con una palabra"],
    "Наберите слово так, как набрали его в программе:": ["en": "Type the word the way you typed it in the app:", "zh": "按你在应用中输入的方式键入该词：", "es": "Escribe la palabra tal como la escribiste:"],
    "например, ghbdtn": ["en": "for example, ghbdtn", "zh": "例如 ghbdtn", "es": "por ejemplo, ghbdtn"],
    "Набирайте в той же раскладке, в которой печатали. Слово нигде не сохраняется.": ["en": "Use the same layout you typed in. The word is not stored anywhere.", "zh": "请使用相同的键盘布局输入。该词不会被保存。", "es": "Usa la misma distribución con la que escribiste. La palabra no se guarda."],
    "Если замена не срабатывает при обычном наборе": ["en": "If replacement doesn't happen while typing", "zh": "如果正常输入时没有替换", "es": "Si el reemplazo no ocurre al escribir"],
    "1. Проверьте слово здесь. Если тут написано «заменит», а в программе не заменяет — дело в той программе, где вы печатаете. Попробуйте «Заметки» или TextEdit.": ["en": "1. Check the word here. If it says it will be replaced but nothing happens where you type, the problem is that app. Try Notes or TextEdit.", "zh": "1. 先在此处检查该词。如果这里显示会替换，但实际输入时没有变化，问题出在你输入的那个应用。试试“备忘录”或 TextEdit。", "es": "1. Comprueba la palabra aquí. Si dice que se reemplazará pero no ocurre donde escribes, el problema es esa app. Prueba en Notas o TextEdit."],
    "2. Замена происходит после пробела, Enter или знака препинания, а не во время набора слова.": ["en": "2. Replacement happens after a space or a punctuation mark, not while the word is being typed.", "zh": "2. 替换发生在空格或标点之后，而不是在输入单词的过程中。", "es": "2. El reemplazo ocurre tras un espacio o un signo de puntuación, no mientras escribes la palabra."],
    "3. Заменяются только слова из словаря macOS. Сленг, имена и сокращения остаются как есть — для них правый ⌥.": ["en": "3. Only words known to the macOS dictionaries are replaced. Slang, names and abbreviations stay as they are — use the right ⌥ for those.", "zh": "3. 只有 macOS 词典收录的词才会被替换。俚语、人名和缩写保持原样，可用右 ⌥ 强制转换。", "es": "3. Solo se reemplazan palabras conocidas por los diccionarios de macOS. La jerga, los nombres y las abreviaturas se quedan igual: usa el ⌥ derecho."],
    "4. Программы из раздела «Программы» пропускаются целиком.": ["en": "4. Apps listed in the Apps tab are skipped entirely.", "zh": "4. “应用”中列出的应用会被完全跳过。", "es": "4. Las apps de la pestaña Apps se omiten por completo."],
    "Что программа НЕ делает": ["en": "What the app never does", "zh": "应用不会做的事", "es": "Lo que la app nunca hace"],
    "Не записывает набранный текст — журнала набора здесь нет намеренно": ["en": "Never records what you type — there is no log, on purpose", "zh": "从不记录你输入的内容——这里刻意没有任何日志", "es": "Nunca registra lo que escribes: no hay ningún registro, a propósito"],
    "Не видит пароли: в полях паролей macOS скрывает нажатия, а программа их пропускает": ["en": "Never sees passwords: macOS hides keystrokes in password fields and the app skips them", "zh": "看不到密码：macOS 在密码框中隐藏按键，应用也会跳过", "es": "Nunca ve contraseñas: macOS oculta las pulsaciones en esos campos y la app los omite"],
    "Не выходит в интернет — в коде нет ни одного сетевого запроса": ["en": "Never goes online — there is not a single network call in the code", "zh": "从不联网——代码中没有任何网络请求", "es": "Nunca se conecta: no hay ni una llamada de red en el código"],
    "Не трогает логины: слова с цифрами, @, точками не исправляются": ["en": "Leaves logins alone: words with digits, @ or dots are not corrected", "zh": "不修改登录名：含数字、@ 或点号的词不会被更正", "es": "Deja en paz los inicios de sesión: no corrige palabras con cifras, @ o puntos"],
    "Что хранится": ["en": "What is stored", "zh": "会保存什么", "es": "Qué se guarda"],
    "Текущее слово — только в памяти, стирается после пробела": ["en": "The current word — in memory only, erased after a space", "zh": "当前词仅存于内存，空格后即清除", "es": "La palabra actual, solo en memoria y borrada tras un espacio"],
    "Слова-исключения — ~/Library/Application Support/LayoutFixer/exceptions.txt": ["en": "Exception words — ~/Library/Application Support/LayoutFixer/exceptions.txt", "zh": "例外词——~/Library/Application Support/LayoutFixer/exceptions.txt", "es": "Palabras excluidas — ~/Library/Application Support/LayoutFixer/exceptions.txt"],
    "Настройки и ваши сокращения — ~/Library/Preferences/local.layoutfixer.plist": ["en": "Settings and your snippets — ~/Library/Preferences/local.layoutfixer.plist", "zh": "设置与你的缩写——~/Library/Preferences/local.layoutfixer.plist", "es": "Ajustes y tus abreviaturas — ~/Library/Preferences/local.layoutfixer.plist"],
    "Показать папку в Finder": ["en": "Show the folder in Finder", "zh": "在访达中显示文件夹", "es": "Mostrar la carpeta en el Finder"],
    "Автопереключение раскладки": ["en": "Fix the layout automatically", "zh": "自动修正布局", "es": "Corregir la distribución"],
    "Исправлять опечатки": ["en": "Fix typos", "zh": "修正拼写错误", "es": "Corregir erratas"],
    "Настройки…": ["en": "Settings…", "zh": "设置…", "es": "Ajustes…"],
    "Выйти": ["en": "Quit", "zh": "退出", "es": "Salir"],
    "⚠︎ Нет доступа — откройте настройки": ["en": "⚠︎ No access — open Settings", "zh": "⚠︎ 无权限 — 请打开设置", "es": "⚠︎ Sin acceso: abre los ajustes"],
    "LayoutFixer: нет доступа": ["en": "LayoutFixer: no access", "zh": "LayoutFixer：无权限", "es": "LayoutFixer: sin acceso"],
    "LayoutFixer: автопереключение выключено": ["en": "LayoutFixer: automatic correction is off", "zh": "LayoutFixer：自动修正已关闭", "es": "LayoutFixer: corrección automática desactivada"],
    "Сейчас активна раскладка, которую программа не знает (нужны английская и русская).": ["en": "The active layout is not one the app knows (a Latin and a Cyrillic layout are needed).", "zh": "当前布局应用无法识别（需要一种拉丁字母和一种西里尔字母布局）。", "es": "La distribución activa no es una que la app conozca (hacen falta una latina y una cirílica)."],
    "Слишком короткое слово — такие не заменяются.": ["en": "The word is too short — those are never replaced.", "zh": "该词太短，不会被替换。", "es": "La palabra es demasiado corta: esas no se reemplazan."],
    "«%@» в списке исключений (раздел «Правила») — не заменяется.": ["en": "«%@» is in the exceptions list (Rules tab) — it is left alone.", "zh": "“%@”在例外列表中（“规则”），不会被修改。", "es": "«%@» está en la lista de excepciones (Reglas): se deja igual."],
    "«%@» — обычное слово в текущей раскладке, заменять нечего.": ["en": "«%@» is an ordinary word in the current layout — nothing to replace.", "zh": "“%@”在当前布局下是正常单词，无需替换。", "es": "«%@» es una palabra normal en la distribución actual: no hay nada que reemplazar."],
    "Заменит на «%@» и переключит раскладку.": ["en": "Will replace it with «%@» and switch the layout.", "zh": "将替换为“%@”并切换布局。", "es": "Lo reemplazará por «%@» y cambiará la distribución."],
    "Опечатка: исправит на «%@».": ["en": "A typo: will be corrected to «%@».", "zh": "拼写错误：将更正为“%@”。", "es": "Errata: se corregirá a «%@»."],
    "Сейчас активна программа или поле, которые LayoutFixer пропускает (пароли, программы-исключения).": ["en": "The active app or field is one LayoutFixer skips (passwords, excluded apps).", "zh": "当前应用或输入框属于 LayoutFixer 跳过的范围（密码、排除的应用）。", "es": "La app o el campo activo es de los que LayoutFixer omite (contraseñas, apps excluidas)."],
    "Не заменит: «%@» в другой раскладке — не слово из словаря.": ["en": "No replacement: «%@» in the other layout is not a dictionary word.", "zh": "不会替换：“%@”在另一种布局下不是词典中的词。", "es": "Sin reemplazo: «%@» en la otra distribución no es una palabra del diccionario."],
    " В нём есть цифры или знаки, а такие слова программа не трогает.": ["en": " It contains digits or symbols, and the app leaves such words alone.", "zh": " 其中含有数字或符号，这类词应用不会修改。", "es": " Contiene cifras o símbolos, y la app no toca esas palabras."],
    "Язык интерфейса": ["en": "Interface language", "zh": "界面语言", "es": "Idioma de la interfaz"],
    "Как в системе": ["en": "Same as the system", "zh": "跟随系统", "es": "Igual que el sistema"],
]
