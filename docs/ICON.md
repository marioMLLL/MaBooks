# MaBooks 图标

使用用户提供的“猫咪 + 打开的书 + 蓝色评论气泡”图片作为图标。保留圆角奶油色底板，只移除底板外围的白色背景和留边，四角透明。

源图：`Sources/MaBooks/Resources/AppIcon.png`。

编辑工具：内置 image_gen，采用透明背景抠图并清理边缘。没有使用 Python 重绘或去除背景。

最终编辑提示词：

> Use case: background-extraction. Precisely clean the alpha mask of the supplied already-extracted app icon. Keep every pixel of the cat, book, blue speech bubble and cream rounded-square tile appearance unchanged. The current transparent perimeter contains scattered white flecks and irregular white remnants OUTSIDE the rounded-square tile; remove ALL of those remnants. The output must contain one single clean smooth rounded-square icon tile on genuine transparent alpha, with perfectly empty transparent space outside the tile. No loose white pixels, no jagged rim, no halo, no speckles, no stray islands. Tight square bounding canvas around the tile: its top, bottom, left and right straight segments reach the edges, with fully transparent corners. Preserve original rounded-square curvature; do not add a new outline or shadow and do not redraw the subject. Keep original warm ivory colors, original cat and book and original blue bubble. This is only transparent-edge cleanup and tight crop.

`scripts/make-icon.sh` 使用 macOS 原生工具生成标准 `.iconset` 中的 16、32、128、256、512 像素以及对应 @2x 尺寸，再转换为 `dist/MaBooks.icns`。`scripts/package-app.sh` 将其放入应用的 Contents/Resources，Info.plist 的 CFBundleIconFile 指向该文件。

启动时显式设置 applicationIconImage，确保本地重新打包后 Dock 使用新图标；源码运行时从 SwiftPM 的图标 PNG 加载。

2026-10-12 验证：源 PNG 四角 alpha 为 0；ICNS 可被 NSImage 加载，包含 10 个尺寸表示。已检查浅色／深色背景上的透明边缘，并在打包后的系统“关于 MaBooks”面板中实际看到新图标及版本 0.2.1。14 项回归测试、release 打包和签名校验通过。
