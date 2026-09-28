# DualWallpaperPicker（双壁纸）

一个 SwiftUI iOS 应用：从 Clarity Wallpaper 的公开接口随机生成指定数量的候选壁纸，让用户分别选择锁屏和主屏图片，再交给随 App 附带的快捷指令完成系统壁纸设置。

## 功能

- 可选择随机生成 2–20 张候选壁纸。
- 锁屏与主屏分别选择，并要求两张图片不同。
- 辅助快捷指令关闭设置预览和“视角缩放”。
- GitHub Actions 在 `macos-latest` 上构建无签名 IPA。
- 构建产物同时包含 IPA 和辅助快捷指令，保留 14 天。

## 使用

1. 从 Actions 的最新成功构建下载 Artifact，解压并侧载 `DualWallpaperPicker-unsigned.ipa`。
2. 首次打开 App，点“首次使用：安装辅助快捷指令”，在分享菜单中用“快捷指令”打开并添加。
3. 随机获取候选图，分别点一张“锁屏”和另一张“主屏”。
4. 点“设置锁屏与主屏壁纸”。App 会把两个图片 URL 写入剪贴板并运行 `双壁纸设置`。

> iOS 的公开 SDK 不允许普通第三方 App 直接修改系统壁纸，因此实际设置由 Apple 快捷指令的“设定墙纸”动作完成。首次导入和首次运行时，iOS 可能要求用户确认权限。

## 本地构建（macOS）

```sh
brew install xcodegen
python3 scripts/make_icon.py
python3 scripts/make_shortcut.py DualWallpaperPicker/Resources/双壁纸设置.shortcut
xcodegen generate
xcodebuild -project DualWallpaperPicker.xcodeproj -scheme DualWallpaperPicker -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

壁纸数据来自 `claritywallpaper.com` 及 `wallpapers.claritywallpaper.com`。项目不保存账号信息或壁纸内容。
