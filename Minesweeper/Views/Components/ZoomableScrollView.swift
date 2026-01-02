//
//  ZoomableScrollView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//
//  这个迟到的双指缩放优化终于来了
//  简单才是最强的：去掉了花里胡哨的计算，只要内容在，就能看到
//  这次终于彻底解决了缩放后点击跳动的问题，以及小棋盘不居中的问题，可喜可贺

import SwiftUI

// 双指缩放导演：让你的雷区既能远观也能近看
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content() // 剧本（内容）交到导演手里
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // 1. 初始化 UIScrollView
        // 【关键改动】：使用自定义的子类，为了重写 layoutSubviews 完美解决居中问题
        let scrollView = CenteringScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0 // 最近看一看细节
        scrollView.minimumZoomScale = 0.1 // 允许极小缩放，看全景
        scrollView.bouncesZoom = true // 弹性手感更愉悦
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // 【关键】：必须允许溢出，防止缩小时内容被切
        scrollView.clipsToBounds = false
        scrollView.backgroundColor = .clear
        
        // 关键：允许内容视图与 ScrollView 不同的交互
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        
        // 2. 添加 HostingController 的视图
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.backgroundColor = .clear
        // 告诉自定义 ScrollView 谁才是主角（需要居中的内容）
        scrollView.contentView = hostedView
        scrollView.addSubview(hostedView)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // 1. 更新 SwiftUI 内容
        context.coordinator.hostingController.rootView = self.content
        
        // 【紧急修复】导演请注意：
        // 如果观众（用户）正在操作镜头（缩放/拖拽），或者镜头还在惯性滑动，
        // 就不要强制重置布局了，否则画面会疯狂闪烁，观众会退票的
        if uiView.isZooming || uiView.isDragging || uiView.isDecelerating {
            return
        }
        
        let hostedView = context.coordinator.hostingController.view!
        
        // 使用简单的 sizeThatFits，因为我们已经改用 Stack，尺寸是实打实的
        // 这个 targetSize 是“1倍缩放”下的理想尺寸
        let targetSize = hostedView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        
        // 【核心修复逻辑】：
        // 之前的 bug 是：contentSize 是缩放后的大小（比如 2 倍），targetSize 是原始大小（1 倍）。
        // 直接比较会导致代码以为尺寸变了，从而强制重置 Frame，导致画面跳动。
        // 现在我们把当前的 contentSize 还原回 1 倍，再跟 targetSize 比较。
        let currentUnscaledWidth = uiView.contentSize.width / uiView.zoomScale
        let currentUnscaledHeight = uiView.contentSize.height / uiView.zoomScale
        
        // 只有当“实际内容结构”发生变化（比如切换难度、新开局）时，才重置布局
        if abs(currentUnscaledWidth - targetSize.width) > 1.0 ||
           abs(currentUnscaledHeight - targetSize.height) > 1.0 {
            
            // 重置 Frame 和 ContentSize
            hostedView.frame = CGRect(origin: .zero, size: targetSize)
            uiView.contentSize = targetSize
            
            // 只有在真的重置了布局（新开局）时，才把缩放归位
            // 如果只是点击格子刷新界面，因为尺寸没变，不会进到这里，所以不会跳动
            uiView.zoomScale = 1.0
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view // 镜头对准舞台
        }
        
        // 注意：这里不再需要手动 centerContent，因为我们在 CenteringScrollView 的 layoutSubviews 里做了
        // 那才是处理居中的正确时机
    }
}

// MARK: - 自定义 ScrollView (为了完美的居中)
// 这是一个幕后英雄，它默默地确保无论你怎么缩放，画面都在它该在的地方
fileprivate class CenteringScrollView: UIScrollView {
    // 引用内容视图
    weak var contentView: UIView?
    
    // 系统的布局回调：这是处理居中的“天条”，比任何手动计算都靠谱
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let contentView = contentView else { return }
        
        // 计算居中位置
        let boundsSize = self.bounds.size
        var frameToCenter = contentView.frame
        
        // 水平居中：如果内容比屏幕小，就放中间；如果比屏幕大，就贴边（0）
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2.0
        } else {
            frameToCenter.origin.x = 0
        }
        
        // 垂直居中：同上
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2.0
        } else {
            frameToCenter.origin.y = 0
        }
        
        // 应用位置
        contentView.frame = frameToCenter
    }
}
