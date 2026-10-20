<p align="center">
  <img src="assets/hero-light.jpg#gh-light-mode-only" alt="Peek —— Flutter 网络日志工具：请求、响应和错误，直接在应用内查看。支持 dio、talker、chopper 和 http。" width="860">
  <img src="assets/hero-dark.jpg#gh-dark-mode-only" alt="Peek —— Flutter 网络日志工具：请求、响应和错误，直接在应用内查看。支持 dio、talker、chopper 和 http。" width="860">
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
  <a href="README.ru.md">Русский</a> ·
  <b>简体中文</b> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ja.md">日本語</a>
</p>

**Peek 是什么。** Peek 是一款 Flutter 网络日志工具，可直接在应用内查看网络请求：请求、响应、请求头和错误一目了然。通过搜索和筛选快速找到需要的请求，并可将其导出为 cURL、HAR、Markdown 或纯文本。

Peek 通过适配器接入 Dio、Chopper 和 `package:http`。如果你使用 Talker，Peek 会直接读取 Talker 已记录的网络日志，不会重复记录。

**工作原理。** Peek 只观察请求，不改变其内容和行为：不会延迟、重试或改写请求。它不创建客户端，不使用 `HttpOverrides`，也不会向控制台输出任何内容——你可以继续使用熟悉的控制台日志工具。

`package:http` 需要一个包装器，它会原样传递数据。如果 Peek 自身出错，错误会交给 `PeekOptions.onError` 处理，不会中断应用的运行。

**灵感来自 Pulse。** Peek 的设计灵感来自 [Pulse](https://github.com/kean/Pulse)——一款面向 Apple 平台的网络日志工具。Peek 是一个独立项目，专为 Flutter 从零编写。

<p align="center">
  <img src="assets/screenshots/phones-light.png" width="860" alt="浅色主题下的 Peek：控制台、单个请求、JSON 响应体和导出面板">
</p>
<p align="center">
  <img src="assets/screenshots/phones-dark.png" width="860" alt="深色主题下的 Peek：控制台、单个请求、JSON 响应体和导出面板">
</p>

## 快速开始

使用 Dio：在创建客户端的地方加两行代码，在需要按钮的地方加一行：

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(PeekDioInterceptor(Peek.instance));

// 之后，在任意 widget 中：
showPeek(context);
```

使用 Talker：在已有的 Talker 旁边加一行即可——它的日志记录器看到的请求，Peek 也能看到：

```dart
final peek = Peek();
peek.attach(PeekTalkerAdapter(peek, talker: talker));
dio.interceptors.add(TalkerDioLogger(talker: talker));

showPeek(context, peek: peek);
```

使用 Chopper：在拦截器链中加一个拦截器：

```dart
final client = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(Peek.instance)],
);

showPeek(context);
```

使用 `package:http`（它没有拦截器）：用一个客户端包裹你现有的客户端：

```dart
final client = PeekHttpClient(Peek.instance, http.Client());

