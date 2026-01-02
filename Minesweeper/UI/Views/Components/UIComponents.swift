//
//  UIComponents.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//

import SwiftUI

// MARK: - 模式切换按钮
// 其实本来是长按插旗的,但是在手机上你用手长按的话就直接把格子盖住了,所以把长按换成了按键切换
// 工具箱:选择你的武器,锤子或旗帜,战术与艺术并存
struct ModeButton: View {
    let title: String, icon: String, isSelected: Bool, color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24))
                Text(title).font(.caption).fontWeight(.bold)
            }
            .frame(maxWidth: .infinity).frame(height: 70)
            .background(isSelected ? color : Color.white)
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(15)
            .shadow(color: isSelected ? color.opacity(0.4) : Color.black.opacity(0.05),
                    radius: isSelected ? 8 : 2, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - 难度选择按钮 (多语言版本)
// 难度卡片:表情包代表心情,文字说明代表现实
struct DifficultyButton: View {
    @ObservedObject var localization = LocalizationManager.shared
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Text(difficulty.icon).font(.system(size: 30))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.localizedName(localization: localization))
                        .font(.headline).fontWeight(.bold)
                    // 【修正】使用 localizedDescription 以支持多语言后缀
                    Text(difficulty.localizedDescription(localization: localization))
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.white : Color.white.opacity(0.5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 规则行组件
// 规则说明:简明扼要,战前动员
struct RuleRow: View {
    let icon: String, text: String
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).foregroundColor(.white).frame(width: 24)
            Text(text).font(.subheadline).fontWeight(.medium).foregroundColor(.white.opacity(0.9))
        }
    }
}
