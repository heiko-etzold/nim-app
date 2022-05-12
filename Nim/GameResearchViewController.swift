//
//  GameResearchViewController.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import UIKit

var referenceArchiveEntry : ArchiveEntry!

class GameResearchViewController: GameViewController {
    
    //hide status bar
    override var prefersStatusBarHidden: Bool{
        return true
    }
    
    
    // MARK: Create Content
    
    @IBOutlet weak var referenceGameFieldView: UIView!

    @IBOutlet weak var referenceNumberOfMaximalCirclesLabel: UILabel!
    @IBOutlet weak var referenceWinModeLabel: UILabel!
    @IBOutlet weak var referenceNumberOfTilesLabel: UILabel!

    @IBOutlet weak var scrollView: UIScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set local variables by archive entry
        numberOfTiles = referenceArchiveEntry.listOfColors.count
        numberOfMaximalCircles = referenceArchiveEntry.numberOfMaximalCircles
        winMode = referenceArchiveEntry.winMode

        firstPlayerName = referenceArchiveEntry.leftPlayerName
        if(firstPlayerName == ""){
            firstPlayerName = NSLocalizedString("left", comment: "Left")
        }
        secondPlayerName = referenceArchiveEntry.rightPlayerName
        if(secondPlayerName == ""){
            secondPlayerName = NSLocalizedString("right", comment: "Right")
        }

        firstColor = referenceArchiveEntry.leftPlayerColor
        secondColor = referenceArchiveEntry.rightPlayerColor
        
        // create and update views
        leftPlayerButton.backgroundColor = firstColor.value
        if(firstColor == .yellow){
            leftPlayerButton.tintColor = .black
        }
        else{
            leftPlayerButton.tintColor = .systemBackground
        }
        
        
        rightPlayerButton.backgroundColor = secondColor.value
        if(secondColor == .yellow){
            rightPlayerButton.tintColor = .black
        }
        else{
            rightPlayerButton.tintColor = .systemBackground
        }
        
        drawField()

