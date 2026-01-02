# Minesweeper (iOS)

![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat&logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS_16.0+-lightgrey.svg?style=flat&logo=apple)
![License](https://img.shields.io/badge/License-GPL_v3-red.svg?style=flat)

一个基于 SwiftUI 和 MVVM 架构构建的现代扫雷游戏。
这不是你记忆中那个枯燥的灰色窗口，这是一个拥有**物理反馈**、**玄学算法**和**完整回放系统**的掌上雷区。

## ✨ 核心亮点 (Features)

### 🌊 视觉与触感
* **涟漪式开区 (Ripple Effect)**：放弃了生硬的刷新，采用 BFS + 曼哈顿距离算法，让安全区的展开像水波纹一样优雅扩散。
* **连锁爆炸引擎**：基于切比雪夫距离（Chebyshev distance）的波次爆炸算法。当你踩雷时，地雷会从中心向外一圈圈引爆，配合粒子特效，带来最解压（或最绝望）的视觉冲击。
* **极致震动反馈**：集成了 `HapticManager`，每一次点击、插旗、胜利或爆炸，都有不同力度的震动反馈。没有震动的扫雷是没有灵魂的。

### 🔮 “玄学”种子系统 (Environmental Seed)
* **不仅仅是随机**：游戏的随机数生成器 (`SeededGenerator`) 不仅依赖时间，还读取了当前的**手机电量**和**纳秒级时间戳**。
* **命运的红线**：每一局游戏都有一个唯一的种子代码。
* **公平竞技**：长按标题旁的重置按钮可复制当前种子。分享给朋友，让他们在**完全相同**的雷区布局下，看看谁才是真正的扫雷之神。

### 📼 影院级回放系统 (Replay System)
* **记录一切**：系统会记录你每一次点击的时间戳和操作类型。
* **复盘神器**：支持 **1x / 2x / 4x** 倍速播放。
* **自由拖拽**：带有进度条，想看哪一步就拖到哪一步（是的，我们处理好了复杂的状态回滚逻辑）。

### ☁️ 云端同步
* **iCloud 集成**：基于 `NSUbiquitousKeyValueStore`，你的战绩和历史记录会在 iPhone 和 iPad 之间自动同步。

### 🌍 多语言支持 (Localization)
* 内置 7 种语言支持：简体中文、繁體中文、English、日本語、한국어、Русский、العربية（支持 RTL 布局）。
* 根据系统语言自动切换，也可以在应用内独立设置。

## 🎮 玩法指南

### 操作模式
底部工具栏提供两种操作模式，适应不同的握持习惯：
* **🔨 挖雷模式 (Dig)**：点击直接翻开格子。如果对已翻开的数字格子点击，且周围旗帜数等于数字，将触发**极速双击 (Chord)** 操作。
* **🚩 插旗模式 (Flag)**：点击格子进行标记/取消标记。

### 难度分级
* **😊 简单**：9x9，10个雷（适合热身）
* **😐 普通**：12x12，20个雷（适合打发时间）
* **😰 困难**：16x16，45个雷（经典挑战）
* **🕵️ ???**：据说在标题界面不仅可以看，还可以进行某种长按操作...（神秘隐藏难度）

## 🛠️ 技术栈 (Tech Stack)

* **Language**: Swift 5
* **UI Framework**: SwiftUI
* **Architecture**: MVVM (Model-View-ViewModel)
* **State Management**: `ObservableObject`, `Combine`
* **Persistence**: `UserDefaults`, `Codable`
* **Cloud**: iCloud Key-Value Store

## 📦 安装与运行

1.  克隆本项目到本地：
    ```bash
    git clone [https://github.com/Nanagokyuu/Minesweeper.git](https://github.com/Nanagokyuu/Minesweeper.git)
    ```
2.  使用 Xcode 打开 `Minesweeper.xcodeproj`。
3.  确保你的开发者账号已配置（为了支持 iCloud 功能）。
4.  选择模拟器或真机，按 `Cmd + R` 运行。

## 📜 许可证

本项目采用 GNU General Public License v3.0 (GPLv3) 许可证。
这意味着你可以自由地运行、研究、共享和修改软件，但基于本项目修改后的衍生作品也必须开源并采用相同的 GPL 协议。详情请参阅 [LICENSE](LICENSE) 文件。

---
*Made with ❤️ (and a lot of coffee) by Nanagokyuu.*
