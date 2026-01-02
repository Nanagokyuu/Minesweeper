# Minesweeper (iOS)  
一个基于 SwiftUI 构建的、具有“玄学感应”和“命运回放”功能的现代扫雷 App。

## ✨ 项目亮点  
### 🎮 极致手感：  

内置 HapticManager。每一次点击、标记、或是引爆，都有细腻的 Taptic Engine 震动反馈。

### 🔮 命运种子系统：

环境初始化：种子生成不仅看时间，还会参考你的手机电量和纳秒级时间戳。

公平对决：输入相同的种子（Seed），即可生成完全一致的雷区布局，方便和好友进行“同题速通”。

### 🎞️ 导演级回放：

内置回放引擎（Replay Engine），支持 1x/2x/4x 倍速。

记录你的每一次“神之一手”或“愚蠢失误”，支持进度条拖动回溯。

### ☁️ iCloud 同步：  

通过 NSUbiquitousKeyValueStore 实现多设备战绩同步。

### 🌊 视觉特效：

涟漪扩散：翻开空白区域时，格子像水波一样优雅扩散。

连锁爆炸：踩雷时触发切比雪夫距离算法引导的波浪式爆炸效果。

### 😈 地狱难度：  

隐藏的长按触发模式，30x24 的密集雷区，欢迎来到外星人领域。

### 🛠️ 技术栈:  

UI 框架：SwiftUI (采用 Observation 模式逻辑)

架构：MVVM + Delegate Adaptor

数据持久化：UserDefaults + JSON 编码

云端：iCloud Key-Value Store

自定义组件：基于 UIViewRepresentable 封装的 ZoomableScrollView，支持双指缩放和自由平移。

### 🚀 快速开始  

运行环境

Xcode 15.0+

iOS 16.0+
