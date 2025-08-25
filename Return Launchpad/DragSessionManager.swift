//
//  DragSessionManager.swift
//  Return Launchpad
//
//  Created by AI Assistant on 26.08.2025.
//

import Foundation
import SwiftUI

/// Manages cross-page drag and drop operations with automatic page navigation
class DragSessionManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isInCrossPageDrag: Bool = false
    @Published var autoScrollActive: Bool = false
    
    // MARK: - Session State
    private var dragStartPage: Int = 0
    private var globalSourceIndex: Int = 0
    private var autoScrollTimer: Timer?
    private var hoverStartTime: Date?
    
    // MARK: - Configuration
    private let hoverThreshold: TimeInterval = 1.5 // 1.5 seconds to trigger auto-scroll
    private let scrollInterval: TimeInterval = 0.8  // 0.8 seconds between page changes
    
    // MARK: - Callbacks
    var onPageChange: ((Int) -> Void)?
    var onDragComplete: ((Int, Int) -> Void)?
    
    init() {
        print("[DragSessionManager] Initialized")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Drag Session Management
    
    /// Starts a new cross-page drag session
    func startDragSession(sourceIndex: Int, currentPage: Int, itemsPerPage: Int) {
        print("🚀 [DragSessionManager] Starting drag session")
        print("   • Source local index: \(sourceIndex)")
        print("   • Current page: \(currentPage)")
        print("   • Items per page: \(itemsPerPage)")
        
        dragStartPage = currentPage
        globalSourceIndex = currentPage * itemsPerPage + sourceIndex
        isInCrossPageDrag = true
        
        print("   • Global source index: \(globalSourceIndex)")
        print("   • Drag start page: \(dragStartPage)")
    }
    
    /// Ends the current drag session
    func endDragSession() {
        print("🏁 [DragSessionManager] Ending drag session")
        cleanup()
        isInCrossPageDrag = false
    }
    
    /// Completes a drop operation with global index calculation
    func completeDrop(targetLocalIndex: Int, currentPage: Int, itemsPerPage: Int) {
        let globalTargetIndex = currentPage * itemsPerPage + targetLocalIndex
        
        print("🎯 [DragSessionManager] Completing drop")
        print("   • Target local index: \(targetLocalIndex)")
        print("   • Current page: \(currentPage)")
        print("   • Global target index: \(globalTargetIndex)")
        print("   • Global source index: \(globalSourceIndex)")
        
        onDragComplete?(globalSourceIndex, globalTargetIndex)
        endDragSession()
    }
    
    // MARK: - Auto-Scroll Navigation
    
    /// Handles hover over navigation arrow
    func handleArrowHover(direction: NavigationDirection, isHovering: Bool, currentPage: Int, maxPages: Int) {
        guard isInCrossPageDrag else { return }
        
        if isHovering {
            startHoverTimer(direction: direction, currentPage: currentPage, maxPages: maxPages)
        } else {
            stopAutoScroll()
        }
    }
    
    private func startHoverTimer(direction: NavigationDirection, currentPage: Int, maxPages: Int) {
        // Don't start if we can't navigate in this direction
        if (direction == .previous && currentPage <= 0) ||
           (direction == .next && currentPage >= maxPages - 1) {
            return
        }
        
        hoverStartTime = Date()
        
        // Start checking for threshold
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self,
                  let startTime = self.hoverStartTime,
                  self.isInCrossPageDrag else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= self.hoverThreshold {
                timer.invalidate()
                self.startAutoScroll(direction: direction)
            }
        }
    }
    
    private func startAutoScroll(direction: NavigationDirection) {
        print("⏩ [DragSessionManager] Starting auto-scroll \(direction)")
        
        autoScrollActive = true
        
        // Immediate first navigation
        triggerPageNavigation(direction: direction)
        
        // Continue with interval
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: scrollInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isInCrossPageDrag && self.autoScrollActive else {
                self?.stopAutoScroll()
                return
            }
            
            self.triggerPageNavigation(direction: direction)
        }
    }
    
    private func triggerPageNavigation(direction: NavigationDirection) {
        // Simply trigger the page change - the UI will handle bounds checking
        switch direction {
        case .previous:
            print("📄 [DragSessionManager] Triggering previous page")
        case .next:
            print("📄 [DragSessionManager] Triggering next page")
        }
        
        // Use a dummy page number - the actual navigation will be handled by the UI
        onPageChange?(-1) // Signal that we want to navigate, direction will be handled by UI
    }
    
    private func stopAutoScroll() {
        print("⏹ [DragSessionManager] Stopping auto-scroll")
        autoScrollActive = false
        hoverStartTime = nil
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    private func cleanup() {
        stopAutoScroll()
        globalSourceIndex = 0
        dragStartPage = 0
    }
    
    // MARK: - Public Properties
    
    var currentGlobalSourceIndex: Int {
        return globalSourceIndex
    }
    
    var startPage: Int {
        return dragStartPage
    }
}

// MARK: - Supporting Types

enum NavigationDirection {
    case previous
    case next
}