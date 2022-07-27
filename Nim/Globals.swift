//
//  Globals.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import Foundation
import UIKit


// MARK: Archive activities

// define structure of archive
struct ArchiveEntry : Codable, Equatable {
    var listOfColors : [Color]
    var winMode : WinMode
    var numberOfMaximalCircles: Int
    var leftPlayerColor : Color
    var rightPlayerColor : Color
    var leftPlayerName : String
    var rightPlayerName : String
    var gameNumber: Int
}

var listOfArchiveEntries : [ArchiveEntry] = []

// save and load Archive locally from UserDefaults
func saveArchive(){
    let encoder = JSONEncoder()
    if let encoded = try? encoder.encode(listOfArchiveEntries) {
        UserDefaults.standard.set(encoded, forKey: "archive")
    }
}
func loadArchive(){
    if let savedArchive = UserDefaults.standard.object(forKey: "archive") as? Data {
        let decoder = JSONDecoder()
        if let loadedArchive = try? decoder.decode([ArchiveEntry].self, from: savedArchive) {
            listOfArchiveEntries = loadedArchive
        }
    }
}

// open archive from url
func openNimFile(url: URL, currentWindow: UIWindow){

    //close all current presented viewcontrollers (like popovers)
    if let presentedVC = currentWindow.rootViewController?.presentedViewController{
        presentedVC.dismiss(animated: true, completion: nil)
    }
    
    if(url.pathExtension == "nim"){
        // open and decode url content as list of ArchivEentry
        let decoder = JSONDecoder()
        if let input = try? String(contentsOf: url){
            let json = input.data(using: .utf8)
            if let product = try? decoder.decode([ArchiveEntry].self, from: json!){
                
                var fileIsOk = Bool(true)
                for entry in product{
                    if(entry.numberOfMaximalCircles<1 || entry.numberOfMaximalCircles>4){
                        fileIsOk = false
                    }
                }

                if(fileIsOk){
                    
                    // if current archive is empty, override with saved archive
                    if(listOfArchiveEntries.isEmpty){
                        listOfArchiveEntries = product
                        saveArchive()
                        navigateToArchive(currentWindow: currentWindow)
                    }
                    
                    // otherwise show alert to ask for overwriting or adding current archive
                    else{
                        let alertVC = UIAlertController(title: NSLocalizedString("archiveNewAlert", comment: "Open new Archive"), message: NSLocalizedString("archiveNewText", comment: "What do you want to do?"), preferredStyle: .alert)
                        alertVC.view.tintColor = exampleColor
                        alertVC.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
                        
                        alertVC.addAction(UIAlertAction(title: NSLocalizedString("archiveRemove", comment: "Overwrite old Archive"), style: .default, handler: { _ in
                            // overriting
                            listOfArchiveEntries = product
                            saveArchive()
                            navigateToArchive(currentWindow: currentWindow)
                            
                        }))
                        alertVC.addAction(UIAlertAction(title: NSLocalizedString("archiveAdd", comment: "Expand old Archive"), style: .default, handler: { _ in
                            // adding
                            for archiveEntry in product{
                                listOfArchiveEntries.append(archiveEntry)
                            }
                            saveArchive()
                            navigateToArchive(currentWindow: currentWindow)
                        }))
                        currentWindow.rootViewController!.present(alertVC, animated: true)
                    }
                    
                }
                else{
                    showErrorAlert(currentWindow: currentWindow, errorMessage: NSLocalizedString("errorNotRead", comment: "The file cannot be read."))
                    
                }
            }
            
    //show some types of alerts if necessary
            else{
                showErrorAlert(currentWindow: currentWindow, errorMessage: NSLocalizedString("errorNotRead", comment: "The file cannot be read."))
            }
        }
        else{
            showErrorAlert(currentWindow: currentWindow, errorMessage: NSLocalizedString("errorUnknown", comment: "An unknown error has occurred."))
        }
    }
    else{
        showErrorAlert(currentWindow: currentWindow, errorMessage: NSLocalizedString("errorFileType", comment: "The file type is not supported by the app."))
    }
}


