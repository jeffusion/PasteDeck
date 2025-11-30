//
//  RetentionSlider.swift
//  PasteDeck
//
//  Created by PasteDeck Contributors
//  Copyright © 2025 PasteDeck Contributors. All rights reserved.
//

import SwiftUI
import AppKit

/// 自定义保留历史滑块组件
/// 支持25个离散位置: 1-7天, 1-4周, 1-12月, 1年, 永久
/// 使用完全自定义的拖拽实现，确保段落感和非线性分布
struct RetentionSlider: View {
    @Binding var retentionDays: Int
    @State private var currentPosition: Int = 0 // 当前逻辑位置 (0-24)
    @State private var isDragging: Bool = false

    // 滑块UI配置（扁平化设计）
    private let trackHeight: CGFloat = 4
    private let thumbWidth: CGFloat = 12
    private let thumbHeight: CGFloat = 20

    var body: some View {
        VStack(spacing: 16) {
            // 自定义滑块
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // 轨道背景（更深的对比）
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: trackHeight)

                    // 已填充轨道
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: thumbXPosition(for: currentPosition, width: width), height: trackHeight)

                    // 5条主刻度线
                    ForEach([0, 6, 10, 22, 24], id: \.self) { position in
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 1, height: 8)
                            .offset(x: thumbXPosition(for: position, width: width) - 0.5, y: 0)
                    }

                    // 滑块头（增强对比）
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                        .frame(width: thumbWidth, height: thumbHeight)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .offset(x: thumbXPosition(for: currentPosition, width: width) - thumbWidth / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDragging {
                                        isDragging = true
                                    }
                                    // 根据拖拽位置计算最近的离散点
                                    let newPosition = nearestPosition(for: value.location.x, width: width)
                                    if newPosition != currentPosition {
                                        currentPosition = newPosition
                                        // 触发触觉反馈
                                        NSHapticFeedbackManager.defaultPerformer.perform(
                                            .alignment,
                                            performanceTime: .default
                                        )
                                        // 不在拖拽过程中更新配置，仅在拖拽结束时更新
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    // 仅在拖拽结束时更新配置，触发二次确认逻辑
                                    updateRetentionDays()
                                }
                        )

                    // 静态5标签 (非拖拽状态) - 文字中心对齐到对应刻度位置
                    if !isDragging {
                        ZStack(alignment: .topLeading) {
                            // "天" - 单字，宽度约16px，居中偏移-8
                            Text("天")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 16)
                                .offset(x: thumbXPosition(for: 0, width: width) - 8)

                            // "周" - 单字，宽度约16px，居中偏移-8
                            Text("周")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 16)
                                .offset(x: thumbXPosition(for: 6, width: width) - 8)

                            // "月" - 单字，宽度约16px，居中偏移-8
                            Text("月")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 16)
                                .offset(x: thumbXPosition(for: 10, width: width) - 8)

                            // "年" - 单字，宽度约16px，居中偏移-8
                            Text("年")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 16)
                                .offset(x: thumbXPosition(for: 22, width: width) - 8)

                            // "永久" - 双字，宽度约32px，居中偏移-16
                            Text("永久")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                                .frame(width: 32)
                                .offset(x: thumbXPosition(for: 24, width: width) - 16)
                        }
                        .offset(y: 20)
                        .transition(.opacity)
                    }

                    // 动态值显示 (拖拽状态)
                    if isDragging {
                        Text(positionToText(currentPosition))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .offset(y: 20)
                            .transition(.opacity)
                    }
                }
                .frame(height: 50)
            }
            .frame(height: 50)
            .animation(.easeInOut(duration: 0.2), value: isDragging)
        }
        .onAppear {
            // 初始化位置
            currentPosition = daysToPosition(retentionDays)
        }
        .onChange(of: retentionDays) { newDays in
            // 外部改变天数时同步位置
            if !isDragging {
                currentPosition = daysToPosition(newDays)
            }
        }
    }

    // MARK: - Helper Methods

    /// 计算滑块头在给定位置的X坐标
    /// - Parameters:
    ///   - position: 逻辑位置 (0-24)
    ///   - width: 可用宽度
    /// - Returns: X坐标
    private func thumbXPosition(for position: Int, width: CGFloat) -> CGFloat {
        let visualRatio = logicalToVisual(position)
        return visualRatio * width
    }

    /// 根据拖拽X坐标找到最近的离散位置
    /// - Parameters:
    ///   - x: 拖拽的X坐标
    ///   - width: 可用宽度
    /// - Returns: 最近的逻辑位置 (0-24)
    private func nearestPosition(for x: CGFloat, width: CGFloat) -> Int {
        // 转换为视觉比例
        let ratio = max(0, min(1, x / width))

        // 找到最近的逻辑位置
        var nearestPos = 0
        var minDistance = abs(logicalToVisual(0) - ratio)

        for pos in 1..<25 {
            let distance = abs(logicalToVisual(pos) - ratio)
            if distance < minDistance {
                minDistance = distance
                nearestPos = pos
            }
        }

        return nearestPos
    }

    /// 更新retentionDays绑定值
    private func updateRetentionDays() {
        retentionDays = positionToDays(currentPosition)
    }

    // MARK: - 非线性映射函数

    /// 逻辑位置 → 视觉位置比例
    /// - Parameter logical: 逻辑位置 (0-24)
    /// - Returns: 视觉位置比例 (0.0 - 1.0)
    private func logicalToVisual(_ logical: Int) -> Double {
        switch logical {
        case 0...6:
            // 区段1: "天" → 视觉位置 0-0.25
            let ratio = Double(logical) / 6.0
            return 0.0 + ratio * 0.25

        case 7...10:
            // 区段2: "周" → 视觉位置 0.25-0.5
            let ratio = Double(logical - 7) / 3.0
            return 0.25 + ratio * 0.25

        case 11...22:
            // 区段3: "月" → 视觉位置 0.5-0.75
            let ratio = Double(logical - 11) / 11.0
            return 0.5 + ratio * 0.25

        case 23...24:
            // 区段4: "年+永久" → 视觉位置 0.75-1.0
            let ratio = Double(logical - 23) / 1.0
            return 0.75 + ratio * 0.25

        default:
            return 0.0
        }
    }

    // MARK: - 位置与天数映射

    /// 位置 → 天数
    /// - Parameter position: 滑块位置 (0-24)
    /// - Returns: 对应的天数 (-1表示永久)
    private func positionToDays(_ position: Int) -> Int {
        switch position {
        // 1-7天 (位置0-6)
        case 0...6:
            return position + 1

        // 1-4周 (位置7-10)
        case 7:
            return 7  // 1周
        case 8:
            return 14 // 2周
        case 9:
            return 21 // 3周
        case 10:
            return 28 // 4周

        // 1-12月 (位置11-22)
        case 11...22:
            let months = position - 10
            return months * 30

        // 1年 (位置23)
        case 23:
            return 365

        // 永久 (位置24)
        case 24:
            return -1

        default:
            return 30 // 默认1月
        }
    }

    /// 位置 → 显示文本 (智能单位)
    /// - Parameter position: 滑块位置 (0-24)
    /// - Returns: 格式化的文本 (如 "3天", "2周", "6个月")
    private func positionToText(_ position: Int) -> String {
        switch position {
        // 1-6天
        case 0...5:
            return "\(position + 1)天"

        // 7天 = 1周
        case 6:
            return "1周"

        // 2-4周
        case 7...9:
            let weeks = position - 6
            return "\(weeks)周"

        // 4周 = 1个月
        case 10:
            return "1个月"

        // 2-11月
        case 11...21:
            let months = position - 10
            return "\(months)个月"

        // 12月 = 1年
        case 22:
            return "1年"

        // 1年
        case 23:
            return "1年"

        // 永久
        case 24:
            return "永久"

        default:
            return "1个月"
        }
    }

    /// 天数 → 位置
    /// - Parameter days: 天数 (-1表示永久)
    /// - Returns: 对应的滑块位置 (0-24)
    private func daysToPosition(_ days: Int) -> Int {
        // 永久
        if days == -1 {
            return 24
        }

        // 1年
        if days >= 365 {
            return 23
        }

        // 月份 (30-360天)
        if days >= 30 {
            let months = min(days / 30, 12)
            return 10 + months
        }

        // 周 (7-28天)
        if days >= 7 {
            switch days {
            case 7:
                return 7
            case 8...13:
                return 7 // 靠近1周
            case 14:
                return 8
            case 15...20:
                return 8 // 靠近2周
            case 21:
                return 9
            case 22...27:
                return 9 // 靠近3周
            case 28...29:
                return 10
            default:
                return 10
            }
        }

        // 1-7天
        return max(0, min(days - 1, 6))
    }
}

// MARK: - Preview

#if DEBUG
struct RetentionSlider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // 测试不同初始值
            RetentionSlider(retentionDays: .constant(3))
                .padding()

            RetentionSlider(retentionDays: .constant(14))
                .padding()

            RetentionSlider(retentionDays: .constant(180))
                .padding()

            RetentionSlider(retentionDays: .constant(-1))
                .padding()
        }
        .frame(width: 400)
    }
}
#endif
