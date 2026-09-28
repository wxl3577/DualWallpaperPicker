# 鱼头壁纸

## 当前版本 1.0（1）

- 每张候选壁纸显示原图像素尺寸。
- 自动识别当前 iPhone 型号，并按实际屏幕画布显示推荐图像尺寸。
- 随机 20 张时通常从 8 个不同专题均衡抽取，每个专题约 2～3 张。
- 专题列表只请求一次，详情请求限制为每批最多 4 个并发，并缓存本次运行已读取的专题。
- 支持单独设置锁屏或主屏；未选中的目标不调用设置接口，保留原壁纸。
- 再次点击已选按钮可取消该项选择。
- 两张都选时完成提示为“锁屏与主图已设置完成。”；单选时仅提示对应目标。
- 预览改为双列自适应高度，每张图片完整显示，取消固定高度产生的黑色留边。
- 实际系统壁纸继续使用完整图片画布适配，不改变其比例策略。

## 历史版本 1.6.1（10）

- 选择按钮为 7 点圆角、32 点高度，减小上下间距。
- 用户确认没有倾斜移动；本次针对放大裁切，保留已有关闭视差参数。
- 原图先等比完整绘制到竖屏尺寸画布，不同比例留黑边，不裁切、不拉伸。
- 输出 UIImage 点尺寸与屏幕一致，像素密度使用屏幕 scale；缩略图同步采用完整显示。
- 模拟器验证横图、竖图、方图、超长图的完整居中布局，以及输出点尺寸和像素尺寸。
- 仅验证准备好的图像，不宣称模拟器验证了真机系统最终显示。

## 历史版本 1.6.0（9）

补充关闭 `magnifyEnabled` 并设置 `zoomScale = 1.0`，在提交前检查选项对象的视差和放大状态。最终系统效果仍需真机确认。应用界面与错误提示不显示安装工具名称。

- 改名“鱼头壁纸”，保留 Bundle ID，可覆盖更新。
- 保留正常的双列选择及 TrollStore 直接设置实现。
- 锁屏/主屏采用蓝色、紫色胶囊按钮，选中时实色突出。
- 底部“刷新 · 再来 N 张”按当前数量重新获取，清空旧选择。
- 移除使用方式、保存照片功能及照片权限声明。

用 TrollStore 安装 IPA，分别选两张图片，点击“直接设置锁屏与主屏”即可。用户已确认上一版直接设置在其设备上可用。视角缩放参数维持为 0。

以下为旧版本功能记录；其中保存照片与使用说明入口已在 1.6.0 移除。

## 历史记录：1.5.0

一个 SwiftUI iOS 应用：随机选择锁屏和主屏壁纸，支持保存照片，以及 iOS 15 / TrollStore 专用的直接设置入口。项目完全不依赖快捷指令。

### 1.5.0：直接设置与新图标

选好两张图片后点击“直接设置锁屏与主屏”，应用会动态调用系统私有壁纸服务，并将视角缩放参数设为 0。浅色/深色模式使用同一张选中图。需要 TrollStore 安装；普通签名不能授予壁纸专用权限。界面仅报告已提交，不保证私有服务实际生效，需真机确认。若接口不可用，可继续保存到照片。iOS 16 及以上禁用此入口的调用。

构建会以 ad-hoc 签名嵌入 `com.apple.springboard.wallpaper-access` 和 `platform-application` 权限，不包含开发者证书。产物保留原有 unsigned 文件名以兼容下载流程。

接口研究参考：[WallpaperSetter](https://github.com/Skittyblock/WallpaperSetter)。本项目桥接实现独立编写，不包含其壁纸文件读取或全盘访问权限。

新图标使用内置图像生成工具制作，提示词概要：参考原图蓝紫、青色、玫红、橙黄低多边形渐变，中心白色叠放壁纸卡片与山景太阳，无文字、不透明方形图标。源图为 `assets/wallpaper-icon.png`。

最低支持 iOS 15.0，包含 iOS 15.6 / TrollStore 安装场景。

## 功能

- 可选择随机生成 2–20 张候选壁纸。
- 锁屏与主屏分别选择，并要求两张图片不同。
- 使用 PhotoKit 的“仅添加”权限保存两张选定图片。
- 在系统“用作墙纸”预览中由用户关闭视角缩放。
- GitHub Actions 在 `macos-latest` 上构建无签名 IPA。
- Actions 会先在 iOS 模拟器中启动 App 8 秒，启动不闪退才继续打包。
- Actions 会检查 IPA 内 Info.plist 和 Mach-O 二进制的最低系统版本均为 iOS 15.0。
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
cp assets/wallpaper-icon.png DualWallpaperPicker/Assets.xcassets/AppIcon.appiconset/AppIcon.png
xcodegen generate
xcodebuild -project DualWallpaperPicker.xcodeproj -scheme DualWallpaperPicker -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

壁纸数据来自 `claritywallpaper.com` 及 `wallpapers.claritywallpaper.com`。项目不保存账号信息或壁纸内容。