showPeek(context);
```

想要一个始终可见的悬浮按钮？只需包裹一次应用：

```dart
MaterialApp(
  builder: (context, child) => PeekOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
);
```

这些代码不只是示例片段，而是会实际编译：它们位于 [`packages/peek/example`](packages/peek/example)——一个以全部四种方式发起真实请求、覆盖所有界面的应用。

## 软件包

| 包 | 说明 | 依赖 |
| --- | --- | --- |
| [`peek`](packages/peek) | 核心模型、存储和导出器（`package:peek/core.dart`，纯 Dart）以及 Flutter 界面（`package:peek/peek.dart`） | `flutter`, `meta` |
| [`peek_chopper`](packages/peek_chopper) | `PeekChopperInterceptor`：记录 Chopper 客户端发出的请求 | `peek`, `chopper`, `http` |
| [`peek_dio`](packages/peek_dio) | `PeekDioInterceptor`：记录 Dio 客户端发出的请求 | `peek`, `dio` |
| [`peek_http`](packages/peek_http) | `PeekHttpClient`：记录 `package:http` 客户端发出的请求 | `peek`, `http` |
| [`peek_remote`](packages/peek_remote) | `PeekRemote`：将请求实时传输到 Mac 上的 Peek Pro | `peek`, `bonsoir`, `shared_preferences` |
| [`peek_talker`](packages/peek_talker) | `PeekTalkerAdapter`：读取 Talker 的日志，开箱即支持 `talker_dio_logger` | `peek`, `peek_dio`, `talker`, `talker_dio_logger` |

## 配置

所有配置都在 `Peek` 实例上一次性设置，并对所有适配器生效：

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

- **`enabled`** — 传入 `kDebugMode`，即可在发布版本中关闭 Peek，无需改动适配器。
- **`limits`** — 保留多少条请求、响应体保留多少字节、最多可固定多少条请求。响应体上限的实际开销要乘以 `maxEntries`，调整其中一个时请兼顾另一个。
- **`redaction`** — 默认不做任何脱敏。`PeekRedactionPolicy()` 涵盖常见名称（`Authorization`、`Cookie`、`token`、`password` 及其变体）；每个集合都会替换内置集合，因此扩展时请用展开运算符把默认值加回来。
- **主题** — Peek 自带外观，只从应用中获取亮度。在应用主题中注册覆盖即可修改任意令牌：`ThemeData(extensions: [PeekTheme.light().copyWith(accent: Colors.teal)])`。
- **文案** — 继承 `PeekStrings`，重写需要翻译的内容，并传给 `showPeek(context, strings: ...)`。
- **分享** — Peek 不依赖任何分享相关的包。为它提供一个接入你所用分享包的 `PeekShareDelegate`；示例中使用的是 `share_plus`。传入的内容会说明自身类型：`PeekShareKind.text` 是可粘贴的 URL、cURL 命令或摘要，`PeekShareKind.file` 是可作为附件的 HAR 或会话文件。在 Web 上无需提供任何东西：浏览器能分享文本时会直接分享，否则保存为文件；如果你提供了委托，仍会优先使用它。

## Peek Pro

[Peek Pro](https://github.com/artdima/peek-pro) 是一款 Mac 应用，可实时查看手机、iOS 模拟器或 Android 模拟器的网络日志。在大屏幕上，你可以搜索请求、同时关注多个应用，并将会话保存为文件。

<p align="center">
  <img src="assets/screenshots/peek-pro.png" alt="Mac 上的 Peek Pro：来自两台设备的请求和两个已保存的会话，其中一个请求完整展开" width="860">
</p>

连接方法：添加 [`peek_remote`](packages/peek_remote)，并在调试版本中启动它：

```dart
if (kDebugMode) {
  peek.attach(PeekRemote(peek)..start());
}
```

然后在 Peek 的菜单中选择 Connect to Peek Pro，输入 Mac 应用中显示的代码。连接只需设置一次。

完整指南见 [`doc/remote.md`](doc/remote.md)：如何建立连接，以及哪些数据会留在设备上。如果你在开发自己的日志查看器，可以在 [`doc/spec/`](doc/spec/) 中找到协议和 `.peek` 文件格式的说明。

## 编写自定义适配器

适配器负责观察日志记录器，并将 `PeekEvent` 上报到 `PeekSink`。它只需要一个导入——`package:peek/core.dart`——以及大约一屏代码；[`doc/adapters.md`](doc/adapters.md) 是完整指南，从契约到包结构，末尾附有检查清单。

## 参与贡献

问题和想法请通过 issue 模板提交；pull request 请参阅 [`CONTRIBUTING.md`](CONTRIBUTING.md)，其中包含环境配置、脚本和完成标准。安全问题请私下报告：参见 [`SECURITY.md`](SECURITY.md)。

## 许可证

MIT © 2026 Dmitriy Medyannik。图标轮廓来自 [Lucide](https://lucide.dev)（ISC）；参见 [`NOTICE`](NOTICE)。
