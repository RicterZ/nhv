# NHV

Swift 编写的自用 iOS 阅读客户端，使用 nhentai API v2。最低 iOS 17，支持 iPhone 和 iPad。

目前完成工程与基础层：API Key 登录、Keychain、会话恢复、中英文本地化及导航骨架。首页、搜索和收藏页尚为占位，作品详情与阅读器将在后续实现。

## 运行工程

使用 Xcode 16 或更新版本打开 `NHV.xcodeproj`，选择 `NHV` Scheme 和 iOS 模拟器运行。已在 Xcode 26.6 验证构建。真机运行时，在 Signing & Capabilities 选择自己的 Team，并按需修改 Bundle Identifier。

命令行构建：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project NHV.xcodeproj -scheme NHV \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath DerivedData build
```

首次启动输入在网站账号设置中生成的 API Key。客户端使用 `GET /api/v2/user` 验证，成功后才写入 Keychain；不调用 login 或 refresh。

## 运行基础层测试

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/NHVCore
```

测试使用可注入的 HTTPTransport 和内存凭据存储，不访问真实账号。覆盖请求参数、认证头、数据默认值、收藏请求、错误分类、取消、会话恢复，以及退出后的迟到响应。

## 继续开发

| 位置 | 职责 |
| --- | --- |
| `App/Features` | 登录、首页、搜索、本人资料及收藏页面 |
| `App/Navigation` | 会话入口与三个主 Tab |
| `App/Shared` | 结构化错误到本地化文案的映射 |
| `App/Resources/Localizable.xcstrings` | 英文及简体中文文案 |
| `Packages/NHVCore/Sources/NHVCore/Networking` | 类型化 API、传输接口、状态码与参数校验 |
| `Packages/NHVCore/Sources/NHVCore/Models` | 作品、标签、本人账号和分页模型 |
| `Packages/NHVCore/Sources/NHVCore/Session` | Keychain 与会话生命周期 |
| `Packages/NHVCore/Sources/NHVCore/Media` | CDN 配置到媒体 URL 的解析 |
| `Packages/NHVCore/Tests/NHVCoreTests` | 独立于 UI 的基础层测试 |
| `openapi.json` | 本次实现使用的 API 合同快照 |

`NHVCore` 是本地 Swift Package，没有第三方依赖。每次登录创建独立的 `AuthenticatedSession`；退出后重建导航视图，后续分页、收藏和阅读状态应放在该会话作用域内。

API 方法已经覆盖作品列表/详情、搜索、标签及标签下作品、本人收藏和 fav/unfav。后续页面通过 `AuthenticatedSession.api` 调用，不直接创建网络请求。

## 本地化

界面跟随系统或 iOS 的 App 语言设置，当前提供 `en` 与 `zh-Hans`。Xcode 的 Scheme → Run → Options → App Language 可分别预览。

- SwiftUI 文案使用可提取的本地化字符串；非 SwiftUI 文案使用 `String(localized:)`。
- 新增文案时同时更新 String Catalog 中的英文与简体中文。
- `NHVCore` 仅返回结构化错误，不包含面向用户的中文或英文提示。
- 作品标题、用户名等服务端内容原样展示；数量、日期等后续使用系统格式化 API。
- 带参数的翻译保留格式占位符，例如 HTTP 状态码的 `%lld`，不拼接句子。

## 接口约束与后续工作

- 只实现本人账号；没有其他用户、评论、投稿或账号编辑模块。
- 列表模型没有收藏状态；详情请求 `include=favorite`，缺失的收藏状态保持未知。
- 搜索与收藏接口不接受 `per_page`。最新作品列表可指定每页数量。
- 媒体地址使用 `/cdn` 返回的服务器和原始路径，不能推测文件扩展名或页码路径。
- API 请求关闭 Cookie、缓存及重定向；CDN 配置请求不附带 API Key。图片传输层后续独立实现。
- 429 保留 `Retry-After` 信息，写操作不自动重试；后续列表及阅读器接入节流和退避调度。
- 网络错误或 403 保留已存 Key，恢复登录收到 401 时清除失效 Key；Keychain 操作失败会显示错误。

下一阶段依次接入首页/详情/收藏、搜索/Tags、阅读器及本人收藏页。阅读器将实现横向翻页、缩放、跳页、前后页预加载与阅读位置恢复。正式 UI 另行 review。

真实账号认证、收藏写入和 CDN 图片加载尚未进行线上联调。
