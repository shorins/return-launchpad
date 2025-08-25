# Документация по реализации Drag & Drop в Return Launchpad

## Обзор

В приложении Return Launchpad реализована система перетаскивания иконок приложений с живыми анимациями, визуальной обратной связью и постоянным сохранением пользовательского порядка. Система использует SwiftUI DropDelegate и NSItemProvider для создания интуитивного интерфейса перетаскивания.

## Архитектура системы

### Основные компоненты

1. **ContentView** - главный интерфейс с сеткой приложений
2. **DropDelegate** - обработчик событий drag & drop
3. **AppOrderManager** - менеджер порядка приложений с персистентностью
4. **AppManager** - управление состоянием приложений

## Реализация Drag & Drop

### 1. Состояния для отслеживания перетаскивания

```swift
// В ContentView
@State private var draggedItem: AppInfo?
@State private var isInDragMode: Bool = false
```

- `draggedItem` - отслеживает какой элемент перетаскивается
- `isInDragMode` - флаг режима перетаскивания для изменения UI

### 2. Инициализация перетаскивания (.onDrag)

```swift
.onDrag {
    draggedItem = app
    isInDragMode = true
    return NSItemProvider(object: app.bundleIdentifier as NSString)
}
```

**Что происходит:**
- Устанавливается `draggedItem` на текущий элемент
- Включается режим перетаскивания
- Создается `NSItemProvider` с уникальным идентификатором приложения

### 3. Обработка области сброса (.onDrop)

```swift
.onDrop(of: [.text], delegate: DropDelegate(
    app: app,
    apps: $appManager.apps,
    appManager: appManager,
    draggedItem: $draggedItem,
    isInDragMode: $isInDragMode
))
```

**Параметры:**
- `of: [.text]` - принимаем текстовые данные (bundleIdentifier)
- `delegate` - кастомный DropDelegate для обработки логики

## DropDelegate - Обработчик перетаскивания

### Структура DropDelegate

```swift
struct DropDelegate: SwiftUI.DropDelegate {
    let app: AppInfo
    @Binding var apps: [AppInfo]
    let appManager: AppManager
    @Binding var draggedItem: AppInfo?
}
```

### Методы DropDelegate

#### dropEntered - Предварительное перемещение

```swift
func dropEntered(info: DropInfo) {
    guard let draggedItem = draggedItem else { return }
    
    if draggedItem.id != app.id {
        let fromIndex = apps.firstIndex(where: { $0.id == draggedItem.id })
        let toIndex = apps.firstIndex(where: { $0.id == app.id })
        
        if let fromIndex = fromIndex, let toIndex = toIndex {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                apps.move(fromOffsets: IndexSet(integer: fromIndex), 
                         toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}
```

**Назначение:**
- Обеспечивает живой preview перемещения
- Анимирует изменения в реальном времени
- Spring анимация с `response: 0.3, dampingFraction: 0.8`

#### performDrop - Финальное сохранение

```swift
func performDrop(info: DropInfo) -> Bool {
    guard let draggedItem = draggedItem else { return false }
    
    if draggedItem.id != app.id {
        let fromIndex = apps.firstIndex(where: { $0.id == draggedItem.id })
        let toIndex = apps.firstIndex(where: { $0.id == app.id })
        
        if let fromIndex = fromIndex, let toIndex = toIndex {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appManager.moveApp(from: fromIndex, to: toIndex)
            }
        }
    }
    
    self.draggedItem = nil
    return true
}
```

**Назначение:**
- Финализирует перемещение через AppManager
- Сохраняет новый порядок в постоянное хранилище
- Сбрасывает состояние перетаскивания

## Визуальные эффекты и анимации

### 1. Эффекты перетаскиваемого элемента

```swift
.scaleEffect(hoverId == app.id ? 1.05 : 1.0)
.rotationEffect(.degrees(draggedItem?.id == app.id ? 5 : 0))
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: draggedItem?.id)
```

**Эффекты:**
- **Масштабирование** при наведении: 1.05x
- **Поворот** при перетаскивании: 5 градусов
- **Анимация** Spring с `response: 0.3, dampingFraction: 0.6`

### 2. Визуальная рамка в режиме перетаскивания

```swift
.overlay(
    RoundedRectangle(cornerRadius: 15)
        .stroke(isInDragMode ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
)
```

**Эффект:**
- Синяя полупрозрачная рамка появляется во время drag mode
- Показывает активные зоны для сброса

