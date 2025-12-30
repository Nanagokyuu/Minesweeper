//
//  ZoomableScrollView.swift
//  Minesweeper
//
//  Created by Nanagokyuu on 2025/12/28.
//
//  这个迟到的双指缩放优化终于来了
//  简单才是最强的：去掉了花里胡哨的计算，只要内容在，就能看到

import SwiftUI

// 双指缩放导演：让你的雷区既能远观也能近看
struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content() // 剧本（内容）交到导演手里
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // 1. 初始化 UIScrollView
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0 // 最近看一看细节
        scrollView.minimumZoomScale = 0.05 // 【修改】：允许极小缩放，看全景
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
        hostedView.clipsToBounds = false // 同上，内容也不要裁切
        scrollView.addSubview(hostedView)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // 1. 更新 SwiftUI 内容
        context.coordinator.hostingController.rootView = self.content
        
        let hostedView = context.coordinator.hostingController.view!
        
        // 使用简单的 sizeThatFits，因为我们已经改用 Stack，尺寸是实打实的
        let targetSize = hostedView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        
        if targetSize.width > 0 && targetSize.height > 0 && uiView.contentSize != targetSize {
            
            hostedView.frame = CGRect(origin: .zero, size: targetSize)
            uiView.contentSize = targetSize
            
            // 简单的居中调用，不做复杂的缩放重置，防止打断用户操作
            DispatchQueue.main.async {
                context.coordinator.centerContent(in: uiView)
            }
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
        
        // 核心修复：在缩放过程中不断修正居中
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView) // 镜头别跑偏，居中才有美
        }
        
        func centerContent(in scrollView: UIScrollView) {
            let boundsSize = scrollView.bounds.size
            var contentFrame = hostingController.view.frame

            if boundsSize.width > contentFrame.size.width {
                contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0
            } else {
                contentFrame.origin.x = 0.0
            }

            if boundsSize.height > contentFrame.size.height {
                contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0
            } else {
                contentFrame.origin.y = 0.0
            }
            
            hostingController.view.frame = contentFrame // 舞台归位，继续演
        }
    }
}
