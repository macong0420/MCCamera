# /performance-audit Command

## Purpose
全面审计MCCamera应用性能，识别和解决性能瓶颈。

## Usage  
```
/performance-audit
```

## Audit Workflow

### 1. Memory Analysis (ios-camera-expert)
- 分析48MP拍照内存峰值
- 检查AVCaptureSession内存使用
- 识别潜在内存泄漏点

### 2. UI Performance (swiftui-architect)
- SwiftUI视图重绘分析
- @Published状态更新优化
- 动画性能检查

### 3. Image Processing (photo-processing-specialist)  
- PhotoDecorationPipeline性能分析
- Core Graphics操作优化
- 大图像处理内存优化

### 4. Performance Recommendations
- 具体优化建议
- 代码重构方案  
- 性能监控方案

## Output Report
```
MCCamera Performance Audit Report
================================

Memory Usage:
- 48MP Capture Peak: XXXmb
- Decoration Processing: XXXmb  
- UI Layer Memory: XXXmb

Performance Metrics:
- Camera Startup: XXXms
- Lens Switch: XXXms
- Photo Processing: XXXms

Optimization Recommendations:
1. [具体建议]
2. [具体建议] 
3. [具体建议]
```