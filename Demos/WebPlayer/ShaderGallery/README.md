# Shader Gallery

Пример Web Player API 2: внешний PNG, WGSL, TTF и WAV. Swift-код игры отсутствует.

`project.json` перечисляет ресурсы по идентификаторам и связывает шейдер с текстурой
в материале `poster-effect`. `Sources/Main.ada` использует три компонента каталога:

- `NativeView("Player.Material", material: "poster-effect", amount: amount)` —
  рисует материал в области AdaUI; `amount` попадает в `parameters.x` шейдера.
- `NativeView("Player.Text", font: "display", text: "SHADER LAB", size: 28)` —
  использует внешний файл шрифта. Атлас создаётся при первом использовании и кешируется.
- `NativeView("Player.Audio", audio: "music")` — запускает/останавливает музыку
  и показывает результат или ошибку Web Audio.

## Контракт WGSL UI material ABI 1

Vertex stage и проекцию AdaUI предоставляет Player. Пользователь пишет fragment
stage с entry point `player_fragment`, UV во входе `@location(0)` и цветом
во выходе `@location(0)`.

```wgsl
@group(1) @binding(0) var<uniform> parameters: vec4<f32>;
@group(1) @binding(1) var image: texture_2d<f32>;
@group(1) @binding(2) var imageSampler: sampler;
```

Имена, типы и bindings фиксированы этой версией ABI. Материалы с одним ID
используют общий экземпляр; для независимых параметров объявите разные material ID,
которые могут ссылаться на один шейдер и одну текстуру.
Синтаксические ошибки WGSL проверяются браузером перед запуском игры;
диагностика содержит путь, строку и колонку на экране загрузчика и в консоли.

## Упаковка

Сначала соберите шаблон `AdaWebPlayer` по ADR 0002, затем:

```sh
swift run AdaWebPlayerPackager dist/web-player-template \
  Demos/WebPlayer/ShaderGallery dist/shader-gallery
cd dist/shader-gallery
zip -r ../shader-gallery-itch.zip .
```

Шаблон должен поддерживать runtime API 2. Замена PNG, TTF, WGSL и WAV требует
только повторной упаковки. Бинарник `AdaWebPlayer.wasm` остаётся прежним.

## Границы прототипа

- PNG загружается как RGBA-текстура. Импорт сжатых GPU-форматов, mipmaps и
  управление памятью больших сцен — последующие этапы.
- TTF/OTF обрабатываются существующим Font runtime; большие наборы символов
  и динамическое добавление глифов требуют отдельной проверки.
- Музыка запрашивается только по нажатию и декодируется в памяти Web Audio.
  Для небольшого демонстрационного WAV это подходит; потоковая музыка пока
  не реализована. Проверен WAV; MP3/M4A зависят от декодера браузера.
- Web Audio подключён к `Player.Audio`. Общий `AdaAudio.AudioServer` ещё использует
  нативный MiniAudioEngine, поэтому его стандартный плагин может вывести ошибку
  инициализации; она не мешает этому адаптеру.
- Пользовательский WGSL проверен в WebGPU. Metal-preview, сцены/ECS,
  экспорт из UI iPad и реальный Safari на iPad в эту проверку не входят.

PNG и WAV — процедурные тестовые ресурсы этого примера; их можно свободно
использовать и изменять. Шрифт — Fira Code, SIL Open Font License 1.1;
лицензия включена в каталог ресурсов и экспортируемый архив.
