<p align="center">
  <img src="assets/hero-light.jpg#gh-light-mode-only" alt="Peek — сетевой логер для Flutter: запросы, ответы и ошибки прямо в приложении. Подключается к dio, talker, chopper и http." width="860">
  <img src="assets/hero-dark.jpg#gh-dark-mode-only" alt="Peek — сетевой логер для Flutter: запросы, ответы и ошибки прямо в приложении. Подключается к dio, talker, chopper и http." width="860">
</p>

<p align="center">
  <a href="https://pub.dev/packages/peek"><img src="https://img.shields.io/pub/v/peek.svg" alt="pub package"></a>
  <a href="https://artdima.github.io/peek/"><img src="https://img.shields.io/badge/demo-live-ff6a3d?logo=flutter&logoColor=white" alt="Live demo"></a>
  <a href="https://github.com/artdima/peek/actions/workflows/ci.yml"><img src="https://github.com/artdima/peek/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/artdima/peek"><img src="https://codecov.io/gh/artdima/peek/branch/main/graph/badge.svg" alt="Coverage"></a>
  <a href="https://github.com/artdima/peek/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <b>Русский</b> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ja.md">日本語</a>
</p>

**Что такое Peek.** Peek — сетевой логер для Flutter с просмотром запросов
прямо в приложении. Он показывает запросы, ответы, заголовки и ошибки. Нужный
вызов легко найти через поиск и фильтры, а данные — экспортировать в cURL,
HAR, Markdown или текст.

Peek подключается к Dio, Chopper и `package:http` через адаптеры. Если вы
используете Talker, Peek берёт уже записанные сетевые логи, не дублируя их.

<p align="center">
  <a href="https://artdima.github.io/peek/"><img src="assets/demo-button.png" width="300" alt="Открыть живое демо: работает в браузере, без установки"></a>
</p>

**Как он работает.** Peek наблюдает за запросами, не меняя их содержимое и
поведение: не задерживает, не повторяет и не переписывает их. Он не создаёт
клиент, не использует `HttpOverrides` и ничего не печатает в консоль —
привычный консольный логер можно оставить.

Для `package:http` нужна обёртка, которая передаёт данные без изменений. Если
в самом Peek возникает ошибка, она передаётся в `PeekOptions.onError`, не
прерывая работу приложения.

**Вдохновлён Pulse.** Идея Peek вдохновлена
[Pulse](https://github.com/kean/Pulse), сетевым логером для платформ Apple.
Peek — независимый проект, написанный с нуля для Flutter.

<p align="center">
  <img src="assets/screenshots/phones-light.png" width="860" alt="Peek в светлой теме: консоль, один вызов, JSON-тело и шторка экспорта">
</p>
<p align="center">
  <img src="assets/screenshots/phones-dark.png" width="860" alt="Peek в тёмной теме: консоль, один вызов, JSON-тело и шторка экспорта">
</p>

## Быстрый старт

С Dio — две строки там, где собирается клиент, и одна там, где нужна кнопка:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(PeekDioInterceptor(Peek.instance));

// Позже, из любого виджета:
showPeek(context);
```

С Talker — одна строка рядом с тем Talker, который у вас уже есть: вызовы,
которые видят его логеры, видит и Peek:

```dart
final peek = Peek();
peek.attach(PeekTalkerAdapter(peek, talker: talker));
dio.interceptors.add(TalkerDioLogger(talker: talker));

showPeek(context, peek: peek);
```

С Chopper — один интерцептор в цепочке:

```dart
final client = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(Peek.instance)],
);

showPeek(context);
```

С `package:http`, у которого интерцепторов нет, — один клиент поверх вашего:

```dart
final client = PeekHttpClient(Peek.instance, http.Client());

