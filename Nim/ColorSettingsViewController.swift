//
//  ColorSettingsViewController.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import UIKit

class ColorSettingsViewController: UIViewController, UIPopoverPresentationControllerDelegate, UIPointerInteractionDelegate {
    
    //MARK: Layout and Navigation
    
    //fit layout to constraints
    override func viewWillAppear(_ animated: Bool) {
        self.preferredContentSize = self.view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
    }

    @IBOutlet weak var widthConstraint: NSLayoutConstraint!
    // make button for dismissing visible if popover is shown on small screens
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    func presentationController(_ presentationController: UIPresentationController, willPresentWithAdaptiveStyle style: UIModalPresentationStyle, transitionCoordinator: UIViewControllerTransitionCoordinator?) {
        if(style != .formSheet){
            heightConstraint.constant = 0
        }
        else{
            heightConstraint.constant = 60
        }
        presentationController.presentedViewController.view.layoutSubviews()
    }

    // dismiss color settings view
    @IBAction func dismissView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    
    
    // MARK: Content
    
    var leftPlayerIsSelected = Bool(true)
    var leftPlayerColor : Color!
    var rightPlayerColor: Color!
        
    @IBOutlet weak var stackView: UIStackView!
    var listOfColorViews: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.presentationController?.delegate = self
        
        // create list of color views and add tapRecognizer
        for subStackView in stackView.subviews where subStackView is UIStackView{
            for subView in (subStackView as! UIStackView).arrangedSubviews{
                let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapColorView))
                subView.addGestureRecognizer(tapRecognizer)
                subView.layer.borderColor = UIColor.systemBackground.cgColor
                listOfColorViews.append(subView)
                subView.isAccessibilityElement = true
                subView.accessibilityLabel = listOfColorNames.first(where: {$0.0 == subView.tag})!.1
                subView.accessibilityHint = NSLocalizedString("doubleTap", comment: "double tap to select color")
            }
        }
        
        // detect, if left or right player is selected
        if(self.popoverPresentationController?.sourceView?.restorationIdentifier == "rightPlayerColorCircleButton"){
            leftPlayerIsSelected = false
        }

        // load current color
        leftPlayerColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "leftPlayerColor")!)
        rightPlayerColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "rightPlayerColor")!)
        let currentColor = leftPlayerIsSelected ? leftPlayerColor : rightPlayerColor
        
        // colorize all color views, and add border to selected one
        for colorView in listOfColorViews {
            colorView.backgroundColor = colorByPosition(postion: colorView.tag).value
            if(colorView.tag == currentColor?.position){
                colorView.layer.borderWidth = UIFontMetrics.default.scaledValue(for: 4)
            }
            
            if #available(iOS 13.4, *) {
                let pointerInteraction = UIPointerInteraction(delegate: self)
                colorView.addInteraction(pointerInteraction)
            }            
        }
        
        widthConstraint.constant = CGFloat(70)
        view.layoutIfNeeded()
    }
    
    
    @available(iOS 13.4, *)
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        if let interactionView = interaction.view {
            let targetedPreview = UITargetedPreview(view: interactionView)
            interactionView.superview!.bringSubviewToFront(interactionView)
            interactionView.superview!.superview!.bringSubviewToFront(interactionView.superview!)
            pointerStyle = UIPointerStyle(effect: UIPointerEffect.highlight(targetedPreview))
        }
        return pointerStyle
    }
    
    
    
    
    // MARK: Interaction
    
    // when view is tapped
    @objc func tapColorView(sender: UITapGestureRecognizer){
        if let tappedView = sender.view, let sourceViewController = (self.presentingViewController as? UINavigationController)?.viewControllers.first as? SettingsViewController{
            changeColor(tappedView: tappedView, sourceViewController: sourceViewController)
        }
    }
    
    // change color of tapped view and color circle
    func changeColor(tappedView: UIView, sourceViewController: SettingsViewController){

        let currentPlayerNewColor = colorByPosition(postion: tappedView.tag)
        let curretnPlayerOldColor = leftPlayerIsSelected ? leftPlayerColor : rightPlayerColor
        let otherPlayerOldColor = leftPlayerIsSelected ? rightPlayerColor : leftPlayerColor
        
        // remove all borders
        for subView in listOfColorViews{
            subView.layer.borderWidth = 0
        }

        // if other player has the same color, change it's color
        if(currentPlayerNewColor == otherPlayerOldColor){
            if leftPlayerIsSelected{
                rightPlayerColor = curretnPlayerOldColor
                UserDefaults.standard.set(curretnPlayerOldColor!.rawValue, forKey: "rightPlayerColor")
            }
            else{
                leftPlayerColor = curretnPlayerOldColor
                UserDefaults.standard.set(curretnPlayerOldColor!.rawValue, forKey: "leftPlayerColor")
            }
        }

        // add border to tapped view
        tappedView.layer.borderWidth = UIFontMetrics.default.scaledValue(for: 4)

        // save current color to UserDefaults
        if leftPlayerIsSelected{
            leftPlayerColor = currentPlayerNewColor
            UserDefaults.standard.set(currentPlayerNewColor.rawValue, forKey: "leftPlayerColor")
        }
        else{
            rightPlayerColor = currentPlayerNewColor
            UserDefaults.standard.set(currentPlayerNewColor.rawValue, forKey: "rightPlayerColor")
        }
        
        // update both circle colors
        sourceViewController.updateCircleColors()
    }
    
}