// show alert if some error
func showErrorAlert(currentWindow: UIWindow, errorMessage: String){
    let alertVC = UIAlertController(title: NSLocalizedString("error", comment: "Error"), message: errorMessage, preferredStyle: .alert)
    alertVC.view.tintColor = exampleColor
    alertVC.addAction(UIAlertAction(title: "OK", style: .cancel))
    currentWindow.rootViewController!.present(alertVC, animated: true)
}


// navigate to archive viewController, dismiss possible popovers, and reload archive data
func navigateToArchive(currentWindow: UIWindow){

    if let navigation = (currentWindow.rootViewController as? UINavigationController)?.viewControllers{
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if(navigation.count == 1){
            if let presentedVC = currentWindow.rootViewController?.presentedViewController{
                presentedVC.dismiss(animated: true, completion: nil)
            }
            let gameVC = storyboard.instantiateViewController(withIdentifier: "gameVC")
            navigation.last?.navigationController?.pushViewController(gameVC, animated: true)
        }
        
        if(navigation.count <= 2){
            let archiveVC = storyboard.instantiateViewController(withIdentifier: "archiveVC")
            navigation.last?.navigationController?.pushViewController(archiveVC, animated: true)
        }
        
        if(navigation.count == 4){
            navigation.last?.navigationController?.popViewController(animated: true)
        }
        
        if(navigation.count == 3){
            if let currentArchiveVC = (navigation.last as? ArchiveViewController){
                if let presentedVC = currentArchiveVC.presentedViewController{
                    presentedVC.dismiss(animated: true, completion: nil)
                }
                currentArchiveVC.archiveCollectionView.reloadData()
            }
        }
    }
}



// MARK: Global Game Settings

enum PlayMode{
    case noPlaying
    case leftPlayerIsPlaying
    case rightPlayerIsPlaying
}

enum WinMode: String, Codable {
    case lastWins
    case lastLoses
}

var namesAreAnonymized = Bool(false)


// MARK: Tile Bar and Circles

// mode for shown numbers in tile bar (global app setting)
enum NumberMode: Int {
    case none
    case five
    case all
}
var numberMode = NumberMode.none
var numberModeIsEditable = Bool(true)

// class for tile label
let heightOfTileLabelInArchive = CGFloat(15)
class TileLabel: UILabel{
    
    var index = Int(0)
    var barAlignment = TileBarAlignment.center
    init(index: Int, barAlignment: TileBarAlignment){
        super.init(frame: .zero)
        self.index = index
        self.barAlignment = barAlignment
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        
        //change size
        if(barAlignment == .center){
            self.font = UIFont.systemFont(ofSize: 20)
        }
        else{
            self.font = UIFont.systemFont(ofSize: heightOfTileLabelInArchive)

        }
        
        // change visibility, depending on global settings
        switch numberMode {
        case .none:
            self.alpha = 0
        case .five:
            if(index%5 != 0){
                self.alpha = 0
            }
            else{
                self.alpha = 1
            }
        case .all:
            self.alpha = 1
        }
    }
}

// class for (squared) tiles
class TileView: UIView{
    var isEditable = Bool(false)
    var color = Color.none
    var index = Int(0)
    var thumbMode = ThumbMode.information
    var winMode = WinMode.lastWins
    var thumb = UIImageView()
    
