# Logo 管理系统使用说明

## 概述
MCCamera 现在使用全新的动态 Logo 管理系统，支持自动发现和管理 Logo 资源，无需修改代码即可添加新的 Logo。

## 特性

### 🔄 自动发现
- 系统会自动扫描 Assets.xcassets 中的所有 Logo 图片
- 支持常见的品牌名称模式识别
- 智能生成显示名称

### 📱 统一管理
- 水印设置和相框设置已整合到一个页面
- 统一的 Logo 选择界面
- 实时预览效果

### 🎯 易于扩展
- 添加新 Logo 只需拖入图片文件
- 支持自定义显示名称映射
- 自动缓存和优化

## 如何添加新的 Logo

### 方法1：直接添加到 Assets.xcassets
1. 在 Xcode 中打开 `Assets.xcassets`
2. 右键选择 "New Image Set"
3. 将 Logo 图片拖入 1x 槽位
4. 重命名为有意义的名称（如 "xiaomi_logo"）
5. 运行应用，Logo 会自动被发现

### 方法2：使用标准命名规则
支持以下命名模式（系统会自动识别）：
- `[品牌名]_logo`（如 xiaomi_logo）
- `[品牌名]_Logo`（如 Xiaomi_Logo）
- `[品牌名]` （如 xiaomi）

### 方法3：自定义显示名称
在 `DynamicLogoManager.swift` 的 `nameMapping` 字典中添加映射：

```swift
private let nameMapping: [String: String] = [
    "your_logo_filename": "显示的品牌名称",
    "xiaomi_logo": "小米",
    "custom_brand": "自定义品牌"
]
```

## 目前支持的 Logo 品牌

### 相机品牌
- Apple, Canon, Sony, Nikon, Leica, Fujifilm
- Hasselblad, Olympus, Panasonic, Zeiss
- Arri, Panavision, Polaroid, Ricoh, Kodak

### 科技品牌
- DJI, 宝丽来, 哈苏

## 系统架构

### 核心组件
1. **DynamicLogoManager**: 自动扫描和管理系统
2. **DynamicLogo**: Logo 数据模型
3. **FrameSettings**: 整合的设置模型

### 兼容性
- 保持与原有 BrandLogo 枚举的兼容性
- 支持渐进式迁移
- 向后兼容现有设置

## 开发者指南

### 添加新的自动发现规则
在 `discoverAdditionalLogos()` 方法中添加新的品牌模式：

```swift
let brandPatterns = [
    "xiaomi", "huawei", "samsung", // 现有的
    "newbrand", "anotherbrand"     // 新增的
]
```

### 自定义Logo处理
可以重写 `preprocessLogo()` 方法来添加自定义的图片处理逻辑：

```swift
private func preprocessLogo(_ image: UIImage) -> UIImage {
    // 自定义处理逻辑
    return processedImage
}
```

### 调试和监控
系统会输出详细的调试信息：
- ✅ 发现Logo: [品牌名] ([文件名])
- ⚠️ Logo不可用: [文件名]
- 🔍 自动发现Logo: [品牌名] ([文件名])

## 最佳实践

### Logo 图片要求
- 推荐尺寸：64x64 到 512x512 像素
- 格式：PNG（支持透明背景）
- 宽高比：接近 1:1 效果最佳
- 文件大小：建议小于 100KB

### 命名建议
- 使用英文小写和下划线
- 包含品牌标识（如 `_logo` 后缀）
- 避免特殊字符和空格
- 使用有意义的名称

### 性能优化
- 系统会自动缩放过大的图片
- 使用缓存机制提高加载速度
- 支持延迟加载和预加载

## 故障排除

### Logo 不显示？
1. 检查图片是否正确添加到 Assets.xcassets
2. 确认文件名符合命名规则
3. 查看控制台输出的调试信息
4. 调用 `DynamicLogoManager.shared.refresh()` 重新扫描

### 显示名称不正确？
1. 在 `nameMapping` 中添加自定义映射
2. 或者重命名图片文件使其更具描述性
3. 使用 `generateDisplayName()` 方法的逻辑

### 性能问题？
1. 检查图片尺寸是否过大
2. 清理缓存：`DynamicLogoManager.shared.clearCache()`
3. 减少 Logo 数量或优化图片

## 未来计划
- [ ] 支持从远程URL加载Logo
- [ ] Logo分类和标签系统
- [ ] 批量Logo导入工具
- [ ] Logo使用统计和推荐