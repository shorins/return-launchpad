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
    private var currentDirection: NavigationDirection?
    private var currentMaxPages: Int = 0
    
    // MARK: - Configuration
    private let hoverThreshold: TimeInterval = 1.5 // 1.5 seconds to trigger auto-scroll
    private let scrollInterval: TimeInterval = 1.5  // 1.5 seconds between page changes
    
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
            // Store current context
            currentDirection = direction
            currentMaxPages = maxPages
            startHoverTimer(direction: direction, currentPage: currentPage, maxPages: maxPages)
        } else {
            // Clear context and stop auto-scroll
            currentDirection = nil
            currentMaxPages = 0
            stopAutoScroll()
        }
    }
    
    private func startHoverTimer(direction: NavigationDirection, currentPage: Int, maxPages: Int) {
        // Don't start if we can't navigate in this direction
        if (direction == .previous && currentPage <= 0) ||
           (direction == .next && currentPage >= maxPages - 1) {
            print("⚠️ [DragSessionManager] Cannot navigate \(direction) from page \(currentPage)")
            return
        }
        
        // Stop any existing hover timer to prevent conflicts
        if hoverStartTime != nil {
            print("🔄 [DragSessionManager] Resetting hover timer for \(direction)")
            stopAutoScroll()
        }
        
        hoverStartTime = Date()
        print("⏰ [DragSessionManager] Starting hover timer for \(direction)")
        
        // Start checking for threshold
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self,
                  let startTime = self.hoverStartTime,
                  self.isInCrossPageDrag else {
                print("❌ [DragSessionManager] Timer invalidated - session ended")
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= self.hoverThreshold {
                print("✅ [DragSessionManager] Hover threshold reached, starting auto-scroll")
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
        guard let onPageChange = onPageChange else {
            print("⚠️ [DragSessionManager] No page change callback available")
            return
        }
        
        // Signal navigation direction to UI - let UI handle the actual page bounds
        switch direction {
        case .previous:
            print("📄 [DragSessionManager] Triggering previous page")
            onPageChange(-2)  // Special signal for "go previous"
        case .next:
            print("📄 [DragSessionManager] Triggering next page")
            onPageChange(-3)  // Special signal for "go next"
        }
    }
    
    private func stopAutoScroll() {
        print("⏹ [DragSessionManager] Stopping auto-scroll")
        
        // Complete cleanup
        autoScrollActive = false
        hoverStartTime = nil
        currentDirection = nil
        
        // Invalidate timer
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        
        print("✅ [DragSessionManager] Auto-scroll stopped and cleaned up")
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