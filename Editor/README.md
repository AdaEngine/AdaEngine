# AdaEditor

AdaEditor — отдельный SwiftPM-пакет редактора AdaEngine. Он содержит исполняемый таргет `AdaEditor`, ресурсы интерфейса и тесты редакторской логики.

## Структура

- `Package.swift` — манифест пакета редактора.
- `Sources/AdaEditor` — исходники приложения редактора.
- `Sources/AdaEditor/Assets` — ресурсы редактора: изображения и шрифты.
- `Tests/AdaEditorTests` — тесты редактора.
- `project.yml` — конфигурация XcodeGen для генерации Xcode-проекта.

## Зависимости

Пакет подключает:

- локальный `AdaEngine` из родительской директории (`.package(path: "..")`);
- `AdaMCP` из `https://github.com/AdaEngine/AdaMCP`.

## Сборка и тесты

Из директории `Editor`:

```bash
swift build
swift test
```

## Генерация Xcode-проекта

Установите XcodeGen, если он ещё не установлен, затем выполните:

```bash
cd Editor
xcodegen generate
open AdaEditor.xcodeproj
```

Сгенерированный проект использует локальный SwiftPM-пакет `AdaEditor` и схему `AdaEditor` для запуска редактора.
