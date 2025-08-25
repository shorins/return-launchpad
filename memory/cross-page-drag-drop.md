# Cross-Page Drag and Drop Implementation

## Overview

This document describes the implementation of cross-page drag and drop functionality in Return Launchpad, allowing users to drag icons from one page to another through automatic page navigation triggered by hovering over navigation arrows.

## User Experience Flow

1. **Initiate Drag**: User starts dragging an icon on any page
2. **Cross-Page Intent**: User drags the icon over the left or right navigation arrow
3. **Hover Detection**: System detects hover over navigation arrow
4. **Auto-Scroll Trigger**: After 1.5 seconds of hovering, automatic page scrolling begins
5. **Immediate Visual Updates**: Pages change immediately without animation, showing target page content
6. **Continuous Navigation**: Pages continue to scroll every 0.8 seconds while hovering
7. **Visual Preservation**: Original dragged icon disappears from its source page, preventing duplication
8. **Drop Completion**: User drops the icon on the target page with proper global index calculation
9. **Array Reorganization**: Icons shift to accommodate the new position, with the last icon flowing to next page if needed

## Technical Architecture

### Core Components

#### 1. DragSessionManager
**Location**: `/Return Launchpad/DragSessionManager.swift`

Central coordinator for cross-page drag operations:
- Tracks drag session state
- Manages global index calculations
- Coordinates page transitions
- Handles drag completion

**Key Properties**:
```swift
@Published var isInCrossPageDrag: Bool = false
@Published var autoScrollActive: Bool = false
private var globalSourceIndex: Int = 0
private var dragStartPage: Int = 0
```

**Key Methods**:
- `startDragSession()`: Initializes cross-page drag with global index calculation
- `completeDrop()`: Finalizes drop with proper global index mapping
- `endDragSession()`: Cleans up session state

#### 2. CrossPageNavigationDelegate
**Location**: `/Return Launchpad/ContentView.swift`

Handles drag hover detection over navigation arrows:
- Detects drag entry/exit over arrow buttons
- Implements 1.5-second hover threshold
- Manages continuous auto-scroll at 0.8-second intervals
- Provides visual feedback during auto-scroll

**Key Behavior**:
```swift
func dropEntered(info: DropInfo) {
    // Wait 1.5 seconds, then start auto-scrolling
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        startAutoScroll()
    }
}
```

#### 3. Enhanced ContentView Integration
**Location**: `/Return Launchpad/ContentView.swift`

Updated navigation controls with drag support:
- Invisible hover zones over navigation arrows
- Visual indicators for active auto-scroll
- Integrated drag session management
- Cross-page drop handling

## Implementation Details

### Global Index Calculation

The system maintains consistent global indexing across pages with special handling for cross-page operations:

```swift
// When starting drag session (source page is preserved)
let globalSourceIndex = dragSessionManager.startPage * itemsPerPage + originalLocalIndex

// When completing drop on different page
let globalTargetIndex = currentPage * itemsPerPage + targetLocalIndex

// Final operation
appManager.moveApp(from: globalSourceIndex, to: globalTargetIndex)
```

### Immediate Visual Updates

During cross-page drag operations, the UI updates immediately to show the target page:

```swift
// Smart layout selection based on drag state
let shouldUseStableLayout = isInDragMode && 
                           !dragSessionManager.isInCrossPageDrag && 
                           currentPage == dragSessionManager.startPage

let displayApps = shouldUseStableLayout ? stablePageApps : pageApps
```

**Key Visual Behaviors**:
- **Source Page**: Shows stable layout during normal drag, live updates during cross-page
- **Target Pages**: Always show current page content immediately
- **Dragged Icon**: Hidden on non-source pages to prevent duplication
- **No Animation**: Page transitions are immediate during drag for responsiveness

### Page Navigation Logic

**Previous Page Navigation**:
- Target: End of previous page (`itemsPerPage - 1`)
- Boundary: Cannot go below page 0

**Next Page Navigation**:
- Target: Beginning of next page (index `0`)
- Boundary: Cannot exceed total page count

### Auto-Scroll Configuration

| Parameter | Value | Purpose |
|-----------|--------|---------|
| Hover Threshold | 1.5 seconds | Time before auto-scroll starts |
| Scroll Interval | 0.8 seconds | Time between page changes |
| Visual Feedback | Blue border | Indicates active auto-scroll |

