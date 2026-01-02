//
//  ResultPopup.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI

// MARK: - 结果弹窗 (多语言版本)
// 战报发布:是捧杯时刻,还是复盘提升
struct ResultPopup: View {
    @ObservedObject var localization = LocalizationManager.shared
    let isWin: Bool
    let timeElapsed: Int
    let onRetry: () -> Void
    let onReview: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: isWin ? "trophy.fill" : "xmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(isWin ? .yellow : .red)
                .padding(.top).shadow(radius: 5)
            
            VStack(spacing: 5) {
                Text(isWin ? localization.text(.congratulations) : localization.text(.gameOver))
                    .font(.title).fontWeight(.heavy).foregroundColor(isWin ? .green : .red)
                
                if isWin {
                    Text("\(localization.text(.timeElapsed)): \(formatTime(timeElapsed))")
                        .font(.headline).foregroundColor(.secondary)
                } else {
                    Text(localization.text(.betterLuckNextTime))
                        .font(.subheadline).foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 15) {
                    Button(action: onRetry) {
                        Text(localization.text(.playAgain))
                            .fontWeight(.bold).frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }
                    Button(action: onExit) {
                        Text(localization.text(.exit))
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(Color.gray.opacity(0.2)).foregroundColor(.primary).cornerRadius(12)
                    }
                }
                
                Button(action: onReview) {
                    Text(localization.text(.reviewBoard))
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.8)).padding(.vertical, 5)
                }
            }
            .padding(.horizontal)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)  // 磨砂玻璃效果
                // 别问,我就是喜欢磨砂玻璃
                .opacity(0.95)  // 增加不透明度
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .padding(40)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
