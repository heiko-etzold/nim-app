//
//  GameViewController.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import UIKit

class GameViewController: UIViewController, UIPointerInteractionDelegate, UIScrollViewDelegate{
    
    // hide status bar
    override var prefersStatusBarHidden: Bool{
        return true
    }

    
    // MARK: Create Content
    
    var numberOfTiles = Int(0)
    var numberOfMaximalCircles = Int(0)
    var winMode : WinMode!

    var currentNumberOfCircles = Int(0)
    var playMode = PlayMode.noPlaying

    var listOfTileViews : [TileView] = []

    var firstPlayerName = NSLocalizedString("left", comment: "Left")
    var secondPlayerName = NSLocalizedString("right", comment: "Right")
    
    var firstColor : Color!
    var secondColor : Color!
    
    @IBOutlet weak var gameContainerView: UIView!
    @IBOutlet weak var rightButtonHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var newGameButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var taskLabelHeightConstraint: NSLayoutConstraint!

    var scrollViewContentWidth = CGFloat(0)
    func changeSizesByAccessibility(){
        
        view.layoutIfNeeded()

        taskLabel.changeHeightConstraint(texts: [String(format: NSLocalizedString("winner", comment: "%@ has won."), firstPlayerName),
                                                 String(format: NSLocalizedString("winner", comment: "%@ has won."), secondPlayerName),
                                                 NSLocalizedString("beginner", comment: "Who begins?"),
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(NSLocalizedString("placeTilesInOrder", comment: "You have to place the tiles in order from left to right."))",
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(NSLocalizedString("placeTilesInOrder", comment: "You have to place the tiles in order from left to right."))",
                                                 NSLocalizedString("selectPlayer", comment: "First you have to choose who begins."),
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(NSLocalizedString("placeAtLeastOne", comment: "You have to place at least one tile."))",
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(NSLocalizedString("placeAtLeastOne", comment: "You have to place at least one tile."))",
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))",
                                                 "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"],
                                         heightConstraint: taskLabelHeightConstraint)


        leftPlayerButton.titleLabel?.textAlignment = .center
        rightPlayerButton.titleLabel?.textAlignment = .center
        newGameButton.titleLabel?.textAlignment = .center
        archiveButton.titleLabel?.textAlignment = .center

        newGameButton.changeHeightConstraint(texts: [newGameButton.title(for: .normal)!],
                                             heightConstraint: newGameButtonHeightConstraint,
                                             maximumWidth: view.frame.width-40)
        archiveButton.changeConstraints(texts: [archiveButton.title(for: .normal)!,newGameButton.title(for: .normal)!],
                                        heightConstraint: archiveButtonHeightConstraint,
                                        widthConstraint: archiveButtonWidthConstraint,
                                        maximumWidth: view.frame.width-40)
        
        view.layoutIfNeeded()
        changeSpecials()
    }
    
    func changeSpecials(){
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        let isAccessibilityCategory = traitCollection.preferredContentSizeCategory
        super.traitCollectionDidChange(previousTraitCollection)
        
        changeSizesByAccessibility()
        if isAccessibilityCategory != previousTraitCollection?.preferredContentSizeCategory {
            changeSizesByAccessibility()
        }
    }
    
    @IBOutlet weak var stackView: UIStackView!
    
    @IBOutlet weak var archiveButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var archiveButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var newGameButton: UIButton!
    @IBOutlet weak var buttonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var gameViewHeightConstraint: NSLayoutConstraint!
   
    override func viewDidLoad() {
        super.viewDidLoad()
    
        numberOfTiles = UserDefaults.standard.integer(forKey: "numberOfTiles")
        numberOfMaximalCircles = UserDefaults.standard.integer(forKey: "numberOfMaximalCircles")
        winMode = WinMode.init(rawValue: UserDefaults.standard.string(forKey: "winMode")!)

        if(UserDefaults.standard.string(forKey: "firstPlayerName") != nil && UserDefaults.standard.string(forKey: "firstPlayerName") != ""){
            firstPlayerName = UserDefaults.standard.string(forKey: "firstPlayerName")!
        }
        if(UserDefaults.standard.string(forKey: "secondPlayerName") != nil && UserDefaults.standard.string(forKey: "secondPlayerName") != ""){
            secondPlayerName = UserDefaults.standard.string(forKey: "secondPlayerName")!
        }
        
        firstColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "leftPlayerColor")!)
        secondColor = Color.init(rawValue: UserDefaults.standard.string(forKey: "rightPlayerColor")!)
        
        leftPlayerButton.backgroundColor = firstColor.value
        if(firstColor == .yellow && traitCollection.userInterfaceStyle == .light){
            leftPlayerButton.tintColor = .black.withAlphaComponent(0.6)
        }
        else{
            leftPlayerButton.tintColor = .systemBackground
        }
        
        
        rightPlayerButton.backgroundColor = secondColor.value
        if(secondColor == .yellow && traitCollection.userInterfaceStyle == .light){
            rightPlayerButton.tintColor = .black.withAlphaComponent(0.6)
        }
        else{
            rightPlayerButton.tintColor = .systemBackground
        }
        
        listOfTileViews = createTileBar(gameFieldView: gameContainerView, numberOfTiles: numberOfTiles, align: .center)

        activateTiles()
        resetTiles()

        for tileView in listOfTileViews{
            
            if(tileView.index != numberOfTiles){
                tileView.thumb.alpha = 0
            }
            else{
                tileView.thumbMode = .game
                tileView.winMode = winMode
                tileView.changeThumbImage()
                tileView.changeThumbColor()
            }
            
            if #available(iOS 13.4, *) {
                let pointerInteraction = UIPointerInteraction(delegate: self)
                tileView.addInteraction(pointerInteraction)
            }
            tileView.isAccessibilityElement = true
            tileView.accessibilityLabel = String(format: NSLocalizedString("fieldOf", comment: "field %i of %i"), tileView.index,numberOfTiles)
            tileView.accessibilityHint = NSLocalizedString("doubleTap", comment: "double tap to select")
        }
        
        changeSizesByAccessibility()

        leftPlayerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        leftPlayerButton.titleLabel?.numberOfLines = 0
        rightPlayerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        newGameButton.titleLabel?.adjustsFontForContentSizeCategory = true
        archiveButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        view.layoutIfNeeded()
    }
    
    @available(iOS 13.4, *)
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        var pointerStyle: UIPointerStyle? = nil
        if let interactionView = interaction.view {
            let targetedPreview = UITargetedPreview(view: interactionView)
            interactionView.superview!.bringSubviewToFront(interactionView)
            pointerStyle = UIPointerStyle(effect: UIPointerEffect.hover(targetedPreview, preferredTintMode: .overlay, prefersShadow: true, prefersScaledContent: false))
        }
        return pointerStyle
    }

    //renew numbers
    override func viewWillAppear(_ animated: Bool) {
        renewNumbersInViews(currentNavigationController: self.navigationController!)
        numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
    }

    override func viewDidAppear(_ animated: Bool) {
        changeSizesByAccessibility()
    }

    func activateTiles(){
        for tileView in listOfTileViews{
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(addCircle))
            tileView.addGestureRecognizer(tapRecognizer)
        }
    }
    
    func resetTiles(){
        for subTile in listOfTileViews{
            subTile.color = .none
            subTile.isEditable = false

            for subView in subTile.subviews.filter({($0 is TileLabel) == false && $0 != subTile.thumb}){
                subView.removeFromSuperview()
            }
            
        }
        view.layoutIfNeeded()
        leftPlayerButton.setTitle(firstPlayerName, for: .normal)
        leftPlayerButton.isEnabled = true
        leftPlayerButton.alpha = 1
        view.layoutIfNeeded()
        leftPlayerButton.layoutIfNeeded()
        leftPlayerButton.setNeedsLayout()
        rightPlayerButton.setTitle(secondPlayerName, for: .normal)
        rightPlayerButton.isEnabled = true
        rightPlayerButton.alpha = 1

        taskLabel.text = NSLocalizedString("beginner", comment: "Who begins?")
        archiveButton.alpha = 0
        
        playMode = .noPlaying

        listOfTileViews.first?.isEditable = true
    }
    
    
    
    // MARK: User Interaction
    
    @IBOutlet weak var taskLabel: UILabel!
    
    @IBOutlet weak var leftPlayerButtonWidthConstraint: NSLayoutConstraint!
    
    // renew labels und state when left player button is pressed
    @IBOutlet weak var leftPlayerButton: UIButton!
    @IBAction func pressLeftPlayerButton(_ sender: UIButton) {
        switch playMode {
        case .noPlaying:
            currentNumberOfCircles = 0
            taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"
            rightPlayerButton.setTitle("", for: .normal)
            sender.setTitle(NSLocalizedString("ready", comment: "ready"), for: .normal)
            rightPlayerButton.isEnabled = false
            rightPlayerButton.alpha = 0.2

            playMode = .leftPlayerIsPlaying

        case .leftPlayerIsPlaying:
            if(currentNumberOfCircles == 0){
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(NSLocalizedString("placeAtLeastOne", comment: "You have to place at least one tile."))"
            }
            else{
                currentNumberOfCircles = 0
                sender.setTitle("", for: .normal)
                rightPlayerButton.setTitle(NSLocalizedString("ready", comment: "ready"), for: .normal)
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"

                sender.isEnabled = false
                sender.alpha = 0.2

                rightPlayerButton.isEnabled = true
                rightPlayerButton.alpha = 1

                playMode = .rightPlayerIsPlaying
            }
        case .rightPlayerIsPlaying:
            break

        }
    }
    
    // renew labels und state when right player button is pressed
    @IBOutlet weak var rightPlayerButton: UIButton!
    @IBAction func pressRightPlayerButton(_ sender: UIButton) {
        switch playMode {
        case .noPlaying:

            taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"
            currentNumberOfCircles = 0
            leftPlayerButton.setTitle("", for: .normal)
            sender.setTitle(NSLocalizedString("ready", comment: "ready"), for: .normal)
            leftPlayerButton.isEnabled = false
            leftPlayerButton.alpha = 0.2
            playMode = .rightPlayerIsPlaying
        case .leftPlayerIsPlaying:
            break
        case .rightPlayerIsPlaying:
            if(currentNumberOfCircles == 0){
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), secondPlayerName))\n\n\(NSLocalizedString("placeAtLeastOne", comment: "You have to place at least one tile."))"
            }
            else{
                currentNumberOfCircles = 0
                sender.setTitle("", for: .normal)
                leftPlayerButton.setTitle(NSLocalizedString("ready", comment: "ready"), for: .normal)
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), firstPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"
                sender.isEnabled = false
                sender.alpha = 0.2
                
                leftPlayerButton.isEnabled = true
                leftPlayerButton.alpha = 1
                playMode = .leftPlayerIsPlaying
            }
        }

    }
    
    // add circle to tile bar
    @objc func addCircle(sender: UITapGestureRecognizer){
        guard let currentTileView = sender.view as? TileView else {
            return
        }
        
        if(playMode == .noPlaying){
            taskLabel.text = NSLocalizedString("selectPlayer", comment: "First you have to choose who begins.")
        }
        else if(currentTileView.color == .none){

            if let currentIndex = listOfTileViews.firstIndex(of: currentTileView){
                if(currentIndex != 0 && listOfTileViews[currentIndex-1].color == .none) {
                    taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), playMode == .leftPlayerIsPlaying ? firstPlayerName : secondPlayerName))\n\n\(NSLocalizedString("placeTilesInOrder", comment: "You have to place the tiles in order from left to right."))"
                }
            }
            
            if(currentNumberOfCircles >= numberOfMaximalCircles){
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), playMode == .leftPlayerIsPlaying ? firstPlayerName : secondPlayerName))\n\n\(String(format: NSLocalizedString("NoMorePlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"
            }
            
            if(currentTileView.isEditable == true && currentNumberOfCircles < numberOfMaximalCircles){
                taskLabel.text = "\(String(format: NSLocalizedString("turnName", comment: "It's %@'s turn."), playMode == .leftPlayerIsPlaying ? firstPlayerName : secondPlayerName))\n\n\(String(format: NSLocalizedString("PlaceCounters", comment: "Place a maximum of %d counters."), numberOfMaximalCircles))"

                currentNumberOfCircles += 1
                let circleView = CircleView()
                circleView.translatesAutoresizingMaskIntoConstraints = false
                currentTileView.addSubview(circleView)

                if let currentIndex = listOfTileViews.firstIndex(of: currentTileView){
                    if(listOfTileViews.count > currentIndex+1){
                        listOfTileViews[currentIndex+1].isEditable = true
                    }
                }
                
                if(playMode == .leftPlayerIsPlaying){
                    circleView.backgroundColor = firstColor.value
                    currentTileView.color = firstColor
                    currentTileView.accessibilityHint = String(format: NSLocalizedString("fieldMarked", comment: "field is marked %@"), listOfColorNames.first(where: {$0.0 == firstColor.position})!.1)//NSLocalizedString("doubleTap", comment: "double tap to select")

                }
                if(playMode == .rightPlayerIsPlaying){
                    circleView.backgroundColor = secondColor.value
                    currentTileView.color = secondColor
                    currentTileView.accessibilityHint = String(format: NSLocalizedString("fieldMarked", comment: "field is marked %@"), listOfColorNames.first(where: {$0.0 == secondColor.position})!.1)//NSLocalizedString("doubleTap", comment: "double tap to select")

                }
                circleView.widthAnchor.constraint(equalTo: currentTileView.widthAnchor, multiplier: 0.8).isActive = true
                circleView.heightAnchor.constraint(equalTo: circleView.widthAnchor).isActive = true
                circleView.centerXAnchor.constraint(equalTo: currentTileView.centerXAnchor).isActive = true
                circleView.centerYAnchor.constraint(equalTo: currentTileView.centerYAnchor).isActive = true
            }
        }
        
        if(listOfTileViews[numberOfTiles-1].color != Color.none){
            leftPlayerButton.isEnabled = false
            leftPlayerButton.alpha = 0
            leftPlayerButton.setTitle("", for: .normal)
            rightPlayerButton.isEnabled = false
            rightPlayerButton.alpha = 0
            rightPlayerButton.setTitle("", for: .normal)
            switch (listOfTileViews[numberOfTiles-1].color, winMode){
            case (firstColor, .lastWins), (secondColor, .lastLoses):
                taskLabel.text = String(format: NSLocalizedString("winner", comment: "%@ has won."), firstPlayerName)
            case (firstColor, .lastLoses), (secondColor, .lastWins):
                taskLabel.text = String(format: NSLocalizedString("winner", comment: "%@ has won."), secondPlayerName)
            default:
                break
            }
            
            currentTileView.thumbMode = .result
            currentTileView.changeThumbColor()
            currentTileView.bringSubviewToFront(currentTileView.thumb)
            archiveButton.alpha = 1
        }
        
        UIAccessibility.post(notification: .layoutChanged, argument: taskLabel)
    }
    
    // create new game
    @IBAction func pressNewGameButton(_ sender: UIButton) {
        resetTiles()
        UIAccessibility.post(notification: .layoutChanged, argument: taskLabel)
    }
    
    
    // MARK: Archive
    
    @IBOutlet weak var archiveButton: UIButton!

    @IBAction func pressArchiveGameButton(_ sender: UIButton) {
        // create list of colors
        var listOfColors : [Color] = []
        for tileView in listOfTileViews[0...numberOfTiles-1]{
            listOfColors.append(tileView.color)
        }
        
        // create temporary tile bar with circles and thumb for visual effect
        let tmpTileBar = UIView(frame: gameContainerView.bounds)
        
        let tmpListOfTileViews = createTileBar(gameFieldView: tmpTileBar, numberOfTiles: numberOfTiles, align: .center)

        for i in 0 ..< listOfColors.count{
            drawCircle(tileView: tmpListOfTileViews[i], contentColor: listOfColors[i])
        }
        
        if let lastTile = tmpListOfTileViews.last{
            lastTile.thumbMode = .result
            lastTile.winMode = winMode
            lastTile.changeThumbColor()
            lastTile.changeThumbImage()
            lastTile.bringSubviewToFront(lastTile.thumb)
        }
        if let lastTile = self.listOfTileViews.last{
            lastTile.thumbMode = .game
            lastTile.changeThumbColor()
        }
        
        tmpTileBar.center = gameContainerView.convert(gameContainerView.center, to: view)
        view.addSubview(tmpTileBar)
        
        // show movement of temporary tile bar and remove it
        var destinationPoint = CGPoint(x: 50 ,y: 49)
        if let buttonView = navigationController?.navigationBar.topItem?.rightBarButtonItem?.value(forKey: "view") as? UIView{
            destinationPoint = buttonView.convert(buttonView.center, to: self.view)
        }

        UIView.animate(withDuration: 1, animations: {
            tmpTileBar.alpha = 0.2
            tmpTileBar.transform = tmpTileBar.transform.scaledBy(x: 0.1, y: 0.1)
            tmpTileBar.center = destinationPoint
        }, completion: {_ in
            tmpTileBar .removeFromSuperview()


        })
        
        // create archive entry and save it in UserDefaults
        let leftPlayerNameIsSet = (UserDefaults.standard.string(forKey: "firstPlayerName") != nil && UserDefaults.standard.string(forKey: "firstPlayerName") != "")
        let rightPlayerNameIsSet = (UserDefaults.standard.string(forKey: "secondPlayerName") != nil && UserDefaults.standard.string(forKey: "secondPlayerName") != "")

        var maximumTimeStamp = Int(0)
        for archiveEntry in listOfArchiveEntries{
            maximumTimeStamp = max(maximumTimeStamp,archiveEntry.gameNumber)
        }
                
        let archiveEntry = ArchiveEntry(listOfColors: listOfColors, winMode: winMode, numberOfMaximalCircles: numberOfMaximalCircles, leftPlayerColor: firstColor, rightPlayerColor: secondColor, leftPlayerName: leftPlayerNameIsSet ? firstPlayerName : "", rightPlayerName: rightPlayerNameIsSet ? secondPlayerName : "", gameNumber: maximumTimeStamp+1)
        listOfArchiveEntries.append(archiveEntry)
        saveArchive()
        
        // clear the visible tile bar
        resetTiles()
    }
    
    
    
    // MARK: Numbering

    @IBOutlet weak var numberModeSegmentControl: UISegmentedControl!
    @IBAction func changeNumberMode(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "settings_numberMode")
        renewNumbersInViews(currentNavigationController: self.navigationController!)
    }

}
