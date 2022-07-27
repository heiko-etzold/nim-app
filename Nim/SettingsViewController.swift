//
//  SettingsViewController.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import UIKit
import NotificationCenter
import Combine


class SettingsViewController: UIViewController, UIDocumentPickerDelegate, UITextFieldDelegate {
    
    //hide status bar
    override var prefersStatusBarHidden: Bool{
        return true
    }
    
    
    // MARK: Content

    var maximumNumberOfCounters = Int(0)
    var numberOfFields = Int(0)
    var winMode : WinMode!
    
    var numberModeSettingSubscribber: AnyCancellable?
    var numberModeIsEditableSettingSubscribber: AnyCancellable?

    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var gameContainerView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // set UserDefaults if not existing
        if(UserDefaults.standard.object(forKey: "archive") != nil){
            loadArchive()
        }
        if(UserDefaults.standard.integer(forKey: "numberOfTiles") == 0){
            UserDefaults.standard.set(10, forKey: "numberOfTiles")
        }
        if(UserDefaults.standard.integer(forKey: "numberOfMaximalCircles") == 0){
            UserDefaults.standard.set(2, forKey: "numberOfMaximalCircles")
        }
        if(UserDefaults.standard.string(forKey: "winMode") == nil){
            UserDefaults.standard.set(WinMode.lastWins.rawValue, forKey: "winMode")
        }
        if(UserDefaults.standard.string(forKey: "leftPlayerColor") == nil){
            UserDefaults.standard.set(Color.red.rawValue, forKey: "leftPlayerColor")
        }
        if(UserDefaults.standard.string(forKey: "rightPlayerColor") == nil){
            UserDefaults.standard.set(Color.blue.rawValue, forKey: "rightPlayerColor")
        }

        // write local variables from UserDefaults
        numberOfFields = UserDefaults.standard.integer(forKey: "numberOfTiles")
        maximumNumberOfCounters = UserDefaults.standard.integer(forKey: "numberOfMaximalCircles")
        winMode = WinMode.init(rawValue: UserDefaults.standard.string(forKey: "winMode")!)
        
        // update visible views by local variables
        numberOfFieldsStepper.value = Double(numberOfFields)
        numberOfFieldsLabel.text = "\(numberOfFields)"
        maximumNumberOfCountersStepper.value = Double(maximumNumberOfCounters)
        maximumNumberOfCountersLabel.text = "\(maximumNumberOfCounters)"
        winModeSegmentControl.selectedSegmentIndex = (winMode == .lastWins) ? 1 : 0

        if(UserDefaults.standard.string(forKey: "firstPlayerName") != nil && UserDefaults.standard.string(forKey: "firstPlayerName") != ""){
            leftPlayerTextField.text = UserDefaults.standard.string(forKey: "firstPlayerName")!
        }
        if(UserDefaults.standard.string(forKey: "secondPlayerName") != nil && UserDefaults.standard.string(forKey: "secondPlayerName") != ""){
            rightPlayerTextField.text = UserDefaults.standard.string(forKey: "secondPlayerName")!
        }
        
        // draw field with tiles
        drawField()
        
        // update circle Colors
        updateCircleColors()
        
