//
//  CrownViewController.swift
//  CrownControl
//
//  Created by Daniel Huri on 11/11/18.
//  Copyright © 2018 Daniel Huri. All rights reserved.
//

import UIKit
import QuickLayout

/** A crown view controller component */
public class CrownViewController: UIViewController {

    // Delegate for the crown spin events
    private weak var delegate: CrownDelegate!
        
    private var lockPanGesture = false
    
    var indicatorView: UIView {
        preconditionFailure("\(#function) be overridden by subclass")
    }
    
    private let contentView = UIView()

    // Gesture Recognizers
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var singleTapGestureRecognizer: UITapGestureRecognizer!
    private var doubleTapGestureRecognizer: UITapGestureRecognizer!
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!

    // Size constraints
    private var horizontalConstraint: NSLayoutConstraint!
    private var verticalConstraint: NSLayoutConstraint!
    
    private var originalHorizontalOffset: CGFloat = 0
    private var originalVerticalOffset: CGFloat = 0
    
    var currentForegroundAngle: CGFloat {
        return viewModel.currentForegroundAngle
    }
                
    // The crown attributes descriptor
    let attributes: CrownAttributes
    let viewModel: CrownAttributesViewModel
    
    // MARK: UI Elements
    
    private lazy var backgroundView: BackgroundView = {
        let backgroundView = BackgroundView(background: attributes.backgroundStyle)
        contentView.addSubview(backgroundView)
        backgroundView.fillSuperview()
        return backgroundView
    }()
    
    // MARK: - Lifecycle
    