## Code Structure

### File Organization
```
Return Launchpad/
├── DragSessionManager.swift          # Cross-page coordination
├── ContentView.swift                 # UI integration and delegates
└── memory/
    └── cross-page-drag-drop.md      # This documentation
```

### Key Integration Points

1. **Drag Initiation** (ContentView):
```swift
.onDrag {
    dragSessionManager.startDragSession(
        sourceIndex: appIndex,
        currentPage: currentPage,
        itemsPerPage: itemsPerPage
    )
    return NSItemProvider(...)
}
```

2. **Navigation Arrow Enhancement**:
```swift
.onDrop(of: [.text], delegate: CrossPageNavigationDelegate(
    direction: .next,
    dragSessionManager: dragSessionManager,
    currentPage: $currentPage,
    maxPages: pageCount,
    onPageChange: { newPage in
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = newPage
        }
    }
))
```

3. **Cross-Page Drop Completion**:
```swift
dragSessionManager.onDragComplete = { globalSource, globalTarget in
    appManager.moveApp(from: globalSource, to: globalTarget)
}
```

## Visual Feedback

### During Auto-Scroll
- Navigation control gains blue border (`Color.blue.opacity(0.8)`)
- Smooth animation transitions (`easeInOut(duration: 0.2)`)

### During Drag
- Dragged icon becomes semi-transparent
- Grid shows insertion points
- Navigation arrows become interactive

## Performance Considerations

### Timer Management
- Timers are properly invalidated when drag ends
- Auto-scroll stops when navigation boundaries are reached
- Memory cleanup prevents timer leaks

### Animation Optimization
- 0.3-second page transition animations
- Smooth spring animations for visual feedback
- Minimal layout recalculation during drag

## Error Handling

### Boundary Checking
```swift
// Prevent navigation beyond boundaries
let canNavigate = (direction == .previous && currentPage > 0) || 
                 (direction == .next && currentPage < maxPages - 1)
```

### Index Validation
```swift
// Ensure global indices are valid
if globalOriginalIndex < appManager.apps.count && 
   globalTargetIndex < appManager.apps.count {
    appManager.moveApp(from: globalOriginalIndex, to: globalTargetIndex)
}
```

### Session Cleanup
- Automatic cleanup on drag end
- Timer invalidation on view disappear
- Memory management through weak references

## Future Enhancements

### Potential Improvements
1. **Configurable Timing**: Allow users to adjust hover threshold and scroll interval
2. **Multi-Direction Support**: Support diagonal navigation for 2D grids
3. **Visual Breadcrumbs**: Show drag path across multiple pages
4. **Gesture Integration**: Support trackpad swipe gestures during drag
5. **Accessibility**: VoiceOver support for cross-page operations

### Performance Optimizations
1. **Lazy Loading**: Only render visible page content during auto-scroll
2. **Predictive Caching**: Pre-load adjacent pages during drag operations
3. **Hardware Acceleration**: Leverage Metal for smooth animations

## Testing Scenarios

### Manual Testing Checklist
- [ ] Drag icon from page 1 to page 2 via right arrow
- [ ] Drag icon from page 2 to page 1 via left arrow
- [ ] Verify 1.5-second hover threshold
- [ ] Test boundary conditions (first/last page)
- [ ] Confirm proper index calculation across pages
- [ ] Validate animation smoothness
- [ ] Check memory cleanup after drag completion

### Edge Cases
- [ ] Drag cancellation (releasing outside drop zones)
- [ ] Rapid page navigation during auto-scroll
- [ ] Multiple concurrent drag attempts
- [ ] App minimization during cross-page drag
- [ ] System sleep/wake during active drag session

## Debugging

### Debug Logging
The implementation includes comprehensive logging:
```
🚀 [DragSessionManager] Starting drag session
📄 [CrossPageNavigationDelegate] Navigating next: 1 → 2
🎯 [ContentView] Cross-page drag complete: 15 → 25
```

### Common Issues
1. **Incorrect Index Calculation**: Verify `itemsPerPage` consistency
2. **Timer Leaks**: Ensure proper cleanup in `deinit` methods
3. **Animation Conflicts**: Check for overlapping SwiftUI animations
4. **Memory Retention**: Use weak references in timer callbacks

## Migration Notes

This implementation is backward compatible with existing single-page drag and drop functionality. No data migration is required for user preferences or app ordering.