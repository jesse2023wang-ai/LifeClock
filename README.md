# LifeColock - 人生时钟

创造自己的人生时钟，显示从出生到现在的时间。支持 macOS 屏保。

## 项目概览

本项目 macOS 屏保版位于 `LifeClock_MAC/` 目录下。

---

## macOS 屏保版

### 功能特点

#### 1. 时间格式
- **00-23** - 24小时制显示
- **01-12** - 12小时制显示
- **中文** - 中文单位显示（天、时、分、秒）

#### 2. 出生日期
- 可自定义出生年月日时分秒
- 默认：2000年1月1日 00:00:00
- 从配置的出生日期开始计算显示的时间

#### 3. 缩放调节
- 滑块控制显示大小
- 范围：0.3 - 1.0
- 默认值：0.7

#### 4. 亮度调节
- 滑块控制文字亮度
- 范围：0.1 - 1.0
- 默认值：0.3

#### 5. 显示选项
- **背景** - 显示/隐藏黑色背景
- **在多个显示器上** - 多显示器支持

### 安装方法

#### 快速安装
1. 双击 `LifeClock.saver`
2. 点击"同意"安装
3. 在系统偏好设置中打开"桌面与屏幕保护程序"
4. 选择 "WebViewScreenSaver" 并点击"屏幕保护程序选项"进行配置

#### 从源码编译
```bash
cd LifeClock_MAC/WebViewScreenSaver
xcodebuild -project WebViewScreenSaver.xcodeproj -target WebViewScreenSaver -configuration Release build
```

编译后，屏保文件会生成在 `build/Release/` 目录下。

### 配置说明

1. 打开"系统偏好设置"
2. 进入"桌面与屏幕保护程序"
3. 选择"屏幕保护程序"选项卡
4. 在列表中找到并选择 "WebViewScreenSaver"
5. 点击右下角"屏幕保护程序选项"按钮
6. 根据需要调整各项设置：
   - 选择时间格式
   - 设置出生日期（精确到时分秒）
   - 调整缩放比例
   - 调整亮度
   - 勾选是否显示背景
   - 勾选是否在多个显示器上显示

---

## 项目结构

```
LifeColock/
└── LifeClock_MAC/               # macOS 屏保项目
    ├── README.md                # 本说明文件
    ├── index.html               # 共享的时钟前端页面（基准版本）
    ├── LifeClock.saver          # 编译好的 macOS 屏保文件
    ├── WebViewScreenSaver/      # macOS 屏保源码
    │   ├── WebViewScreenSaver.xcodeproj
    │   ├── Resources/
    │   │   └── index.html       # 供屏保使用的 HTML
    │   └── ...                  # Objective-C 源码
    ├── .github/
    │   └── workflows/
    │       └── ci.yml
    ├── LICENSE
    └── ...
```

### 共享资源

`index.html` 为时钟前端基准版本，位于 `LifeClock_MAC/index.html`：
- `LifeClock_MAC/WebViewScreenSaver/Resources/index.html` 供屏保使用
- 两者保持同步，确保一致的视觉效果

---

## 技术说明

### macOS 屏保
- 基于 [WebViewScreenSaver](https://github.com/liquidx/webviewscreensaver) 开发
- 使用 Objective-C 开发 macOS 屏保引擎
- 使用 WebKit 加载和运行 HTML/CSS/JavaScript
- 支持 Apple Silicon 和 Intel 双架构

---

## 许可证

继承自 WebViewScreenSaver 的 Apache License, Version 2.0

---

**注意**：首次打开 macOS 屏保时可能需要在"系统偏好设置"->"安全性与隐私"中允许打开未签名的应用。
