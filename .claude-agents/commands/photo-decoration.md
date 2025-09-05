# /photo-decoration Command

## Purpose
专门用于MCCamera照片装饰功能开发的工作流命令。

## Usage
```
/photo-decoration "添加动态Logo水印功能"
```

## Workflow Pipeline

### 1. Design Analysis (photo-processing-specialist)
- 分析图像处理需求
- 设计内存友好的处理策略  
- 确定支持的图像格式

### 2. Pipeline Integration (photo-processing-specialist)
- 扩展PhotoDecorationPipeline
- 实现Logo动态加载机制
- 优化大图像处理流程

### 3. Settings Architecture (swiftui-architect)
- 设计Logo选择界面
- 实现设置数据持久化
- 添加预览功能

### 4. Quality Assurance
- 48MP图像处理测试
- 内存压力测试
- 多格式兼容性验证
- 装饰质量检查

## Success Criteria
- ✅ 支持HEIC/JPEG/ProRAW格式
- ✅ 48MP处理内存 < 800MB
- ✅ 处理时间 < 3秒
- ✅ 图像质量无明显损失