    init(index: Int, superView: UIView){
        super.init(frame: .zero)
        self.backgroundColor = tileBackgroundColor
        self.layer.borderWidth = 1
        self.layer.borderColor = exampleColor.cgColor
        self.index = index
        
        if(index > 4){
            changeThumbImage()
            changeThumbColor()
            self.addSubview(thumb)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func changeThumbColor(){
        switch thumbMode {
        case .research:
            thumb.tintColor = UIColor(named: "researchBackgroundColor")
        case .information:
            thumb.tintColor = exampleColor
        case .game:
            thumb.tintColor = exampleColor.withAlphaComponent(0.5)
        default:
            thumb.tintColor = tileBackgroundColor
        }
    }
    
    func changeThumbImage(){
        let thumbImage = (winMode == .lastWins) ? UIImage(systemName: "hand.thumbsup") : UIImage(systemName: "hand.thumbsdown")
        let filledThumbImage = (winMode == .lastWins) ? UIImage(systemName: "hand.thumbsup.fill") : UIImage(systemName: "hand.thumbsdown.fill")
        thumb.image = (thumbMode == .archive) ? filledThumbImage : thumbImage

    }
    
    override func layoutSubviews() {
        thumb.frame.size.width = self.frame.width*0.6
        thumb.frame.size.height = self.frame.width*0.6
        thumb.center = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
    }
}

// spaces between tiles (single and blocks of five)
let smallSpaceBetweenTiles = CGFloat(3)
let largeSpaceBetweenTiles = CGFloat(9)

// left alignment needed for archive, center alignment for working view
enum TileBarAlignment{
    case left
    case center
}


// draw tileBar in superView and create list of tiles
func createTileBar(gameFieldView: UIView, numberOfTiles: Int, align: TileBarAlignment) -> [TileView]{
    
    let barView = UIView()
    barView.restorationIdentifier = "barView"
    barView.translatesAutoresizingMaskIntoConstraints = false
    gameFieldView.addSubview(barView)
    
    switch align {
    case .left:
        barView.leadingAnchor.constraint(equalTo: gameFieldView.leadingAnchor).isActive = true
        let barHeightConstraint = NSLayoutConstraint(item: barView, attribute: .height, relatedBy: .equal, toItem: gameFieldView, attribute: .height, multiplier: 0.8, constant: 0)
        barHeightConstraint.priority = UILayoutPriority(rawValue: 750)
        barHeightConstraint.isActive = true

        barView.trailingAnchor.constraint(greaterThanOrEqualTo: gameFieldView.trailingAnchor).isActive = true
    case .center:
        barView.centerXAnchor.constraint(equalTo: gameFieldView.centerXAnchor).isActive = true
        
        let leftConstraint = barView.leadingAnchor.constraint(greaterThanOrEqualTo: gameFieldView.leadingAnchor)
        leftConstraint.priority = .defaultLow
        leftConstraint.isActive = true

        let rightConstraint = barView.trailingAnchor.constraint(greaterThanOrEqualTo: gameFieldView.trailingAnchor)
        rightConstraint.priority = .defaultLow
        rightConstraint.isActive = true
        
        barView.heightAnchor.constraint(lessThanOrEqualTo: gameFieldView.heightAnchor, multiplier: 0.8).isActive = true
    }

    barView.bottomAnchor.constraint(equalTo: gameFieldView.bottomAnchor).isActive = true

    var listOfTiles: [TileView] = []
    for i in 0...numberOfTiles-1{
        let tileView = TileView(index: i+1, superView: barView)
        listOfTiles.append(tileView)
        tileView.translatesAutoresizingMaskIntoConstraints = false
        barView.addSubview(tileView)
        tileView.heightAnchor.constraint(equalTo: barView.heightAnchor).isActive = true
        tileView.widthAnchor.constraint(equalTo: tileView.heightAnchor).isActive = true
        if(i == 0){
            tileView.leadingAnchor.constraint(equalTo: barView.leadingAnchor).isActive = true
        }
        else{
            tileView.leadingAnchor.constraint(equalTo: listOfTiles[i-1].trailingAnchor, constant: (i%5 == 0) ? largeSpaceBetweenTiles : smallSpaceBetweenTiles).isActive = true
        }
        if(i == numberOfTiles-1){
            let lastConstraint = NSLayoutConstraint(item: tileView, attribute: .trailing, relatedBy: .equal, toItem: barView, attribute: .trailing, multiplier: 1, constant: 0)
            lastConstraint.identifier = "lastConstraint"
            lastConstraint.isActive = true
        }
        
        let label = TileLabel(index: i+1, barAlignment: align)
        label.textColor = .secondaryLabel
        label.text = "\(i+1)"
        gameFieldView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: tileView.centerXAnchor).isActive = true

        if(align == .left){
            label.topAnchor.constraint(equalTo: gameFieldView.topAnchor).isActive = true
        }
        label.bottomAnchor.constraint(equalTo: barView.topAnchor).isActive = true

    }
        
    gameFieldView.layoutIfNeeded()
    return listOfTiles
}

enum ThumbMode{
    case information
    case result
    case game
    case archive
    case research
}

// class for circle in tile
class CircleView : UIView {
    override func layoutSubviews() {
        self.layer.cornerRadius = self.frame.width/2
    }
}

// draw circle in tile
func drawCircle(tileView: TileView, contentColor: Color){
    let circleView = CircleView()
    circleView.translatesAutoresizingMaskIntoConstraints = false
    tileView.addSubview(circleView)
    circleView.widthAnchor.constraint(equalTo: tileView.widthAnchor, multiplier: 0.8).isActive = true
    circleView.heightAnchor.constraint(equalTo: circleView.widthAnchor).isActive = true
    circleView.centerXAnchor.constraint(equalTo: tileView.centerXAnchor).isActive = true
    circleView.centerYAnchor.constraint(equalTo: tileView.centerYAnchor).isActive = true
    circleView.backgroundColor = contentColor.value
}



// MARK: Colors

let exampleColor = UIColor.systemGray
let tileBackgroundColor = UIColor.systemGray6

// Color type, necessary to save in archive
enum Color: String, Codable {
    case red
    case blue
    case yellow
    case green
    case orange
    case purple
    case none
}

let listOfColorNames : [(Int,String)] = [(1,NSLocalizedString("red", comment: "red")),
                                         (2,NSLocalizedString("blue", comment: "blue")),
                                         (3,NSLocalizedString("yellow", comment: "yellow")),
                                         (4,NSLocalizedString("green", comment: "green")),
                                         (5,NSLocalizedString("orange", comment: "orange")),
                                         (6,NSLocalizedString("purple", comment: "purple"))]

// get systemColor and position by color
extension Color {
    var value: UIColor {
        get {
            switch self {
            case .red:
                return UIColor(named: "red")!
            case .orange:
                return UIColor(named: "orange")!
            case .yellow:
                return UIColor(named: "yellow")!
            case .blue:
                return UIColor(named: "blue")!
            case .green:
                return UIColor(named: "green")!
            case .purple:
                return UIColor(named: "purple")!
            case .none:
                return exampleColor
            }
        }
    }
    
