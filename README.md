# Minesweeper (iOS)

![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat&logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS_16.0+-lightgrey.svg?style=flat&logo=apple)
![License](https://img.shields.io/badge/License-GPL_v3-red.svg?style=flat)

一个基于 SwiftUI 和 MVVM 架构构建的现代扫雷游戏。
这不是你记忆中那个枯燥的灰色窗口，这是一个拥有**物理反馈**、**玄学算法**、**多皮肤换装**和**完整回放系统**的掌上雷区。

## ✨ 核心亮点 (Features)

### 🌊 视觉与触感
* **涟漪式开区 (Ripple Effect)**：BFS + 曼哈顿距离延迟，让安全区展开像水波纹一样扩散。
* **连锁爆炸引擎**：切比雪夫距离分波次引爆，带粒子特效；被你点中的那颗雷会高亮为红色，其他雷保持统一底色。
* **极致震动反馈**：`HapticManager` 区分轻触/重击/成功/失败，挖雷、插旗、爆炸、胜利都有不同力度。

### 🖌️ 主题与外观
* **双皮肤**：经典 (💣) 与花圃 (🌼)，从格子底色到爆炸色全套适配。
* **外观模式**：跟随系统深浅色，确保深夜游玩不会刺眼。
* **无白底刺眼问题**：雷格底色与数字格一致，深色模式也和谐。

### 🔮 “玄学”种子系统 (Environmental Seed)
* **不止时间戳**：随机数依赖时间 + 电量 + 纳秒级时间戳。
* **命运的种子**：每局都有唯一种子；长按标题旁重置可复制并分享，保证完全相同的雷区布局。
* **自定义种子挑战**：输入数字直接复刻局面，与朋友公平对战。

### 🚫 无猜模式 (No Guessing Mode)
* 开关在设置页；开启后可确保局面可逻辑推导，无需极限二选一。

### 📼 影院级回放系统 (Replay System)
* **记录一切**：时间戳 + 操作类型全记录。
* **倍速播放**：1x / 2x / 4x。
* **自由拖拽**：进度条随意跳转，状态可正确回滚。
* **胜利补全**：胜利回放结束时自动翻开所有非雷格。

### ☁️ 云端同步
* **iCloud**：基于 `NSUbiquitousKeyValueStore`，历史记录自动同步多设备。

### 🌍 多语言支持 (Localization)
* 内置 8 种语言：简体中文、繁體中文、English、日本語、한국어、Русский، العربية、Français（支持 RTL）。
* 可跟随系统，也可在应用内独立设置。

### 🧠 玩法与规则补充
* **双模式操作**：底部工具栏切换“挖雷”与“插旗”。
* **极速双击 (Chord)**：对已翻开的数字格，当周围旗帜数等于数字时快速开周围格子。
* **胜利自动揭示**：只要未踩雷获胜，系统自动翻开所有非雷格，复盘更直观。

## 🎮 难度分级
* **😊 简单**：9×9 · 10 雷（热身）
* **😐 普通**：12×12 · 20 雷（消遣）
* **😰 困难**：16×16 · 45 雷（经典挑战）
* **？？？**：据说在标题界面不仅可以看，还可以进行某种长按操作...（神秘隐藏难度）

## 🛠️ 技术栈 (Tech Stack)
* **Language**: Swift 5
* **UI Framework**: SwiftUI
* **Architecture**: MVVM
* **State Management**: `ObservableObject`, Combine
* **Persistence**: `UserDefaults`, `Codable`
* **Cloud**: iCloud Key-Value Store
* **Effects**: 自定义涟漪 Flood Fill、粒子爆炸、连锁爆炸节奏控制、全局触感反馈

## 📦 安装与运行
1. 克隆仓库：
   ```bash
   git clone https://github.com/Nanagokyuu/Minesweeper.git
   ```
2. 用 Xcode 打开 `Minesweeper.xcodeproj`。
3. 确保已配置开发者账号以启用 iCloud。
4. 选择模拟器或真机，`Cmd + R` 运行。

## 📜 许可证
本项目采用 GNU General Public License v3.0 (GPLv3)。你可以自由运行、研究、共享和修改，但衍生作品需同样以 GPL 开源。详见 [LICENSE](LICENSE)。

---
*Made with ❤️ (and a lot of coffee) by Nanagokyuu.*
