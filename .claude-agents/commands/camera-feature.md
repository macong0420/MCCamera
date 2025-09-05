# /camera-feature Command

## Purpose
专门用于MCCamera相机功能开发的端到端工作流命令。

## Usage
```
/camera-feature "实现实时景深调节功能"
```

## Workflow Pipeline

### 1. Requirements Analysis (ios-camera-expert)
- 分析AVFoundation景深API可用性
- 确定设备兼容性要求
- 设计用户交互方式

### 2. Architecture Design (swiftui-architect)  
- 设计DepthControlViewModel
- 规划SwiftUI界面组件
- 定义状态管理策略

### 3. Implementation (ios-camera-expert)
- 实现AVCaptureDevice景深控制
- 集成到CameraService
- 添加实时预览更新

### 4. UI Integration (swiftui-architect)
- 创建DepthControlView
- 实现滑动条控件
- 添加视觉反馈动画

### 5. Quality Gates
- 内存使用检查 (< 100MB增量)
- 响应时间验证 (< 200ms)
- 设备兼容性测试
- 代码审查通过

## Success Criteria
- ✅ 功能在支持设备上正常工作
- ✅ UI响应流畅无延迟
- ✅ 内存使用在可控范围
- ✅ 代码符合项目架构标准