    var position: Int {
        get {
            switch self {
            case .red:
                return 1
            case .blue:
                return 2
            case .yellow:
                return 3
            case .green:
                return 4
            case .orange:
                return 5
            case .purple:
                return 6
            case .none:
                return 0
            }
        }
    }
}

// get color by position
func colorByPosition(postion: Int) -> Color{
    switch postion{
    case 1:
        return .red
    case 2:
        return .blue
    case 3:
        return .yellow
    case 4:
        return .green
    case 5:
        return .orange
    case 6:
        return .purple
    default:
        return .none
    }
}



// MARK: Numbering

func renewNumbersInViews(currentWindow: UIWindow){
    if let navigationController = currentWindow.rootViewController as? UINavigationController{
        renewNumbersInViews(currentNavigationController: navigationController)
    }
}


func renewNumbersInViews(currentNavigationController: UINavigationController){
    
    if(UserDefaults.standard.value(forKey: "settings_numberMode") == nil){
        UserDefaults.standard.set(0, forKey: "settings_numberMode")
    }
    if(UserDefaults.standard.value(forKey: "settings_numberModeIsEditable") == nil){
        UserDefaults.standard.set(true, forKey: "settings_numberModeIsEditable")
    }
    
    numberMode = NumberMode.init(rawValue: UserDefaults.standard.integer(forKey: "settings_numberMode"))!
    numberModeIsEditable = UserDefaults.standard.bool(forKey: "settings_numberModeIsEditable")
    
    if let currentVC = currentNavigationController.topViewController{
        
        if let settingsVC = currentVC as? SettingsViewController{
            settingsVC.numberModeSegmentControl.isHidden = !numberModeIsEditable
            settingsVC.numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
            if let gameFieldVieww = settingsVC.gameContainerView{
                for label in gameFieldVieww.subviews.filter({$0 is TileLabel}){
                    label.layoutSubviews()
                    if((label as! TileLabel).index > settingsVC.numberOfFields){
                        label.alpha = 0
                    }
                }
            }
        }
        if let gameVC = currentVC as? GameViewController{
            gameVC.numberModeSegmentControl.isHidden = !numberModeIsEditable
            gameVC.numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
            for label in gameVC.gameContainerView.subviews.filter({$0 is TileLabel}){
                label.layoutSubviews()
                if((label as! TileLabel).index > gameVC.numberOfTiles){
                    label.alpha = 0
                }
            }
        }
        if let archiveVC = currentVC as? ArchiveViewController{
            archiveVC.numberModeSegmentControl.isHidden = !numberModeIsEditable
            archiveVC.numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
            archiveVC.archiveCollectionView.reloadData()
        }
        if let gameResearchVC = currentVC as? GameResearchViewController{
            gameResearchVC.numberModeSegmentControl.isHidden = !numberModeIsEditable
            gameResearchVC.numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
            for label in gameResearchVC.referenceGameContainerView.subviews.filter({$0 is TileLabel}){
                label.layoutSubviews()
               
            }
        }
    }
}




// MARK: Localization

//make string localizable
extension String {
    func localized(withComment comment: String? = nil) -> String {
        
        let value = NSLocalizedString(self, comment: "")
        if value != self || NSLocale.preferredLanguages.first == "en" {
            return value
        }
        
        //fall back to Base
        guard
            let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return value }
        return NSLocalizedString(self, bundle: bundle, comment: comment ?? "")
    }
}