showPeek(context);
```

Хочется плавающую кнопку, которая всегда под рукой? Оберните приложение один
раз:

```dart
MaterialApp(
  builder: (context, child) => PeekOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
);
```

Эти строки компилируются, а не просто процитированы: они живут в
[`packages/peek/example`](packages/peek/example) — приложении, которое делает
настоящие вызовы всеми четырьмя способами и проходит по каждому экрану.

## Пакеты

| Пакет | Что это | Зависит от |
| --- | --- | --- |
| [`peek`](packages/peek) | Модель, хранилище и экспортёры (`package:peek/core.dart`, чистый Dart) и Flutter-интерфейс (`package:peek/peek.dart`) | `flutter`, `meta` |
| [`peek_chopper`](packages/peek_chopper) | `PeekChopperInterceptor`: сообщает, что делает клиент Chopper | `peek`, `chopper`, `http` |
| [`peek_dio`](packages/peek_dio) | `PeekDioInterceptor`: сообщает, что делает клиент Dio | `peek`, `dio` |
| [`peek_http`](packages/peek_http) | `PeekHttpClient`: сообщает, что делает клиент `package:http` | `peek`, `http` |
| [`peek_remote`](packages/peek_remote) | `PeekRemote`: передаёт вызовы в Peek Pro на Mac, вживую | `peek`, `bonsoir`, `shared_preferences` |
| [`peek_talker`](packages/peek_talker) | `PeekTalkerAdapter`: читает, что логирует Talker; `talker_dio_logger` понимает из коробки | `peek`, `peek_dio`, `talker`, `talker_dio_logger` |

## Настройка

Всё задаётся один раз, на экземпляре `Peek`, и действует для каждого
адаптера:

```dart
final peek = Peek(
  options: PeekOptions(
    enabled: kDebugMode,
    limits: const PeekLimits(maxEntries: 500, maxBodyBytes: 256 * 1024),
    redaction: PeekRedactionPolicy(
      headerNames: {...PeekRedactionPolicy.defaultHeaderNames, 'x-session'},
    ),
    onError: (error, stackTrace) => log('peek: $error'),
  ),
);
```

- **`enabled`** — передайте `kDebugMode`, чтобы выключить Peek в релизных
  сборках, не трогая адаптеры.
- **`limits`** — сколько вызовов хранить, сколько байт тела, сколько вызовов
  можно закрепить. Лимит тела обходится в `maxEntries` таких тел, так что
  поднимайте одно с оглядкой на другое.
- **`redaction`** — ничего не маскируется, пока вы не попросите.
  `PeekRedactionPolicy()` покрывает привычные имена (`Authorization`,
  `Cookie`, `token`, `password` и их родню); каждое множество заменяет
  встроенное, так что расширяйте его, подставляя значения по умолчанию
  обратно через spread.
- **Тема** — у Peek свой облик, из приложения он берёт только яркость.
  Зарегистрируйте override в теме приложения, чтобы поменять любой токен:
  `ThemeData(extensions: [PeekTheme.light().copyWith(accent: Colors.teal)])`.
- **Строки** — унаследуйте `PeekStrings`, переопределите то, что переводите,
  и передайте в `showPeek(context, strings: ...)`.
- **Шаринг** — Peek не зависит ни от одного пакета для шаринга. Передайте
  ему `PeekShareDelegate`, подключённый к тому, что вы используете; пример
  показывает это с `share_plus`. Что приходит, то и говорит о себе:
  `PeekShareKind.text` — URL, команда cURL или сводка, чтобы вставить,
  `PeekShareKind.file` — HAR или сессия, чтобы приложить. На web передавать
  нечего: браузер делится текстом, где умеет, и сохраняет файл иначе, а
  переданный там делегат всё равно используется вместо него.

## Peek Pro

[Peek Pro](https://github.com/artdima/peek-pro) — приложение для Mac, в
котором удобно смотреть сетевые логи с телефона, симулятора или эмулятора в
реальном времени. На большом экране можно искать запросы, следить за
несколькими приложениями одновременно и сохранять сессии в файлы.

<p align="center">
  <img src="assets/screenshots/peek-pro.png" alt="Peek Pro на Mac: вызовы с двух устройств и две сохранённые сессии, один вызов открыт целиком" width="860">
</p>

Для подключения добавьте [`peek_remote`](packages/peek_remote) и включите
его в отладочных сборках:

```dart
if (kDebugMode) {
  peek.attach(PeekRemote(peek)..start());
}
```

Затем в меню Peek выберите Connect to Peek Pro и введите код из приложения
на Mac. Подключение достаточно настроить один раз.

Подробная инструкция — в [`doc/remote.md`](doc/remote.md): как настроить
подключение и какие данные остаются на устройстве. Если вы разрабатываете
свой просмотрщик логов, описание протокола и формата файлов `.peek` найдёте
в [`doc/spec/`](doc/spec/).

## Свой адаптер

Адаптер наблюдает за логером и сообщает `PeekEvent`'ы в `PeekSink`. Ему нужен
один импорт — `package:peek/core.dart` — и около экрана кода;
[`doc/adapters.md`](doc/adapters.md) — руководство от контракта до раскладки
пакета, с чек-листом в конце.

## Участие

Ошибки и идеи — через шаблоны issue; pull request'ы — через
[`CONTRIBUTING.md`](CONTRIBUTING.md), где описаны настройка, скрипты и
критерии готовности. Сообщения о безопасности — приватно: см.
[`SECURITY.md`](SECURITY.md).

## Лицензия

MIT © 2026 Dmitriy Medyannik. Контуры иконок — из
[Lucide](https://lucide.dev) (ISC); см. [`NOTICE`](NOTICE).