### 3. Автоматический выход из режима перетаскивания

```swift
.onChange(of: draggedItem) { oldValue, newValue in
    if newValue == nil {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInDragMode = false
        }
    }
}
```

**Логика:**
- Отложенное отключение режима перетаскивания на 0.1 секунды
- Плавный переход визуальных эффектов

## Постоянное сохранение (AppOrderManager)

### Многоуровневая система сохранения

#### 1. Автоматическое сохранение при изменениях

```swift
@Published private var userOrderJSON: String = "" {
    didSet {
        appGroupDefaults.set(userOrderJSON, forKey: userAppOrderKey)
        appGroupDefaults.synchronize() // Принудительная синхронизация
    }
}
```

#### 2. Сохранение при завершении приложения

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(appWillTerminate),
    name: NSApplication.willTerminateNotification,
    object: nil
)
```

#### 3. Периодическое резервное сохранение

```swift
Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
    self.forceSave()
}
```

#### 4. Сохранение в деинициализаторе

```swift
deinit {
    forceSave()
    NotificationCenter.default.removeObserver(self)
}
```

### Пользовательские ключи хранения

```swift
private var customOrderEnabledKey: String { "\(currentUser)_isCustomOrderEnabled" }
private var userAppOrderKey: String { "\(currentUser)_userAppOrder" }
```

**Особенности:**
- Уникальные ключи для каждого пользователя macOS
- Использование app group контейнера
- JSON сериализация порядка приложений

## Логика перемещения в AppManager

### moveApp метод

```swift
func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
    apps.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
    
    // Сохранение через AppOrderManager
    appOrderManager.moveApp(from: sourceIndex, to: destinationIndex, in: apps)
}
```

**Процесс:**
1. Обновление UI массива приложений
2. Передача данных в AppOrderManager
3. Автоматическое включение пользовательского режима
4. Принудительное сохранение нового порядка

## Интеграция с поиском и пагинацией

### Отключение перетаскивания в режиме поиска

```swift
// В onTapGesture
if !isInDragMode {
    NSWorkspace.shared.open(app.url)
    NSApplication.shared.terminate(nil)
}
```

### Сохранение порядка при переключении страниц

- Drag & drop работает в пределах одной страницы
- AppOrderManager сохраняет глобальный порядок
- При перестройке страниц порядок восстанавливается

## Пример полной реализации

### Добавление drag & drop к иконке приложения

```swift
appIconView(app: app)
    .onDrag {
        draggedItem = app
        isInDragMode = true
        return NSItemProvider(object: app.bundleIdentifier as NSString)
    }
    .onDrop(of: [.text], delegate: DropDelegate(
        app: app,
        apps: $appManager.apps,
        appManager: appManager,
        draggedItem: $draggedItem,
        isInDragMode: $isInDragMode
    ))
```

### Создание кастомного DropDelegate

```swift
struct DropDelegate: SwiftUI.DropDelegate {
    let app: AppInfo
    @Binding var apps: [AppInfo]
    let appManager: AppManager
    @Binding var draggedItem: AppInfo?
    
    func dropEntered(info: DropInfo) {
        // Логика предварительного перемещения с анимацией
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Финальное сохранение и сброс состояния
    }
}
```

## Ключевые особенности реализации

### 1. Живые анимации
- Spring анимации для естественных движений
- Различные параметры для preview и финального перемещения
- Плавные переходы между состояниями

### 2. Надежная персистентность
- 4-уровневая система сохранения
- App Group контейнер для песочницы macOS
- Пользовательские ключи для мультиюзерности

### 3. Визуальная обратная связь
- Масштабирование и поворот элементов
- Цветовые индикаторы активных зон
- Отложенное отключение visual states

### 4. Интеграция с основной логикой
- Автоматическое переключение в пользовательский режим
- Совместимость с поиском и пагинацией
- Обработка новых приложений

## Возможные расширения

1. **Мультиселект drag**: перетаскивание нескольких иконок
2. **Drag между страницами**: переход на другие страницы при перетаскивании
3. **Папки**: создание групп приложений
4. **Haptic feedback**: тактильные отклики на Mac с Force Touch
5. **Undo/Redo**: отмена последних перемещений

Эта реализация обеспечивает плавный, интуитивный опыт перетаскивания с надежным сохранением пользовательских настроек, который можно легко адаптировать для других SwiftUI приложений.