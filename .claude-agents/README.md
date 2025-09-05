# MCCamera Claude Agents

MCCamera项目的专门化AI工作流系统，基于myclaude多智能体架构。

## 🚀 快速开始

### 基础命令
```bash
# 开发新的相机功能
/camera-feature "实现夜间模式拍摄"

# 开发照片装饰功能  
/photo-decoration "添加艺术相框效果"

# 性能审计和优化
/performance-audit
```

### 专家Agent直接调用
当需要特定领域深度分析时：

```bash
# iOS相机专家
@ios-camera-expert "分析48MP模式下的内存使用模式"

# 照片处理专家  
@photo-processing-specialist "优化HEIC格式的水印处理流程"

# SwiftUI架构师
@swiftui-architect "重构CameraViewModel的状态管理"
```

## 🎯 工作流模式

### 1. Feature-Driven Development
```
需求 → 架构设计 → 实现 → UI集成 → 质量验证
```

### 2. Performance-First Approach  
```
基准测试 → 瓶颈识别 → 优化方案 → 验证效果
```

### 3. Code Quality Gates
- 内存使用标准
- 响应时间要求  
- 架构一致性检查
- 代码审查通过

## 📋 质量标准

### iOS Camera (ios-camera-expert)
- 内存峰值: 48MP模式 < 500MB
- 启动时间: < 1秒
- 镜头切换: < 300ms
- 零内存泄漏

### Photo Processing (photo-processing-specialist)
- 处理时间: 48MP < 3秒
- 内存峰值: < 800MB
- 图像质量损失: < 2%
- 格式支持: HEIC/JPEG/ProRAW

### SwiftUI Architecture (swiftui-architect)
- 视图层级: ≤ 6层
- 状态响应: < 100ms
- 60fps动画
- 内存视图实例: ≤ 50个

## 🔧 扩展指南

### 添加新的Agent
1. 在 `.claude-agents/` 创建新的配置文件
2. 定义专家领域和职责
3. 设置质量标准和审查重点
4. 更新工作流命令集成

### 自定义工作流
1. 在 `commands/` 目录创建新命令
2. 定义pipeline步骤和agent协作
3. 设置成功标准和验收条件
4. 添加使用示例和文档

## 📊 使用统计

跟踪各个agent和命令的使用情况，持续优化工作流效率。

---

*基于myclaude多智能体架构，为MCCamera项目深度定制*