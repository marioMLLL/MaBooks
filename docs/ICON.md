# MaBooks 图标

当前图标采用用户提供的睁眼猫咪、书本和蓝色评论气泡原图。

此次使用 macOS 原生 CoreGraphics 直接裁切：移除原图外围白色留边，保留猫咪、书本及奶油色圆角底板，将底板外的四角设为透明。没有重新生成或绘制图案。源 PNG 为 `Sources/MaBooks/Resources/AppIcon.png`，尺寸为 1024 × 1024。

`scripts/make-icon.sh` 使用 sips 和 iconutil 生成 10 个标准图标尺寸。打包时 ICNS 文件名包含图标内容摘要，Info.plist 的 `CFBundleIconFile` 指向该文件，减少系统复用旧图标缓存的机会。

本次安装包版本为 **0.2.2（4）**。更新后请退出旧进程，再打开新安装的 MaBooks。
