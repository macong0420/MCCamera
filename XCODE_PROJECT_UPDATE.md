# Xcode 项目文件更新指南

## 问题说明
由于我们重新组织了文件结构，Xcode 项目文件 (.xcodeproj) 中的文件引用需要更新。

## 解决步骤

### 1. 打开 Xcode 项目
```bash
open MCCamera.xcodeproj
```

### 2. 清理旧的文件引用
在 Xcode 的项目导航器中，你会看到一些显示为红色的文件（表示找不到文件）：
- `CameraService.swift` (已移动到 `Core/Camera/`)
- `CameraView.swift` (已移动到 `Features/Camera/`)
- 其他已移动的文件

**操作**: 右键点击这些红色文件 → 选择 "Delete" → 选择 "Remove Reference"

### 3. 添加新的文件夹结构
1. 右键点击项目根目录 "MCCamera" 
2. 选择 "Add Files to MCCamera..."
3. 选择以下文件夹（确保选中 "Create folder references"）：
   - `Core/`
   - `Features/`
   - `Shared/`

### 4. 验证文件引用
确保以下文件都正确添加到项目中：

#### Core 模块
- `Core/Camera/CameraService.swift`
- `Core/Camera/CameraDiscovery.swift`
- `Core/Camera/HighResolutionCameraManager.swift`
- `Core/Location/LocationManager.swift`
- `Core/Photo/PhotoProcessor.swift`
- `Core/Photo/PhotoSettingsManager.swift`

#### Features 模块
- `Features/Camera/CameraView.swift`
- `Features/Camera/CameraViewModel.swift`
- `Features/Camera/CameraPreview.swift`
- `Features/Camera/Views/` (所有子文件)
- `Features/Settings/SettingsView.swift`
- `Features/Watermark/` (所有文件)

#### Shared 模块
- `Shared/Models/` (所有模型文件)
- `Shared/Extensions/` (所有扩展文件)
- `Shared/Components/` (所有组件文件)

### 5. 编译测试
1. 按 `Cmd + B` 编译项目
2. 解决任何剩余的编译错误

## 常见问题

### Q: 文件显示为红色怎么办？
A: 右键点击红色文件 → "Delete" → "Remove Reference"，然后重新添加正确路径的文件

### Q: 编译时提示找不到某个类型？
A: 确保相关的 .swift 文件已正确添加到项目 target 中

### Q: 如何批量添加文件？
A: 可以直接拖拽整个文件夹到 Xcode 项目导航器中

## 自动化脚本（可选）
如果手动操作麻烦，也可以删除当前的 .xcodeproj 文件，然后重新创建项目：

```bash
# 备份重要文件
cp -r MCCamera.xcodeproj MCCamera.xcodeproj.backup

# 在 Xcode 中创建新项目，然后添加所有 .swift 文件
```

## 验证完成
完成后，项目结构在 Xcode 中应该显示为：
```
MCCamera/
├── Core/
├── Features/
├── Shared/
├── Assets.xcassets
├── ContentView.swift
└── MCCameraApp.swift
```