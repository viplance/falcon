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
    private var completion: ((CGRect?) -> Void)?
    private var initialRect: CGRect?
    
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
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Clear the selection area
        if selectionRect.width > 0 && selectionRect.height > 0 {
            NSColor.clear.setFill()
            var drawRect = selectionRect
            
            // Convert coordinate system (AppKit uses bottom-left origin)
            drawRect.origin.y = bounds.height - drawRect.origin.y - drawRect.height
            
            NSGraphicsContext.current?.saveGraphicsState()
            drawRect.fill(using: .copy)
            NSGraphicsContext.current?.restoreGraphicsState()
            
            // Draw selection border
            NSColor.systemBlue.setStroke()
            let borderPath = NSBezierPath(rect: drawRect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
            
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
        let instructions = isDragging ? "Release to capture" : "Drag to select area • ESC to cancel"
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
    
    override func mouseDown(with event: NSEvent) {
        let location = event.locationInWindow
        startPoint = location
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentPoint = event.locationInWindow
        
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
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        
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
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
