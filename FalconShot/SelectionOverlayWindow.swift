//
//  SelectionOverlayWindow.swift
//  FalconShot
//
//  Created by Dzmitry Sharko on 17.03.2026.
//

import Cocoa
import SwiftUI

class SelectionOverlayWindow: NSWindow {
    private var selectionView: SelectionView?
    private var completion: ((CGRect?) -> Void)?
    
    init(initialRect: CGRect?, completion: @escaping (CGRect?) -> Void) {
        // Get the screen frame
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            self.completion = completion
            return
        }
        
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.completion = completion
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        
        let view = SelectionView(
            frame: screen.frame,
            initialRect: initialRect
        ) { [weak self] rect in
            self?.finishSelection(with: rect)
        }
        
        self.selectionView = view
        self.contentView = view
        self.makeFirstResponder(view)
    }
    
    private func finishSelection(with rect: CGRect?) {
        let completionCopy = self.completion
        self.completion = nil
        self.selectionView = nil
        self.contentView = nil
        self.close()
        completionCopy?(rect)
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

class SelectionView: NSView {
    private var selectionRect: CGRect = .zero
    private var startPoint: CGPoint = .zero
    private var isDragging: Bool = false
    private var isResizing: Bool = false
    private var isMoving: Bool = false
    private var resizeEdge: ResizeEdge = .none
    private var dragOffset: CGPoint = .zero
    private var completion: ((CGRect?) -> Void)?
    private var initialRect: CGRect?
    private let handleSize: CGFloat = 10
    
    enum ResizeEdge {
        case none, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
    }
    
    init(frame: NSRect, initialRect: CGRect?, completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        self.initialRect = initialRect
        super.init(frame: frame)
        
        if let rect = initialRect {
            selectionRect = rect
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func convertToDrawCoordinates(_ rect: CGRect) -> CGRect {
        var drawRect = rect
        drawRect.origin.y = bounds.height - drawRect.origin.y - drawRect.height
        return drawRect
    }
    
    private func getResizeEdge(at point: CGPoint) -> ResizeEdge {
        guard selectionRect.width > 0 && selectionRect.height > 0 else { return .none }
        
        let drawRect = convertToDrawCoordinates(selectionRect)
        let handleRect = { (x: CGFloat, y: CGFloat) -> CGRect in
            CGRect(x: x - self.handleSize/2, y: y - self.handleSize/2, width: self.handleSize, height: self.handleSize)
        }
        
        // Check corners first (priority)
        if handleRect(drawRect.minX, drawRect.minY).contains(point) { return .topLeft }
        if handleRect(drawRect.maxX, drawRect.minY).contains(point) { return .topRight }
        if handleRect(drawRect.minX, drawRect.maxY).contains(point) { return .bottomLeft }
        if handleRect(drawRect.maxX, drawRect.maxY).contains(point) { return .bottomRight }
        
        // Check edges
        let edgeThreshold: CGFloat = 8
        if abs(point.x - drawRect.minX) < edgeThreshold && point.y >= drawRect.minY && point.y <= drawRect.maxY {
            return .left
        }
        if abs(point.x - drawRect.maxX) < edgeThreshold && point.y >= drawRect.minY && point.y <= drawRect.maxY {
            return .right
        }
        if abs(point.y - drawRect.minY) < edgeThreshold && point.x >= drawRect.minX && point.x <= drawRect.maxX {
            return .top
        }
        if abs(point.y - drawRect.maxY) < edgeThreshold && point.x >= drawRect.minX && point.x <= drawRect.maxX {
            return .bottom
        }
        
        // Check if inside rectangle (for moving)
        if drawRect.contains(point) {
            return .none // Inside, but not on edge - can move
        }
        
        return .none
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .cursorUpdate]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        guard initialRect != nil else { return }
        
        let location = event.locationInWindow
        let edge = getResizeEdge(at: location)
        
        // Update cursor based on location
        switch edge {
        case .topLeft, .bottomRight, .topRight, .bottomLeft:
            NSCursor.crosshair.set() // Could use diagonal resize cursors if available
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .none:
            let drawRect = convertToDrawCoordinates(selectionRect)
            if selectionRect.width > 0 && drawRect.contains(location) {
                NSCursor.openHand.set()
            } else {
                NSCursor.crosshair.set()
            }
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Clear the selection area
        if selectionRect.width > 0 && selectionRect.height > 0 {
            // Use a nearly-transparent color to ensure mouse events are captured
            // In AppKit, 100% clear areas in a transparent window can pass through clicks to windows below
            NSColor(white: 1.0, alpha: 0.001).setFill()
            let drawRect = convertToDrawCoordinates(selectionRect)
            
            NSGraphicsContext.current?.saveGraphicsState()
            drawRect.fill(using: .copy)
            NSGraphicsContext.current?.restoreGraphicsState()
            
            // Draw selection border
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: drawRect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
            
            // Draw resize handles if in edit mode
            if initialRect != nil {
                drawResizeHandles(in: drawRect)
            }
            
            // Draw dimensions label
            let dimensions = String(format: "%.0f × %.0f", selectionRect.width, selectionRect.height)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.white
            ]
            let textSize = dimensions.size(withAttributes: attributes)
            let textRect = CGRect(
                x: drawRect.maxX - textSize.width - 8,
                y: drawRect.minY - textSize.height - 8,
                width: textSize.width + 4,
                height: textSize.height + 4
            )
            
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
            
            dimensions.draw(
                at: CGPoint(x: textRect.minX + 2, y: textRect.minY + 2),
                withAttributes: attributes
            )
        }
        
        // Draw instructions
        let instructions: String
        if isMoving {
            instructions = "Drag to move • Release and adjust"
        } else if isResizing {
            instructions = "Drag to resize • Release and adjust"
        } else if isDragging {
            instructions = "Release to finish selection"
        } else if initialRect != nil {
            instructions = "Drag to move/resize • Enter to capture • ESC to cancel"
        } else {
            instructions = "Drag to select area • Release to capture • ESC to cancel"
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ]
        let textSize = instructions.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: bounds.height - 50,
            width: textSize.width + 16,
            height: textSize.height + 8
        )
        
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        
        instructions.draw(
            at: CGPoint(x: textRect.minX + 8, y: textRect.minY + 4),
            withAttributes: attributes
        )
    }
    
    private func drawResizeHandles(in rect: CGRect) {
        let handleSize: CGFloat = 8
        NSColor.systemBlue.setFill()
        NSColor.white.setStroke()
        
        let handles = [
            CGPoint(x: rect.minX, y: rect.minY),     // Top-left
            CGPoint(x: rect.maxX, y: rect.minY),     // Top-right
            CGPoint(x: rect.minX, y: rect.maxY),     // Bottom-left
            CGPoint(x: rect.maxX, y: rect.maxY),     // Bottom-right
            CGPoint(x: rect.midX, y: rect.minY),     // Top
            CGPoint(x: rect.midX, y: rect.maxY),     // Bottom
            CGPoint(x: rect.minX, y: rect.midY),     // Left
            CGPoint(x: rect.maxX, y: rect.midY),     // Right
        ]
        
        for handle in handles {
            let handleRect = CGRect(
                x: handle.x - handleSize/2,
                y: handle.y - handleSize/2,
                width: handleSize,
                height: handleSize
            )
            let path = NSBezierPath(ovalIn: handleRect)
            path.fill()
            path.lineWidth = 1
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        startPoint = location
        
        if initialRect != nil && selectionRect.width > 0 {
            // Edit mode - check if clicking on edge/corner or inside
            resizeEdge = getResizeEdge(at: location)
            let drawRect = convertToDrawCoordinates(selectionRect)
            
            if resizeEdge != .none {
                isResizing = true
                isDragging = false
                isMoving = false
            } else if drawRect.contains(location) {
                // Clicking inside - move the whole rectangle
                isMoving = true
                isDragging = false
                isResizing = false
                dragOffset = CGPoint(
                    x: location.x - drawRect.minX,
                    y: location.y - drawRect.minY
                )
                NSCursor.closedHand.set()
            } else {
                // Clicking outside - create new selection
                isDragging = true
                isResizing = false
                isMoving = false
                selectionRect = .zero
            }
        } else {
            // Dynamic mode - always create new selection
            isDragging = true
            isResizing = false
            isMoving = false
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = event.locationInWindow
        
        if isMoving {
            // Move the entire rectangle
            let newX = currentPoint.x - dragOffset.x
            let newY = currentPoint.y - dragOffset.y
            
            // Convert from draw coordinates to selection coordinates
            selectionRect.origin.x = newX
            selectionRect.origin.y = bounds.height - newY - selectionRect.height
            
        } else if isResizing {
            // Resize based on edge
            let drawRect = convertToDrawCoordinates(selectionRect)
            var newRect = selectionRect
            
            let deltaX = currentPoint.x - startPoint.x
            let deltaY = currentPoint.y - startPoint.y
            
            switch resizeEdge {
            case .left:
                // Moving left edge
                newRect.origin.x = drawRect.minX + deltaX
                newRect.size.width = drawRect.width - deltaX
                
            case .right:
                // Moving right edge
                newRect.size.width = drawRect.width + deltaX
                
            case .top:
                // Moving top edge (remember: AppKit Y is inverted)
                let newTopY = drawRect.minY + deltaY
                newRect.origin.y = bounds.height - newTopY - drawRect.height + deltaY
                newRect.size.height = drawRect.height - deltaY
                
            case .bottom:
                // Moving bottom edge
                let newBottomY = drawRect.maxY + deltaY
                newRect.origin.y = bounds.height - newBottomY
                newRect.size.height = drawRect.height + deltaY
                
            case .topLeft:
                // Top-left corner
                newRect.origin.x = drawRect.minX + deltaX
                newRect.size.width = drawRect.width - deltaX
                let newTopY = drawRect.minY + deltaY
                newRect.origin.y = bounds.height - newTopY - drawRect.height + deltaY
                newRect.size.height = drawRect.height - deltaY
                
            case .topRight:
                // Top-right corner
                newRect.size.width = drawRect.width + deltaX
                let newTopY = drawRect.minY + deltaY
                newRect.origin.y = bounds.height - newTopY - drawRect.height + deltaY
                newRect.size.height = drawRect.height - deltaY
                
            case .bottomLeft:
                // Bottom-left corner
                newRect.origin.x = drawRect.minX + deltaX
                newRect.size.width = drawRect.width - deltaX
                let newBottomY = drawRect.maxY + deltaY
                newRect.origin.y = bounds.height - newBottomY
                newRect.size.height = drawRect.height + deltaY
                
            case .bottomRight:
                // Bottom-right corner
                newRect.size.width = drawRect.width + deltaX
                let newBottomY = drawRect.maxY + deltaY
                newRect.origin.y = bounds.height - newBottomY
                newRect.size.height = drawRect.height + deltaY
                
            default:
                break
            }
            
            // Ensure minimum size
            if newRect.width > 20 && newRect.height > 20 {
                selectionRect = newRect
                startPoint = currentPoint
            }
            
        } else if isDragging {
            // Create new selection
            let x = min(startPoint.x, currentPoint.x)
            let y = min(startPoint.y, currentPoint.y)
            let width = abs(currentPoint.x - startPoint.x)
            let height = abs(currentPoint.y - startPoint.y)
            
            // Store in screen coordinates (top-left origin)
            selectionRect = CGRect(
                x: x,
                y: bounds.height - y - height,
                width: width,
                height: height
            )
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        isResizing = false
        isMoving = false
        NSCursor.crosshair.set()
        
        // In edit mode, don't auto-capture on mouse up
        // User must press Enter to capture
        if initialRect != nil {
            needsDisplay = true
            return
        }
        
        // In dynamic mode, auto-capture after selection
        let completionCopy = self.completion
        self.completion = nil // Prevent double-calls
        
        if selectionRect.width > 10 && selectionRect.height > 10 {
            completionCopy?(selectionRect)
        } else {
            completionCopy?(nil)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            let completionCopy = self.completion
            self.completion = nil
            completionCopy?(nil)
        } else if event.keyCode == 36 || event.keyCode == 76 { // Enter or Return key
            let completionCopy = self.completion
            self.completion = nil
            
            if selectionRect.width > 10 && selectionRect.height > 10 {
                completionCopy?(selectionRect)
            } else {
                completionCopy?(nil)
            }
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
