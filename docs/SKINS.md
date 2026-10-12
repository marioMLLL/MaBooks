# MaBooks 皮肤模块

当前有四套内置皮肤：春日樱语、海盐微风、林间书屋、素纸。点击正文顶部或书架底部的画板图标进入“切换皮肤”，选择立即生效并保存。

皮肤统一控制原生窗口背景、书架、正文、评论面板、强调色、段落高亮与装饰封面。阅读主题（系统／明亮／纸张／夜间）、布局和字号独立保存，切换皮肤不改变书籍或选中段落。可以关闭装饰，只保留配色。微信读书网页内部仍使用官方页面设置。

## 代码位置

- `Sources/ReaderCore/ReaderSkin.swift`：稳定的皮肤 ID、名称与说明。
- `Sources/MaBooks/SkinAppearance.swift`：SkinPalette 配色、环境注入、背景、封面及图标按钮。
- `Sources/MaBooks/SkinPicker.swift`：可视化皮肤卡片、选中状态、装饰及阅读主题设置。
- `Sources/MaBooks/ContentView.swift`：AppStorage 与三栏工作台。

添加皮肤时在 ReaderSkin 增加 case，定义 SkinPalette 和背景，SkinPicker 会自动列出。不要复用或更改旧的 rawValue；它们已用于持久化。`reader.skin` 和 `reader.decorations` 是新增偏好键，首次安装默认使用春日樱语。

## 原创插画

素材：`Sources/MaBooks/Resources/sakura-reading.png`。使用内置 image_gen 生成，用户提供的截图仅作为构图氛围参考，没有将截图或截图里的 UI、文字复制到项目。正文、侧边栏、按钮与评论均是真实 SwiftUI 组件。海盐与森林皮肤采用代码绘制的柔和曲线背景，素纸不包含插画。

最终生成提示词：

> Use case: illustration-story. Asset type: original widescreen decorative background for a native macOS ebook reader named MaBooks. Use the supplied image only as a reference for the soft spring atmosphere and pastel colors; generate a NEW original scene, never reproduce the UI or lettering. A sunlit reading nook by a tall wooden window, blooming pale pink cherry blossom branches framing the top and far sides against a soft blue spring sky. Warm ivory, muted blush, peach sunlight, a few drifting petals. At the LOWER RIGHT corner, a small peacefully sleeping calico cat resting on two closed books on the windowsill; at lower left, a few softly blurred books and a ceramic cup. Japanese animation inspired painterly illustration, delicate watercolor-like light, cozy and beautifully detailed at the edges. Composition: landscape 16:10, very spacious calm pale ivory center covering the middle 70% of image where the app's actual live text and panels will be rendered; most detailed imagery restricted to the outer 10% frame and lower right 15%. Soft natural light, low contrast. No user interface, no windows or buttons, no app mockup, no typography, no logos, no watermark, no people. The cat is small and secondary, leave center clean and quiet.

插画优先从 MaBooks.app/Contents/Resources 的资源 bundle 读取，源码运行时回退到 SwiftPM Bundle.module。打包脚本复制 bundle 并检查图片文件存在。源码运行和打包后都须检查资源存在，不能只检查 Xcode 预览。

## 改名与兼容

仓库、Swift 包、可执行目标、窗口、菜单与应用包名统一为 MaBooks。为保持已有数据连续性，本轮刻意保留旧版 bundle identifier `com.mariomlll.wereadmac`、Keychain service 与 `~/Library/Application Support/WeReadMac` 数据目录；这些是内部存储标识，界面不会显示旧名称。

## 验收

- [x] 打包后樱花背景和封面装饰正常显示。
- [x] 四套皮肤可切换，书架、正文、评论同步换色，所选段落不改变。
- [x] 关闭背景装饰后背景插画消失，阅读操作正常，封面缩略图保留。
- [x] 夜间主题保持暗色且不改变皮肤选择。
- [x] 退出重启后皮肤与装饰设置保留，旧版 TXT 书库可读取。
- [x] 段落导航、阅读设置与专注模式在新布局中可用。

2026-10-12：14 项测试通过，release 编译、资源检查与本地签名验证通过。已在打包后的 MaBooks.app 中实际检查以上勾选项，包含从旧版书库读取验收 TXT、海盐皮肤重启恢复、关闭背景装饰后重启恢复，以及重新开启樱花背景后的实际界面。微信读书真实账号验收仍沿用 docs/ACCEPTANCE.md 中未完成项。