extension UIButton {
    
    func changeHeightConstraint(texts: [String], heightConstraint: NSLayoutConstraint, maximumWidth: CGFloat){

        let buttonLabel = UILabel()
        buttonLabel.numberOfLines = 0
        buttonLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        buttonLabel.font = self.titleLabel?.font
        
        var height = CGFloat(0)
        for part in texts{
            buttonLabel.frame.size = CGSize(width: maximumWidth-10, height: .greatestFiniteMagnitude)
            buttonLabel.text = part
            buttonLabel.sizeToFit()
            height = max(height,buttonLabel.frame.height)
        }
        
        heightConstraint.constant = height+20
        
    }
    
    func changeConstraints(texts: [String], heightConstraint: NSLayoutConstraint, widthConstraint: NSLayoutConstraint, maximumWidth: CGFloat){

        let buttonLabel = UILabel()
        buttonLabel.numberOfLines = 0
        buttonLabel.lineBreakMode = .byTruncatingTail
        buttonLabel.font = self.titleLabel?.font
        
        var height = CGFloat(0)
        var width = CGFloat(0)
        for part in texts{
            buttonLabel.frame.size = CGSize(width: maximumWidth-20, height: .greatestFiniteMagnitude)
            buttonLabel.text = part
            buttonLabel.sizeToFit()
            height = max(height,buttonLabel.frame.height)
            width = max(width,buttonLabel.frame.width)
        }

        heightConstraint.constant = height+20
        widthConstraint.constant = width+20
    }
}


extension UILabel {
    
    func changeHeightConstraint(texts: [String], heightConstraint: NSLayoutConstraint){
        
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.font = self.font
        
        var height = CGFloat(0)
        for part in texts{
            label.frame.size = CGSize(width: self.frame.width, height: .greatestFiniteMagnitude)
            label.text = part
            label.sizeToFit()
            height = max(height,label.frame.height)
        }
        heightConstraint.constant = height
    }
}


// settings for Mac
extension UserDefaults {
    @objc dynamic var settings_numberMode: Int {
        return integer(forKey: "settings_numberMode")
    }
    @objc dynamic var settings_numberModeIsEditable: Bool {
        return bool(forKey: "settings_numberModeIsEditable")
    }
    @objc dynamic var settings_allowIndividualExport: Bool {
        return bool(forKey: "settings_allowIndividualExport")
    }
}
