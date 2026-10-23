# Shader Graph: продолжение на другом компьютере

Состояние на **23 октября 2026**. Это draft реализации, а не готовая к релизу
функция. Основные слои 1–16 реализованы; экспорт (17) и итоговая приёмка (18)
закрыты частично. Общего feature flag нет. История разбита на последовательные
коммиты; границы и исходные критерии находятся в
[карте декомпозиции](../docs/tbd/decompositions/2026-10-20-shader-graph.md).
Описание пользовательского API: [ShaderGraph.md](ShaderGraph.md).

## Что уже есть

- Версионированный граф, проверка типов и циклов, детерминированное lowering,
  GLSL, привязанные к узлам диагностики, uniform/texture bindings.
- Sprite и PBR, независимые экземпляры материалов, модельные material slots,
  маска alpha в тенях/depth/motion, общий кэш pipelines.
- Нативный AdaUI редактор: создание/открытие, canvas, связи, Inspector,
  history/save, поиск, clipboard, группы/заметки, en/ru, production preview.
- Time, UV, noise, математика, векторные каналы, Select Value; шаблоны
  Sprite/PBR/Dissolve/UV Scroll.
- Реальные AdaScript VM и standalone ABI-3 AOT: чтение/запись параметров,
  назначение/очистка графа, query и scriptable component bindings,
  readonly и время жизни borrowed handles. AOT учитывает `@access`.
- `.shadergraphlib`, точный поиск WGSL по generated source + defines,
  preload графов/текстур, host baker и подключение к Web exporter.
- Явный resource scope при декодировании сцен до запуска asset plugins.
  Portable proxy для экспорта primitive Mesh3D вместо сериализации GPU mesh.

## Что делать дальше, по порядку

1. **Свести ветку с актуальным `main` в чистом checkout.** Разработка началась
   от `5b6085790a14fa8a7461804e53c7ae3547f3b543`. На момент передачи `origin/main`
   уже `94f3cd1ab8ea091d280e4b716f7d705225c560f2`. Предварительный `git merge-tree`
   строит merge без конфликтов, но merge/rebase и запуск на новой базе не выполнены.
   Не переносить посторонние незакоммиченные изменения старого ПК.
2. **Найти зависание браузерного Player.** Экспорт fixture ниже завершается,
   HTTP отдаёт WASM, scene, archive и texture с 200, заголовок страницы меняется,
   но первый подтверждённый кадр игры не получен, renderer нагружает CPU.
   `AppBuilder.waitForPluginLoad` теперь отдаёт управление browser task через
   async timer и проверяет cancellation; native readiness/cancellation tests
   есть, но это ещё не доказанное исправление браузера. Проверить stages startup,
   plugin readiness, archive/texture preload и первый frame на обычном Chromium.
   Сначала сравнить тот же экспорт без graph, затем Sprite graph, затем PBR.
   Локальный IAB зависал и переставал отвечать на automation; это ограничивает
   доказательства, но не устанавливает причину зависания.
3. **Довести настоящий native export.** Package-only macOS/web export проходил.
   Отдельный native executable собирался и сообщал `Native game ready`, однако
   успешная упаковка `.app` и её кадр ещё не приняты. Последний packaging test
   падал до сборки Player из-за неинициализированного `RenderEngine` в harness;
   в тест добавлен headless setup; package-only повтор уже проходит. Повторить
   настоящую упаковку с отдельным child scratch (ниже),
   затем запустить `.app` и проверить Sprite + PBR + AOT изменение `tint`.
4. **Проверить primitive PBR export end to end.** Новые
   `PrimitiveMesh3DSource`, ветки в native exporter/scene loader и codec tests
   добавлены последними. Проверить все пять primitive kinds, shadows,
   независимые overrides и загрузку после переноса проекта. Fixture пока содержит
   Sprite scene и PBR graph asset; 3D scene надо добавить через Studio.
   Импортированный GLB с material overrides проверить отдельно.
5. **Усилить baker/export tests.** Негативные случаи: missing graph/texture,
   invalid graph, нет точного baked variant, Unicode/пробелы в пути, inline graph
   в сцене и texture override. Проверить весь набор PBR feature masks:
   baker собирает базовые layer/morph комбинации и texture masks из glTF
   extensions; произвольные authored PBR layer textures ещё не приняты.
   Проверить отсутствие изменений экспорта игры без графов; сейчас сцены могут
   запускать сборку baker даже без graph. Оценить вывод дочерних процессов,
   чтобы большой stderr не блокировал pipe.