    public init(with attributes: CrownAttributes, delegate: CrownDelegate? = nil) {
        self.attributes = attributes
        self.delegate = delegate
        viewModel = CrownAttributesViewModel(using: attributes)
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        view = viewModel.view
        view.frame = CGRect(origin: .zero, size: attributes.sizes.backgroundSurfaceSquareSize)
        view.addSubview(contentView)
        view.isExclusiveTouch = true
        
        contentView.set(.width, .height, of: attributes.sizes.backgroundSurfaceDiameter)
        contentView.layoutToSuperview(.left, .right, .top, .bottom)
        contentView.addSubview(backgroundView)
        
        setupUserInteraction()
        
        view.transform = attributes.crownTransform
        
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // MARK: - Setup
    
    private func setupUserInteraction() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGestureRecognized))
        panGestureRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(panGestureRecognizer)

        if attributes.userInteraction.doubleTap.isInteractable {
            doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestureRecognized))
            doubleTapGestureRecognizer.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTapGestureRecognizer)
        }
        
        if attributes.userInteraction.singleTap.isInteractable {
            singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(singleTapGestureRecognized))
            singleTapGestureRecognizer.numberOfTapsRequired = 1
            if let doubleTapGestureRecognizer = doubleTapGestureRecognizer {
                singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
            }
            view.addGestureRecognizer(singleTapGestureRecognizer)
        }
        
        if !viewModel.isForceTouchAvailable && attributes.userInteraction.repositionGesture.isLongPress {
            longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureRecognized))
            longPressGestureRecognizer.minimumPressDuration = attributes.userInteraction.repositionGesture.longPressDuration
            view.addGestureRecognizer(longPressGestureRecognizer)
        }
    }
    
    // MARK: - Orientation
    
    // Normalize the position of the crown surface after device orientation change
    @objc private func deviceOrientationDidChange() {
        spin(to: viewModel.progress)
        
        let superviewBounds = viewModel.superviewBounds
        
        if view.minX < superviewBounds.minX {
            horizontalConstraint.constant = originalHorizontalOffset
        } else if view.maxX > superviewBounds.maxX {
            horizontalConstraint.constant = originalHorizontalOffset
        }

        if view.minY < superviewBounds.minY {
            verticalConstraint.constant = originalVerticalOffset
        } else if view.maxY > superviewBounds.maxY {
            verticalConstraint.constant = originalVerticalOffset
        }
    }
    
    // MARK: - User Interaction
    
    @objc private func panGestureRecognized(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch (viewModel.panSubject, attributes.userInteraction.repositionGesture.isForceTouch) {
        case (.indicator, _):
            panIndicator(using: gestureRecognizer)
        case (.crown, true):
            panCrownSurface(using: gestureRecognizer)
        default:
            break
        }
    }
    
    @objc private func doubleTapGestureRecognized(_ gestureRecognizer: UITapGestureRecognizer) {
        viewModel.performTapActionIfNeeded(attributes.userInteraction.doubleTap)
    }
    
    @objc private func singleTapGestureRecognized(_ gestureRecognizer: UITapGestureRecognizer) {
        viewModel.performTapActionIfNeeded(attributes.userInteraction.singleTap)
    }
    
    @objc private func longPressGestureRecognized(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let superview = view.superview else {
            return
        }
        let location = gestureRecognizer.location(in: superview)
        viewModel.longPress(with: gestureRecognizer.state, location: location)
    }
    
    private func panCrownSurface(using gestureRecognizer: UIPanGestureRecognizer) {
        guard let superview = view.superview else {
            return
        }
        let state = gestureRecognizer.state
        switch state {
        case .began:
            break
        case .changed:
            defer {
                gestureRecognizer.setTranslation(.zero, in: superview)
            }
            
            let translation = gestureRecognizer.translation(in: superview)
            let velocity = gestureRecognizer.velocity(in: superview)
            
            if viewModel.isCrownWithinHorizontalBounds(after: translation.x, velocity: velocity.x) {
                horizontalConstraint.constant += translation.x
            }
            
            if viewModel.isCrownWithinVerticalBounds(after: translation.y, velocity: velocity.y) {
                verticalConstraint.constant += translation.y
            }
            
        case .cancelled, .ended, .failed:
            break
        case .possible:
            break
        }
    }
    
    private func panIndicator(using gestureRecognizer: UIPanGestureRecognizer) {
        guard let superview = view.superview else {
            return
        }
        let state = gestureRecognizer.state
        switch state {
        case .began:
            delegate?.crownDidBeginSpinning(self)
        case .changed:
            let translation = gestureRecognizer.translation(in: superview)
            defer {
                gestureRecognizer.setTranslation(.zero, in: superview)
            }
            
            guard viewModel.isAbleToSpin else {
                return
            }
            
            lockPanGesture = true
            
            // Update current angle
            viewModel.currentForegroundAngle = viewModel.angle(of: indicatorView, by: indicatorView.center + translation)
            
            // Inform delegate pre update
            delegate?.crown(self, willUpdate: viewModel.progress)
            
            // Make the translation
            translate()
            
            // Update progress
            viewModel.progress = (currentForegroundAngle - attributes.anchorPosition.radians) / attributes.sizes.maximumAngleInRadian
            
            // Update scroll view offset by progress
            viewModel.updateScrollViewOffset()
            
            // Update delegate after the progress update
            delegate?.crown(self, didUpdate: viewModel.progress)
            
            // Generate haptic feedback
            generateEdgeFeedbackIfNecessary()
            
            // Update previous angle
            viewModel.previousForegroundAngle = viewModel.currentForegroundAngle
            
            lockPanGesture = false
            
        case .cancelled, .ended, .failed:
            delegate?.crownDidEndSpinning(self)
        case .possible:
            break
        }
    }
    
    // MARK: - Feedback Generation
    
    private func generateEdgeFeedbackIfNecessary() {
        if viewModel.hasForegroundReachedLeadingEdge {
            generate(edgeFeedback: attributes.feedback.leading)
        } else if viewModel.hasForegroundReachedTrailingEdge {
            generate(edgeFeedback: attributes.feedback.trailing)
        }
    }
    
    func generate(edgeFeedback: CrownAttributes.Feedback.Descripter) {
        HapticFeedbackGenerator.generate(impact: edgeFeedback.impactHaptic)
        backgroundView.flash(with: edgeFeedback.backgroundFlash)
    }
    
    func translate() {
        preconditionFailure("Must be implemented by subclass")
    }
  
    // MARK: - UIResponder
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            viewModel.force(force: touch.force, max: touch.maximumPossibleForce)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            viewModel.force(force: 0, max: touch.maximumPossibleForce)
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            viewModel.force(force: 0, max: touch.maximumPossibleForce)
        }
    }
    
    /**
     Layout the crown horizontally in relation to another given view.
     - parameter edge: Crown edge.
     - parameter otherEdge: Other view edge.
     - parameter otherView: The other view to which the crown clings horizontally.
     - parameter offset: The horizontal offset from the edge.
     */
    private func layoutHorizontally(_ edge: NSLayoutConstraint.Attribute, to otherEdge: NSLayoutConstraint.Attribute, of otherView: UIView, offset: CGFloat = 0) {
        originalHorizontalOffset = offset
        horizontalConstraint = view.layout(edge, to: otherEdge, of: otherView, offset: offset, priority: .must)
    }
    
    /**
     Layout the crown vertically in relation to another given view.
     - parameter edge: Crown edge.
     - parameter otherEdge: Other view edge.
     - parameter otherView: The other view to which the crown clings vertically.
     - parameter offset: The vertical offset from the edge.
     */
    private func layoutVertically(_ edge: NSLayoutConstraint.Attribute, to otherEdge: NSLayoutConstraint.Attribute, of otherView: UIView, offset: CGFloat = 0) {
        originalVerticalOffset = offset
        verticalConstraint = view.layout(edge, to: otherEdge, of: otherView, offset: offset, priority: .must)
    }
    
    // MARK: - Exposed
    
    /**
     Add the crown view controller as a child of a parent view controller and layout it vertically and horizontally.
     - parameter parent: A parent view controller.
     - parameter horizontalConstaint: Horizontal constraint construct.
     - parameter verticalConstraint: Vertical constraint construct.
     */
    public func layout(in parent: UIViewController, horizontalConstaint: CrownAttributes.AxisConstraint, verticalConstraint: CrownAttributes.AxisConstraint) {
        parent.addChild(self)
        parent.view.addSubview(view)
        layoutHorizontally(horizontalConstaint.crownEdge, to: horizontalConstaint.anchorViewEdge, of: horizontalConstaint.anchorView, offset: horizontalConstaint.offset)
        layoutVertically(verticalConstraint.crownEdge, to: verticalConstraint.anchorViewEdge, of: verticalConstraint.anchorView, offset: verticalConstraint.offset)
    }
    
    /**
     Spins the crown's foreground to a given progress in the range of [0...1].
     - parameter progress: The progress of the spin from 0 to 1. Reflects the offset in the bound scroll view.
     */
    public func spin(to progress: CGFloat) {
        guard !lockPanGesture else {
            return
        }
        viewModel.currentForegroundAngle = progress * attributes.sizes.maximumAngleInRadian + attributes.anchorPosition.radians
        viewModel.progress = progress
        translate()
        viewModel.previousForegroundAngle = viewModel.currentForegroundAngle
    }
}
