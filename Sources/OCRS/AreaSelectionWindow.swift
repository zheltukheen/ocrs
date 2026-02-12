import SwiftUI
import AppKit

/// Fullscreen window for click-drag area selection
/// Captures a region when user clicks, drags, and releases
class AreaSelectionWindow: NSWindow {

    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionView: AreaSelectionView?

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)

        // Configure window for fullscreen overlay
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func configure(onComplete: @escaping (CGRect) -> Void) {
        self.onSelectionComplete = onComplete

        // Create the selection view
        let view = AreaSelectionView(frame: self.frame)
        view.onSelectionComplete = { [weak self] rect in
            self?.onSelectionComplete?(rect)
        }
        view.onCancel = { [weak self] in
            self?.onCancel?()
        }

        self.contentView = view
        self.selectionView = view
    }
}

/// The actual view that handles mouse interaction and draws the selection rectangle
class AreaSelectionView: NSView {

    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var isDragging = false
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var hasSnapped = false  // Track if we've crossed the minimum threshold

    private let selectionColor = NSColor.systemCyan.withAlphaComponent(0.3)
    private let borderColor = NSColor.systemCyan
    private let borderWidth: CGFloat = 2.0
    private let cornerRadius: CGFloat = 6.0
    private let minimumSize: CGFloat = 20.0

    private var dimensionLabel: CATextLayer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        setupDimensionLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupDimensionLabel() {
        let label = CATextLayer()
        label.fontSize = 12
        label.foregroundColor = NSColor.white.cgColor
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        label.cornerRadius = 4
        label.alignmentMode = .center
        label.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        label.isHidden = true
        layer?.addSublayer(label)
        dimensionLabel = label
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        startPoint = location
        currentPoint = location
        isDragging = true
        hasSnapped = false
        setNeedsDisplay(bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = convert(event.locationInWindow, from: nil)

        let selectionRect = calculateSelectionRect()
        if !hasSnapped && selectionRect.width > minimumSize && selectionRect.height > minimumSize {
            hasSnapped = true
        }

        setNeedsDisplay(bounds)
        updateDimensionLabel()
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }

        isDragging = false
        currentPoint = convert(event.locationInWindow, from: nil)

        let selectionRect = calculateSelectionRect()
        if selectionRect.width > 10 && selectionRect.height > 10 {
            onSelectionComplete?(selectionRect)
        } else {
            onCancel?()
        }
    }

    private func calculateSelectionRect() -> CGRect {
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func updateDimensionLabel() {
        guard let label = dimensionLabel else { return }

        let rect = calculateSelectionRect()
        guard rect.width > 30 && rect.height > 20 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            label.isHidden = true
            CATransaction.commit()
            return
        }

        let text = "\(Int(rect.width)) × \(Int(rect.height))"

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        label.string = " \(text) "
        label.isHidden = false

        let textWidth = max(70, min(100, CGFloat(text.count) * 8))
        let labelSize = CGSize(width: textWidth, height: 18)

        var labelY = rect.minY - labelSize.height - 6
        if labelY < 20 {
            labelY = rect.maxY + 6
        }

        label.frame = CGRect(
            x: rect.midX - labelSize.width / 2,
            y: labelY,
            width: labelSize.width,
            height: labelSize.height
        )

        CATransaction.commit()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isDragging else { return }

        let selectionRect = calculateSelectionRect()
        guard selectionRect.width > 2 && selectionRect.height > 2 else { return }

        let path = NSBezierPath(roundedRect: selectionRect, xRadius: cornerRadius, yRadius: cornerRadius)
        selectionColor.setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()

        drawCornerHandles(in: selectionRect)
    }

    private func drawCornerHandles(in rect: CGRect) {
        let handleSize: CGFloat = 8
        let handleColor = NSColor.white

        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        for corner in corners {
            let handleRect = CGRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )

            let handlePath = NSBezierPath(ovalIn: handleRect)
            handleColor.setFill()
            handlePath.fill()
            borderColor.setStroke()
            handlePath.lineWidth = 1.5
            handlePath.stroke()
        }
    }
}
