//
//  CrownIndicatorViewController.swift
//  CrownControl
//
//  Created by Daniel Huri on 11/9/18.
//  Copyright © 2018 Daniel Huri. All rights reserved.
//

import UIKit
import QuickLayout

/** A crown indicator view controller */
class CrownIndicatorViewController: CrownViewController {

    // MARK: - Properties
    
    override var indicatorView: UIView {
        return pinIndicatorView
    }
    
    private lazy var pinIndicatorView: PinIndicatorView = {
        let pinIndicatorView = PinIndicatorView(anchorPoint: viewModel.crownAnchorPoint, edgeSize: attributes.sizes.foregroundDiameter, background: attributes.foregroundStyle)
        return pinIndicatorView
    }()
        
    // MARK: - Lifecycle
    
    override func loadView() {
        super.loadView()
        view.addSubview(pinIndicatorView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.async {
            self.peformForegroundTranslation()
        }
    }
    
    // MARK: - Feedback Generation

    override func generate(edgeFeedback: CrownAttributes.Feedback.Descripter) {
        super.generate(edgeFeedback: edgeFeedback)
        pinIndicatorView.flash(with: edgeFeedback.foregroundFlash)
    }
    
    // MARK: - Calculation Accessors
    
    override func peformForegroundTranslation() {
        pinIndicatorView.center = viewModel.calculateForegroundCenter(by: attributes.sizes.innerCircleEdgeSize * 0.5, angle: foregroundAngle)
    }
}