6. **Повторить полный GPU gate на бодрствующей машине.** Последний расширенный
   прогон из 214 тестов имел один Dawn buffer-map timeout в существующем
   `sheenTexturesScaleTheirFactors` во время длительного сна машины. Не считать
   его зелёным. Не обновлять references ради timeout; сначала повторить этот
   тест, затем полный gate. Позже добавлены два plugin tests.
7. **Повторить реальный Save → reopen → Play.** На macOS и iPad проверить
   Sprite/PBR, изменение параметров без recompilation, texture reload,
   invalid graph → last valid preview → исправление, long Russian labels,
   split tabs/undo и touch drag/scroll. Нативный editor preview уже виден на обеих
   платформах. Первый iPad Play был пустым из-за пропущенного Sprite при раннем
   разрешении `@res://`; resource-scope fix покрыт тестом, повторный live Play
   после исправления ещё нужен.
8. **Замерить регрессии без graph.** Release benchmark packages были собраны,
   но замеров baseline/changed нет. Сравнить batching/instancing, CPU/upload/GPU
   и тяжёлую 3D сцену на одной тихой машине с одинаковыми настройками. После
   этого — owning test targets, CI и отдельная проверка Windows/Linux/других
   экспортных платформ. Их работоспособность этим PR не подтверждена.

## Воспроизводимый fixture и первые проверки

Команды ниже — из engine root в чистом checkout. Не копировать `.build` между
ПК/toolchains и не удалять общий `.build`. Применять отдельные scratch paths;
один scratch не использовать одновременно несколькими SwiftPM процессами.
Для native проверок использовался Xcode 26.6 / Swift 6.3.3. Для WebGPU/WASM
нужен совместимый **Swift 6.3.2**, Swan/Dawn и SDK `swift-6.3.2-RELEASE_wasm`;
см. [Tint setup](../../Tools/Tint/README.md). Проверить `swift --version` и
`swift sdk list`, использовать явный путь к нужному `swift` при переключении.

```bash
export ADA_GRAPH_ROOT="$PWD"
export ADA_GRAPH_QA="$PWD/.build-tools/shader-graph-qa"
mkdir -p "$ADA_GRAPH_QA"
cp -R Editor/Tests/Fixtures/ShaderGraphSmoke "$ADA_GRAPH_QA/project"
python3 script/check_studio_localization.py
python3 script/shader_graph_validation_package.py "$ADA_GRAPH_QA/cpu-package"
swift test --package-path "$ADA_GRAPH_QA/cpu-package" \
  --scratch-path "$ADA_GRAPH_QA/cpu-build" --no-parallel -j 4
```

`shader_graph_validation_package.py` копирует **production** test sources и
реальный compiled C fixture; приложение не получает QA hooks. После правок тестов
повторить staging command. Канонический AOT source —
`Tests/AdaScriptAOTFixture/ShaderGraph.ada`, регенерация —
`python3 script/generate_shader_graph_fixture.py`.

```bash
export ADAENGINE_GRAVITY_PACKAGE_PATH="$ADA_GRAPH_ROOT/Sources/gravity-lang"
export ADAENGINE_SHADER_GRAPH_EXPORT_PROJECT="$ADA_GRAPH_QA/project"
export ADAENGINE_SHADER_GRAPH_EXPORT_OUTPUT="$ADA_GRAPH_QA/exports"
swift test --package-path Editor --scratch-path "$ADA_GRAPH_QA/editor-build" \
  --no-parallel -j 4 \
  --filter 'EditorShaderGraph|EditorNodeCanvas|EditorLocalizationTests'
```

Export test по умолчанию только создаёт production packages. Для настоящей
macOS упаковки задать перед повтором `EditorShaderGraphExportTests`:

```bash
export ADAENGINE_SHADER_GRAPH_EXPORT_BUILD_NATIVE=1
export ADAENGINE_SHADER_GRAPH_NATIVE_SCRATCH="$ADA_GRAPH_QA/native-player-build"
swift test --package-path Editor --scratch-path "$ADA_GRAPH_QA/editor-build" \
  --no-parallel -j 4 --filter EditorShaderGraphExportTests
unset ADAENGINE_SHADER_GRAPH_EXPORT_BUILD_NATIVE
```

Child scratch должен отличаться от editor scratch: иначе возможна блокировка
SwiftPM. Не клонировать готовый scratch в другой путь: PCM/modules содержат
исходные абсолютные пути. Fixture не содержит готового `.shadergraphlib`:
проверка обязана собрать свежие варианты.

