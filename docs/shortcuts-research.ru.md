# Горячая клавиша и автозапуск

Проверено 10 сентября 2026 года. Проект использует sandbox, минимальную macOS 15.5; локально доступен Swift 6.2.4.

## Выбор

Для глобальной клавиши выбран **KeyboardShortcuts 3.0.1**, MIT, Swift Package Manager. Пакет предоставляет готовый нативный recorder, подходит для sandbox и не требует диалогов Accessibility/Input Monitoring. [Репозиторий](https://github.com/sindresorhus/KeyboardShortcuts).

Версия 3 требует Swift tools 6.2; локальный компилятор подходит. В 3.0 параметр `default:` переименован в `initial:`. Зафиксировать разрешённую версию в Package.resolved. [Манифест](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Package.swift), [релизы](https://github.com/sindresorhus/KeyboardShortcuts/releases).

## Подключение

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleLaunchpad = Self("toggleLaunchpad")
}

// Один раз в AppDelegate, а не при каждом открытии окна:
KeyboardShortcuts.onKeyUp(for: .toggleLaunchpad) { [weak self] in
    self?.toggleLauncher()
}

// В SwiftUI-настройках, размещённых в NSHostingView:
KeyboardShortcuts.Recorder("Открыть Launchpad:", name: .toggleLaunchpad)
```

Recorder сохраняет комбинацию; пользователь может её удалить. Для готового начального сочетания допустимо `Self("toggleLaunchpad", initial: .init(.space, modifiers: [.control, .option]))`, но предпочтительно дать пользователю выбрать сочетание при первом запуске. Имя не должно содержать точек. [Name.swift](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/main/Sources/KeyboardShortcuts/Name.swift).

Для подписи использовать `KeyboardShortcuts.getShortcut(for: .toggleLaunchpad)?.description` на главном акторе. Для меню — `menuItem.setShortcut(for: .toggleLaunchpad)`. Не привязывать второй обработчик той же клавиши к кнопке SwiftUI: это потенциально создаёт повторное переключение.

## Конфликты, запись, хранение

Recorder проверяет системные сочетания и главное меню приложения. Для дополнительных правил доступен `.shortcutValidation { shortcut in ... }` с результатом `.allow` либо `.disallow(reason: "...")`; `onChange` обновляет собственные подписи после изменения. [Recorder.swift](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/3.0.1/Sources/KeyboardShortcuts/Recorder.swift).

Во время записи Recorder автоматически приостанавливает callbacks. Потеря фокуса окна, окончание редактирования и удаление элемента из окна снимают паузу. Вручную отключать клавишу при открытии настроек не нужно. [RecorderCocoa.swift](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/3.0.1/Sources/KeyboardShortcuts/RecorderCocoa.swift).

Публичные `disable(.toggleLaunchpad)` / `enable(.toggleLaunchpad)` пригодны для временного отключения функции. `setShortcut(nil, for: .toggleLaunchpad)` удаляет назначение; `reset(.toggleLaunchpad)` возвращает начальное. Хранилище — `UserDefaults.standard`, автоматически внутри sandbox приложения; App Group для этого не нужен. Не редактировать внутренние ключи библиотеки. [KeyboardShortcuts.swift](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/3.0.1/Sources/KeyboardShortcuts/KeyboardShortcuts.swift).

Системную занятость можно проверить через `shortcut.isTakenBySystem`. Это не гарантия обнаружения всех комбинаций сторонних приложений: проверять фактическую работу после назначения. В исходнике ограничение Option-only относится к macOS 15.0/15.1, несмотря на более широкую формулировку README; минимальная 15.5 проекта этим не затронута. [Shortcut.swift](https://raw.githubusercontent.com/sindresorhus/KeyboardShortcuts/3.0.1/Sources/KeyboardShortcuts/Shortcut.swift).

## Жизненный цикл приложения

Предлагаемая интеграция: AppDelegate владеет одним окном launcher, окном настроек и NSStatusItem. Закрытие launcher скрывает окно, сохраняя процесс и каталог в памяти. Явный пункт «Завершить» завершает процесс. Повторный запуск из Finder/Dock и сочетание вызывают один контроллер показа. Открытие настроек сначала скрывает launcher; потеря фокуса launcher не должна закрывать окно настроек. Обработчик сочетания не регистрируется повторно при каждом показе.

## Запуск при входе

Использовать `ServiceManagement` и `SMAppService.mainApp`, доступные начиная с macOS 13. Отдельный helper не нужен. `try SMAppService.mainApp.register()` включает запуск основного приложения на последующих входах; `try SMAppService.mainApp.unregister()` отключает. Ошибку показывать пользователю, не оставлять переключатель в ложном состоянии. [Apple: mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp), [Apple: register](https://developer.apple.com/documentation/servicemanagement/smappservice/register()).

Источником состояния служит `SMAppService.mainApp.status`, а не сохранённый Bool. Для `.requiresApproval` показать кнопку `SMAppService.openSystemSettingsLoginItems()`. Обновлять статус при возвращении приложения в активное состояние, поскольку пользователь может изменить его в настройках системы. Эти API также сверены с заголовком SMAppService.h локального macOS SDK. Автозапуск включается только переключателем пользователя; не восстанавливать регистрацию насильно при каждом запуске.

## Если сеть недоступна

Сначала использовать ранее разрешённый SPM cache. Если его нет, допустимо сохранить проверенный релиз пакета как локальную зависимость вместе с MIT LICENSE и исходными ресурсами локализации. Не подменять зависимость незаметно урезанным recorder. Последний резерв — небольшой адаптер Carbon `RegisterEventHotKey` / `UnregisterEventHotKey` с явной обработкой OSStatus и сохранением комбинации; он потребует отдельной проверки конфликтов и интерфейса записи, поэтому готовый пакет предпочтительнее.

## Проверка поведения

- Назначение, удаление и восстановление комбинации; сохранение после перезапуска.
- Открытие и скрытие из другого приложения; длительное удержание не вызывает многократное переключение.
- Запись той же клавиши в настройках не открывает launcher; закрытие настроек во время записи возобновляет обработку.
- Предупреждение для системной комбинации; корректная подпись в меню после изменения.
- Launcher скрывается без завершения процесса; явное завершение снимает регистрацию клавиши.
- Автозапуск включается и отключается, системный запрет корректно отражается в настройках; проверка на установленной подписанной сборке.