        // add pointer support
        if #available(iOS 13.4, *) {
            leftPlayerColorButton.pointerStyleProvider = { button, effect, shape in
                let preview = UITargetedPreview(view: button.superview!)
                return UIPointerStyle(effect: .highlight(preview))
            }
            rightPlayerColorButton.pointerStyleProvider = { button, effect, shape in
                let preview = UITargetedPreview(view: button.superview!)
                return UIPointerStyle(effect: .highlight(preview))
            }
        }

        // add keyboard gestures
        leftPlayerTextField.delegate = self
        rightPlayerTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        // change settings on Mac
        numberModeSettingSubscribber = UserDefaults.standard
                .publisher(for: \.settings_numberMode)
                .sink(receiveValue: {_ in renewNumbersInViews(currentNavigationController: self.navigationController!)})
        
        numberModeIsEditableSettingSubscribber = UserDefaults.standard
                .publisher(for: \.settings_numberModeIsEditable)
                .sink(receiveValue: {_ in renewNumbersInViews(currentNavigationController: self.navigationController!)})

        // add accessibility labels
        leftPlayerColorButton.accessibilityLabel = NSLocalizedString("selectLeftColor", comment: "select left color")
        rightPlayerColorButton.accessibilityLabel = NSLocalizedString("selectRightColor", comment: "select right color")
        
        leftPlayerTextField.accessibilityLabel = NSLocalizedString("insertLeftName", comment: "insert name of left player")
        rightPlayerTextField.accessibilityLabel = NSLocalizedString("insertRightName", comment: "insert name of right player")
        
        numberModeSegmentControl.imageForSegment(at: 0)?.accessibilityLabel = NSLocalizedString("noNumber", comment: "no numbering")
        numberModeSegmentControl.imageForSegment(at: 1)?.accessibilityLabel = NSLocalizedString("fifthNumber", comment: "number every fifth field")
        numberModeSegmentControl.imageForSegment(at: 2)?.accessibilityLabel = NSLocalizedString("allNumber", comment: "number all fields")
        
        winModeSegmentControl.imageForSegment(at: 0)?.accessibilityLabel = NSLocalizedString("changeLose", comment: "activate last field loses")
        winModeSegmentControl.imageForSegment(at: 1)?.accessibilityLabel = NSLocalizedString("changeWin", comment: "activate last field wins")
        
        maximumNumberOfCountersStepper.accessibilityValue = "Hallo"
        
        // renew sizes
        stackView.setCustomSpacing(0, after: stackView.subviews[0])
        stackView.setCustomSpacing(10, after: stackView.subviews[2])
        stackView.setCustomSpacing(0, after: stackView.subviews[4])
        changeSizes()
    }

    // renew numbers
    override func viewWillAppear(_ animated: Bool) {
        //change number mode segment control
        numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
        renewNumbersInViews(currentNavigationController: self.navigationController!)
    }

    override func viewDidAppear(_ animated: Bool) {
        changeSizes()
    }
    func drawField(){
        
        // remove all tiles
        for sub in gameContainerView.subviews{
            sub.removeFromSuperview()
        }
        // create new tiles
        let exampleTileBar = createTileBar(gameFieldView: gameContainerView, numberOfTiles: 20, align: .center)
        for tileView in exampleTileBar{
            tileView.winMode = winMode
            tileView.thumbMode = .information
            tileView.changeThumbImage()
            tileView.changeThumbColor()
        }
        
        // draw number of maximal circles
        for i in 0 ..< maximumNumberOfCounters{
            drawCircle(tileView: exampleTileBar[i], contentColor: .none)
        }
        
        adjustCurrentNumberOfField()

        changeVisibilityOfTiles(tileBar: exampleTileBar)
        renewAllLabels()
    }
    
    override func viewWillLayoutSubviews() {
        if let listOfLabels = gameContainerView.subviews.filter({$0 is TileLabel}) as? [TileLabel]{
            for tileLabel in listOfLabels{
                if (tileLabel.index <= numberOfFields){
                    tileLabel.alpha = 1
                    tileLabel.layoutSubviews()
                }
                else{
                    tileLabel.alpha = 0
                }
            }
        }
    }
    
    func changeVisibilityOfTiles(tileBar: [TileView]){
        for tileView in tileBar{
            if(tileView.index <= numberOfFields){
                tileView.alpha = 1
                if(tileView.index == numberOfFields){
                    tileView.thumb.alpha = 1
                }
                else{
                    tileView.thumb.alpha = 0
                }
            }
            else{
                tileView.alpha = 0
            }
        }
    }
    
    func adjustCurrentNumberOfField(){
        
        if let barView = gameContainerView.subviews.first(where: {$0.restorationIdentifier == "barView"}){
            if let exampleTileBar = barView.subviews.filter({$0 is TileView}) as? [TileView]{
                if let lastConstraint =  barView.constraints.first(where: {$0.identifier == "lastConstraint"}){
                    barView.removeConstraint(lastConstraint)
                    let newLastConstraint = NSLayoutConstraint(item: exampleTileBar[numberOfFields-1], attribute: .trailing, relatedBy: .equal, toItem: barView, attribute: .trailing, multiplier: 1, constant: 0)
                    newLastConstraint.identifier = "lastConstraint"
                    newLastConstraint.isActive = true
                }
            }
        }
    }
    
    func renewAllLabels(){
        numberOfFieldsLabel.text = "\(numberOfFields) \(NSLocalizedString("fields", comment: "fields"))"
        switch maximumNumberOfCounters{
        case 1:
            maximumNumberOfCountersLabel.text = NSLocalizedString("oneTile", comment: "1 tile")
        case 2:
            maximumNumberOfCountersLabel.text = NSLocalizedString("twoTiles", comment: "1 or 2 tiles")
        case 3:
            maximumNumberOfCountersLabel.text = NSLocalizedString("threeTiles", comment: "1, 2, or 3 tiles")
        default:
            maximumNumberOfCountersLabel.text = NSLocalizedString("fourTiles", comment: "1, 2, 3, or 4 tiles")
        }
        if(winMode == .lastWins){
            winModeLabel.text = NSLocalizedString("lastWins", comment: "last field wins")
        }
        else{
            winModeLabel.text = NSLocalizedString("lastLoses", comment: "last field loses")
        }
    }
    
    
    
    //MARK: Accessibility
    
    // when iPhone is rotated or font size is changed
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        changeSizes()
    }
    
    // when iPad is rotated or multitasking style is changed
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) {_ in
            self.changeSizes()
        }
    }
    
    func changeSizes(){
        view.layoutIfNeeded()

        // calc potential height of labels and change distances
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.font = maximumNumberOfCountersLabel.font

        var height1 = CGFloat(0)
        for part in [NSLocalizedString("oneTile", comment: "1 tile"),NSLocalizedString("twoTiles", comment: "1 or 2 tiles"),NSLocalizedString("threeTiles", comment: "1, 2, or 3 tiles"),NSLocalizedString("fourTiles", comment: "1, 2, 3, or 4 tiles")]{
            label.frame.size = CGSize(width: maximumNumberOfCountersLabel.frame.width, height: .greatestFiniteMagnitude)
            label.text = part
            label.sizeToFit()
            height1 = max(height1,label.frame.height)
        }
        
        var height2 = CGFloat(0)
        for part in [NSLocalizedString("lastWins", comment: "last field wins"),NSLocalizedString("lastLoses", comment: "last field loses")]{
            label.frame.size = CGSize(width: winModeLabel.frame.width, height: .greatestFiniteMagnitude)
            label.text = part
            label.sizeToFit()
            height2 = max(height2,label.frame.height)
        }
        
        var height3 = CGFloat(0)
        for i in 5...20{
            label.frame.size = CGSize(width: maximumNumberOfCountersLabel.frame.width, height: .greatestFiniteMagnitude)
            label.text = "\(i) \(NSLocalizedString("fields", comment: "fields"))"
            label.sizeToFit()
            height3 = max(height3,label.frame.height)
        }
        
        let maxi = max(height1,height2,height3)
        
        let currentMaxi = max(maximumNumberOfCountersLabel.frame.height,winModeLabel.frame.height,numberOfFieldsLabel.frame.height)

        if let stackView = view.subviews.first?.subviews.first?.subviews.first?.subviews.first(where: {$0 is UIStackView}) as? UIStackView{
            stackView.setCustomSpacing(100+maxi-currentMaxi, after: stackView.subviews[1])
        }
        
        // renew corner radius of color circles
        leftPlayerColorCircle.layer.cornerRadius = leftPlayerColorCircle.bounds.width/2
        rightPlayerColorCircle.layer.cornerRadius = rightPlayerColorCircle.bounds.width/2
    }
    
    
    
    // MARK: Settings Tiles and Circles

    // settings for number of tiles
    @IBOutlet weak var numberOfFieldsLabel: UILabel!
    @IBOutlet weak var numberOfFieldsStepper: UIStepper!
    @IBAction func changeNumberOfTiles(_ sender: UIStepper){
        numberOfFields = Int(sender.value)
        UserDefaults.standard.set(numberOfFields, forKey: "numberOfTiles")
        
        if let barView = self.gameContainerView.subviews.first(where: {$0.restorationIdentifier == "barView"}){
            if let tileBar = barView.subviews.filter({$0 is TileView}) as? [TileView]{
                                
                adjustCurrentNumberOfField()
                
                UIView.animate(withDuration: 0.4,animations: {
                    self.view.layoutIfNeeded()
                    self.changeVisibilityOfTiles(tileBar: tileBar)
                    
                    if let listOfLabels = self.gameContainerView.subviews.filter({$0 is TileLabel}) as? [TileLabel]{
                        for tileLabel in listOfLabels{
                            if (tileLabel.index <= self.numberOfFields){
                                tileLabel.alpha = 1
                            }
                            else{
                                tileLabel.alpha = 0
                            }
                        }
                    }
                })
                
            }
        }
        
        renewAllLabels()
        changeSizes()
    }
    
    // settings for number of maximal circle
    @IBOutlet weak var maximumNumberOfCountersLabel: UILabel!
    @IBOutlet weak var maximumNumberOfCountersStepper: UIStepper!
    @IBAction func changeNumberOfMaximalCircles(_ sender: UIStepper) {
        maximumNumberOfCounters = Int(sender.value)
        UserDefaults.standard.set(maximumNumberOfCounters, forKey: "numberOfMaximalCircles")
        drawField()
        changeSizes()
    }
    
    // settings for win mode
    @IBOutlet weak var winModeLabel: UILabel!
    @IBOutlet weak var winModeSegmentControl: UISegmentedControl!
    @IBAction func changeWinMode(_ sender: UISegmentedControl) {
        winMode = (sender.selectedSegmentIndex == 1) ? .lastWins : .lastLoses
        UserDefaults.standard.set(winMode.rawValue, forKey: "winMode")
        drawField()
        changeSizes()
    }


    
    // MARK: Settings Names and Colors
    
    // change left player name
    @IBOutlet weak var leftPlayerTextField: UITextField!
    @IBAction func changeLeftPlayerName(_ sender: UITextField) {
        UserDefaults.standard.set(sender.text, forKey: "firstPlayerName")
    }
    
    // change right player name
    @IBOutlet weak var rightPlayerTextField: UITextField!
    @IBAction func changeRightPlayerName(_ sender: UITextField) {
        UserDefaults.standard.set(sender.text, forKey: "secondPlayerName")
    }
    
    // circle colors
    @IBOutlet weak var rightPlayerColorCircle: UIView!
    @IBOutlet weak var leftPlayerColorCircle: UIView!
    @IBOutlet weak var leftPlayerColorButton: UIButton!
    @IBOutlet weak var rightPlayerColorButton: UIButton!
    func updateCircleColors(){
        leftPlayerColorCircle.backgroundColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "leftPlayerColor")!)?.value
        rightPlayerColorCircle.backgroundColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "rightPlayerColor")!)?.value
    }
    
    
    
    // MARK: Keyboard Activities
        
    @IBOutlet weak var scrollView: UIScrollView!

    // move view to top, when keyboard is shown
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height-view.safeAreaInsets.bottom+10, right: 0.0)
            scrollView.contentInset = contentInsets
            scrollView.scrollIndicatorInsets = contentInsets
            let activeRect = leftPlayerTextField.convert(leftPlayerTextField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(activeRect, animated: true)
        }
    }
    
    // move view back when keyboard is hidden
    @objc func keyboardWillHide(notification: Notification) {
        let contentInsets = UIEdgeInsets.zero
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
           view.endEditing(true)
           return false
    }
    
    // dismiss keyboard when somewhere is tapped
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    
    // MARK: Numbering

    @IBOutlet weak var numberModeSegmentControl: UISegmentedControl!
    @IBAction func changeNumberMode(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "settings_numberMode")
        renewNumbersInViews(currentNavigationController: self.navigationController!)
    }
    
}