Нативный Studio (macOS) открывает копию fixture обычным production loader:

```bash
ADA_EDITOR_STANDALONE_SWIFTPM=1 \
ADAENGINE_PACKAGE_PATH="$ADA_GRAPH_ROOT" \
ADA_EDITOR_SCRATCH="$ADA_GRAPH_QA/studio-build" \
ADA_EDITOR_APP_NAME='Shader Graph Studio' \
bash Editor/script/build_and_run.sh run \
  --editor-project="$ADA_GRAPH_QA/project" --mcp-port=39487
```

Нативные Windows/Linux launch scripts и обязательные compiler/runtime overrides
описаны в [Editor README](../README.md). Не переносить приведённые macOS
bundle paths на другую ОС.

Переключить PATH на Swift 6.3.2 **до** WebGPU/WASM команд:

```bash
python3 script/ensure_tint.py --check
ADAENGINE_WEBGPU_SCRATCH="$ADA_GRAPH_QA/webgpu-build" \
  bash script/validate_webgpu.sh

cd "$ADA_GRAPH_QA/exports/web"
swift package --allow-writing-to-package-directory \
  --allow-network-connections all export-web --product AdaNativeGame \
  --scratch-path "$ADA_GRAPH_QA/wasm-build" \
  --swift-sdk swift-6.3.2-RELEASE_wasm --output "$ADA_GRAPH_QA/browser-player" --debug
python3 -m http.server 39489 --bind 127.0.0.1 --directory "$ADA_GRAPH_QA/browser-player"
```

Открыть `http://127.0.0.1:39489/` в Chromium, сохранить console/network и снимок
реального кадра. Проверить наличие checker texture и свежего
`shaders.shadergraphlib` в GameAssets/manifest. Успех WASM build не означает
успех browser playback. Browser Studio **authoring UI** не входит в этот scope.

Для 3D benchmark использовать одинаковую команду на baseline и новой ветке
(разные checkout/scratch, по очереди):

```bash
ADAENGINE_PERF=1 ADAENGINE_GOLDEN_METAL=1 \
  swift test -c release -Xswiftc -enable-testing \
  --scratch-path "$ADA_GRAPH_QA/perf-build" --filter Render3DGPUTests/Benchmarks
```

## Доказательства к передаче

| Проверка | Реальный результат до передачи |
|---|---|
| Core schema/lowering/GLSL/material state | Фокусные suites проходили; owning AdaRender — 190 тестов на раннем слое |
| Финальный Editor resource/canvas/preview/localization + package-only export | 26 тестов / 9 suites прошли с portable fixture и последними изменениями |
| VM + AOT + archive + plugin readiness/cancellation | 24 теста / 6 suites прошли до последнего primitive proxy |
| Финальный CPU/VM/AOT handoff package | 49 тестов / 10 suites прошли, включая portable primitive codec, реальный AOT и plugin cancellation |
| WebGPU full gate | 210 / 41 прошли; расширенные 214 — один timeout (см. выше) |
| Baked WGSL PBR | Отдельный production GPU тест прошёл, pixels совпали с эквивалентным stock material |
| Новые WebGPU references | 5 frames отрендерены и просмотрены; отличие от Metal 0/2/0/5/4 pixels, в пределах существующего допуска |
| macOS / iPad Studio | Запуск и настоящий PBR editor preview со связями подтверждены; final Play/resource reload ещё проверить |
| WASM export | Сборка и выдача всех ресурсов подтверждены; browser playback зависает |
| macOS exported Player | Сборка bare executable и startup log есть; packaged `.app`/pixels ещё проверить |
| Performance / CI / Windows / Linux | Итоговых результатов нет |

Последние результаты focused проверок для handoff записаны в описании PR.
Старые подробные logs/screenshots находятся только на исходном ПК в игнорируемых
`.build-tools/shader-graph-evidence` и `.shader-graph-*.log`; они не нужны для
воспроизведения и не включены в git. Не ссылаться на них как на доступные CI
артефакты. Личные projects/workspace state/bookmarks и build caches в PR не входят.
До передачи исходный список recent projects iPad Simulator восстановлен из backup.

За рамками этой версии остаются vertex displacement, raw shader code nodes,
subgraphs, postprocess graphs и браузерный редактор графов. Их не требуется
добавлять для закрытия перечисленных выше acceptance gates.
