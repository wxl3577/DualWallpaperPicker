# DualWallpaperPicker（双壁纸）

一个 SwiftUI iOS 应用：从 Clarity Wallpaper 的公开接口随机生成指定数量的候选壁纸，让用户分别选择锁屏和主屏图片，并保存到照片。项目完全不依赖快捷指令。

## 功能

- 可选择随机生成 2–20 张候选壁纸。
- 锁屏与主屏分别选择，并要求两张图片不同。
- 使用 PhotoKit 的“仅添加”权限保存两张选定图片。
- 在系统“用作墙纸”预览中由用户关闭视角缩放。
- GitHub Actions 在 `macos-latest` 上构建无签名 IPA。
- Actions 会先在 iOS 模拟器中启动 App 8 秒，启动不闪退才继续打包。
- 构建产物保留 14 天。

## 使用

1. 从 Actions 的最新成功构建下载 Artifact，解压并侧载 `DualWallpaperPicker-unsigned.ipa`。
2. 随机获取候选图，分别点一张“锁屏”和另一张“主屏”。
3. 点“保存两张壁纸到照片”，首次使用时允许 App 添加照片。
4. 打开“照片”，对两张图片分别使用系统的“用作墙纸”功能。

> iOS 的公开 App SDK 不允许普通第三方 App 静默修改系统壁纸。直接下发墙纸的公开接口属于受监督设备的 MDM 管理能力，因此普通 App 必须让用户在系统墙纸界面确认。

## 本地构建（macOS）

```sh
brew install xcodegen
python3 scripts/make_icon.py
xcodegen generate
xcodebuild -project DualWallpaperPicker.xcodeproj -scheme DualWallpaperPicker -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

壁纸数据来自 `claritywallpaper.com` 及 `wallpapers.claritywallpaper.com`。项目不保存账号信息或壁纸内容。
