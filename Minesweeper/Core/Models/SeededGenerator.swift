//
//  SeededGenerator.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import Foundation

// 种子随机数发生器：上帝掷骰子的地方（但你可以指定点数）
struct SeededGenerator: RandomNumberGenerator {
    // 内部状态：一条 64 位的命运之线
    private var state: UInt64
    
    init(seed: Int) {
        // 初始化：将 Int 转换为 UInt64，确保非零
        // 如果你硬是给了 0，我们也会给你一个看起来很“有故事”的初始值
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 { self.state = 0x987654321 }
    }
    
    mutating func next() -> UInt64 {
        // 线性同余生成器 (LCG)：古典而优雅，便宜好用的随机数方案
        // state = state * A + C (mod 2^64)
        // A 与 C 的选取来自“经验主义”，效果还不错
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state // 把新的命运数抛给你
    }
}