        for tileView in listOfTileViews{
            if #available(iOS 13.4, *) {
                let pointerInteraction = UIPointerInteraction(delegate: self)
                tileView.addInteraction(pointerInteraction)
            }
        }
        numberOfTilesStepper.value = Double(numberOfTiles)
        numberOfMaximalCirclesStepper.value = Double(numberOfMaximalCircles)
        winModeSegmentControl.selectedSegmentIndex = (winMode == .lastWins) ? 1 : 0

        // create reference tile bar
        let referenceTileBar = createTileBar(gameFieldView: referenceGameContainerView, numberOfTiles: numberOfTiles, align: .center)
        for referenceTileView in referenceTileBar{
            referenceTileView.backgroundColor = .clear
        }
        for i in 0 ..< numberOfTiles{
            drawCircle(tileView: referenceTileBar[i], contentColor: referenceArchiveEntry.listOfColors[i])
        }
        
        
        if let lastTile = referenceTileBar.last{
            lastTile.thumbMode = .result
            lastTile.winMode = winMode
            lastTile.changeThumbColor()
            lastTile.changeThumbImage()
            lastTile.bringSubviewToFront(lastTile.thumb)
        }
        
        referenceNumberOfTilesLabel.text = numberOfTilesLabel.text
        referenceWinModeLabel.text = winModeLabel.text
        referenceNumberOfMaximalCirclesLabel.text = numberOfMaximalCirclesLabel.text
        
    }
    
    @IBOutlet weak var referenceLabelHeightConstraint: NSLayoutConstraint!
    override func changeSpecials() {
        numberOfMaximalCirclesLabel.changeHeightConstraint(texts: [NSLocalizedString("oneTile", comment: "1 tile"),
                                                                   NSLocalizedString("twoTiles", comment: "1 or 2 tiles"),
                                                                   NSLocalizedString("threeTiles", comment: "1, 2, or 3 tiles"),
                                                                   NSLocalizedString("fourTiles", comment: "1, 2, 3, or 4 tiles"),
                                                                   NSLocalizedString("lastWins", comment: "last field wins"),
                                                                   NSLocalizedString("lastLoses", comment: "last field loses"),
                                                                   "20 \(NSLocalizedString("fields", comment: "fields"))"],
                                                           heightConstraint: numberOfCircleHeightConstraint)

        referenceLabelHeightConstraint.constant = numberOfCircleHeightConstraint.constant
        numberOfCircleHeightConstraint.constant += 20
    }
    
    @IBOutlet weak var numberOfCircleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var referenceGameContainerView: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
        renewNumbersInViews(currentNavigationController: self.navigationController!)
    }
    
    
    // draw gameField depending on local settings
    func drawField(){
        for sub in self.gameContainerView.subviews{
            sub.removeFromSuperview()
        }
        
        listOfTileViews = createTileBar(gameFieldView: gameContainerView, numberOfTiles: 20, align: .center)
        
        for tileView in listOfTileViews{
            tileView.winMode = winMode
            tileView.thumbMode = .game
            tileView.changeThumbImage()
            tileView.changeThumbColor()
        }

        adjustCurrentNumberOfField()
        changeVisibilityOfTiles(tileBar: listOfTileViews)

        renewAllLabels()
        activateTiles()
        resetTiles()
    }

    func changeVisibilityOfTiles(tileBar: [TileView]){
        for tileView in tileBar{
            if(tileView.index <= numberOfTiles){
                tileView.alpha = 1
                if(tileView.index == numberOfTiles){
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
    
    func renewAllLabels(){
        numberOfTilesLabel.text = "\(numberOfTiles) \(NSLocalizedString("fields", comment: "fields"))"

        switch numberOfMaximalCircles{
        case 1:
            numberOfMaximalCirclesLabel.text = NSLocalizedString("oneTile", comment: "1 tile")
        case 2:
            numberOfMaximalCirclesLabel.text = NSLocalizedString("twoTiles", comment: "1 or 2 tiles")
        case 3:
            numberOfMaximalCirclesLabel.text = NSLocalizedString("threeTiles", comment: "1, 2, or 3 tiles")
        default:
            numberOfMaximalCirclesLabel.text = NSLocalizedString("fourTiles", comment: "1, 2, 3, or 4 tiles")
        }
        
        if(winMode == .lastWins){
            winModeLabel.text = NSLocalizedString("lastWins", comment: "last field wins")
        }
        else{
            winModeLabel.text = NSLocalizedString("lastLoses", comment: "last field loses")
        }
    }
    
    override func viewWillLayoutSubviews() {
        if let listOfLabels = gameContainerView.subviews.filter({$0 is TileLabel}) as? [TileLabel]{
            for tileLabel in listOfLabels{
                if (tileLabel.index <= numberOfTiles){
                    tileLabel.alpha = 1
                }
                else{
                    tileLabel.alpha = 0
                }
            }
        }
    }
    
    func adjustCurrentNumberOfField(){
        
        if let barView = gameContainerView.subviews.first(where: {$0.restorationIdentifier == "barView"}){
            if let exampleTileBar = barView.subviews.filter({$0 is TileView}) as? [TileView]{
                if let lastConstraint =  barView.constraints.first(where: {$0.identifier == "lastConstraint"}){
                    barView.removeConstraint(lastConstraint)
                    let newLastConstraint = NSLayoutConstraint(item: exampleTileBar[numberOfTiles-1], attribute: .trailing, relatedBy: .equal, toItem: barView, attribute: .trailing, multiplier: 1, constant: 0)
                    newLastConstraint.identifier = "lastConstraint"
                    newLastConstraint.isActive = true
                }
            }
        }
    }
    
    
    // settings for number of tiles
    @IBOutlet weak var numberOfTilesLabel: UILabel!
    @IBOutlet weak var numberOfTilesStepper: UIStepper!
    @IBAction func changeNumberOfTiles(_ sender: UIStepper) {
        
        numberOfTiles = Int(sender.value)
        
        if let barView = self.gameContainerView.subviews.first(where: {$0.restorationIdentifier == "barView"}){
            if let tileBar = barView.subviews.filter({$0 is TileView}) as? [TileView]{
                
                adjustCurrentNumberOfField()
                
                UIView.animate(withDuration: 0.4,
                               animations: {
                    self.view.layoutIfNeeded()
                    self.changeVisibilityOfTiles(tileBar: tileBar)
                    
                    if let listOfLabels = self.gameContainerView.subviews.filter({$0 is TileLabel}) as? [TileLabel]{
                        for tileLabel in listOfLabels{
                            if (tileLabel.index <= self.numberOfTiles){
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
        activateTiles()
        resetTiles()
    }
    
    // settings for number of maximal circle
    @IBOutlet weak var numberOfMaximalCirclesLabel: UILabel!
    @IBOutlet weak var numberOfMaximalCirclesStepper: UIStepper!
    @IBAction func changeNumberOfMaximalCircles(_ sender: UIStepper) {
        numberOfMaximalCircles = Int(sender.value)
        UserDefaults.standard.set(numberOfMaximalCircles, forKey: "numberOfMaximalCircles")
        drawField()
    }
    
    // settings for win mode
    @IBOutlet weak var winModeLabel: UILabel!
    @IBOutlet weak var winModeSegmentControl: UISegmentedControl!
    @IBAction func changeWinMode(_ sender: UISegmentedControl) {
        winMode = (sender.selectedSegmentIndex == 1) ? .lastWins : .lastLoses
        UserDefaults.standard.set(winMode.rawValue, forKey: "winMode")
        drawField()
    }
    
}
