# LifeClock 版本日志

## v1.0.0 (2026-07-07)

### Bug 修复
- **修复出生日期配置不生效的问题**：配置现在通过 `WKNavigationDelegate` 的 `didFinishNavigation` 回调注入，确保页面完全加载后再调用 `window.reconfigureScreenSaver()`，避免配置被默认值覆盖
- **修复 `stopAnimation` 条件写反**：非预览模式下现在会正确清理 webview 和 timer
- **修复 `WVSSConfig.m` 默认值读取逻辑**：`scale`/`brightness` 使用显式 `objectForKey:` 判断，避免 `floatForKey` 返回 `0.0` 时的误判
- **修复 `_Nonnull` 与 `nil` 矛盾**：移除 `static NSDate * _Nonnull const kDefaultBirthDate = nil` 的不安全声明
- **修复 `NSDateFormatter` 格式稳定性**：添加 `en_US_POSIX` locale 和 `localTimeZone`，避免系统 locale 影响日期解析

### 前端优化
- **差量更新 DOM**：时钟数字块在 HTML 中预创建，`tick()` 只更新 `textContent`，不再每秒销毁重建 7 个 DOM 节点
- **移除无意义的三元表达式**：`pad(t.hr, config.timeFormat === '01-12' ? 2 : 2)` 简化为固定值

### Objective-C 代码改进
- **替换废弃 API**：`NSKeyedArchiver archivedDataWithRootObject:` 和 `NSKeyedUnarchiver unarchiveObjectWithData:` 升级为支持 `requiringSecureCoding` 的版本
- **清理未使用代码**：删除 `loadFromStart` 中已失效的 URL 查询参数拼接逻辑
- **配置面板增强**：出生日期选择器增加时分秒选择（`NSDatePickerElementFlagHourMinuteSecond`）和本地时区设置

### 工程改进
- **新增一键编译脚本**：`test.sh` 支持用 `clang` 直接编译（无需完整 Xcode）
- **新增双击安装脚本**：`Install.command` 双击即可在 Terminal 中执行编译安装
- **版本号更新**：`CFBundleShortVersionString` / `CFBundleVersion` 更新为 `1.0.0`
- **显示名称带版本后缀**：`CFBundleName` 改为 `LifeClock v1.0.0`，系统设置中可直接看到版本
- **目录结构优化**：`README.md` 和 `index.html` 整理到 `LifeClock_MAC/` 目录下

---

## 历史版本

### v2.4 (原始版本)
- 基于 WebViewScreenSaver 的初始版本
- 支持 macOS 屏保，使用 WKWebView 加载 HTML 前端
- 基础配置：时间格式、出生日期、缩放、亮度、背景显示
