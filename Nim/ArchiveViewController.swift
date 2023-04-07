//
//  ArchiveViewController.swift
//  Nim
//
//  Created by Heiko Etzold
//  MIT License
//

import UIKit
import PDFKit
import Combine

extension NSTextAlignment {
    static var inversed: NSTextAlignment {
        return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .left : .right
    }
}

class TmpLayout : UICollectionViewFlowLayout{
    override var flipsHorizontallyInOppositeLayoutDirection: Bool{
        return true
    }
    override func prepare() {
        self.scrollDirection = .horizontal
    }
}



class ArchiveCollectionView : UICollectionView, UICollectionViewDragDelegate, UICollectionViewDropDelegate{
    
    fileprivate func reorderItems (coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        if let item = coordinator.items.first,
        let sourceIndexPath = item.sourceIndexPath {

            collectionView.performBatchUpdates({
                
                let archiveEntryAtSourceIndex = listOfArchiveEntries[sourceIndexPath.item]
                listOfArchiveEntries.remove(at: sourceIndexPath.item)
                listOfArchiveEntries.insert(archiveEntryAtSourceIndex, at: destinationIndexPath.item)
                saveArchive()
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
                collectionView.reloadData()
                if(sourceIndexPath.row < destinationIndexPath.row){
                    for i in sourceIndexPath.row...destinationIndexPath.row{
                        if let label = self.cellForItem(at: IndexPath(row: i, section: 0))?.contentView.subviews.first(where: {$0 is UILabel}) as? UILabel{
                            label.text = "\(i)"
                        }
                    }
                }
                else{
                    for i in destinationIndexPath.row...sourceIndexPath.row{
                        if let label = self.cellForItem(at: IndexPath(row: i, section: 0))?.contentView.subviews.first(where: {$0 is UILabel}) as? UILabel{
                            label.text = "\(2+i)"
                        }
                    }
                }
            }, completion: nil)
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        var destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        }
        else {
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(item: row - 1, section: 0)
        }
        if coordinator.proposal.operation == .move {
            self.reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        let renderer = UIGraphicsImageRenderer(bounds: collectionView.cellForItem(at: indexPath)!.convert(collectionView.cellForItem(at: indexPath)!.bounds, to: self))
        let image = renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
        
        let itemProvider = NSItemProvider(object: image as UIImage)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if(collectionView.hasActiveDrag){
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
}




class ArchiveViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate{
    
    
    // hide status bar
    override var prefersStatusBarHidden: Bool{
        return true
    }

    
    // MARK: Sizes
    
    // distance between cells
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    // height of cell
    let heightOfCell = CGFloat(50)
    
    // width of cell (depending on largest number of fields)
    let widthOfLabel = CGFloat(50)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let maximalNumberOfTiles = listOfArchiveEntries.sorted(by: {$0.listOfColors.count > $1.listOfColors.count}).first?.listOfColors.count ?? 10
        
        let tmpLabel = UILabel()
        tmpLabel.text = "1"
        tmpLabel.font = UIFont.systemFont(ofSize: heightOfTileLabelInArchive)
        tmpLabel.sizeToFit()
        
        var width = CGFloat(maximalNumberOfTiles)*(heightOfCell-tmpLabel.frame.height)
        width += CGFloat(maximalNumberOfTiles-1)*smallSpaceBetweenTiles
        width += CGFloat((maximalNumberOfTiles-1)/5)*(largeSpaceBetweenTiles-smallSpaceBetweenTiles)
        return CGSize(width: widthOfLabel+width, height: heightOfCell)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 5, left: 0, bottom: 15, right: 0)
    }


    
    // MARK: Collection Initialization
    
    // initialize data and there updates
    @IBOutlet weak var archiveCollectionView: ArchiveCollectionView!
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return listOfArchiveEntries.count
    }
    override func viewWillAppear(_ animated: Bool) {
        archiveCollectionView.reloadData()
        renewNumbersInViews(currentNavigationController: self.navigationController!)
        numberModeSegmentControl.selectedSegmentIndex = numberMode.rawValue
    }

    let dateFormatterForFileName = DateFormatter()
    let dateFormatterForContent = DateFormatter()

    var allowIndividualExportSettingSubscribber: AnyCancellable?

    override func viewDidLoad() {
        // add longPress, to enable cell movement
//        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture))
//        archiveCollectionView.addGestureRecognizer(longPressGesture)

        dateFormatterForFileName.dateFormat = "yyyy-MM-dd_HH-mm"
        dateFormatterForFileName.locale = Locale(identifier: "en")

        dateFormatterForContent.dateStyle = .medium
        dateFormatterForContent.timeStyle = .short
        dateFormatterForContent.locale = Locale(identifier: Locale.current.languageCode!)

        let tmpLayout = TmpLayout()
        archiveCollectionView.collectionViewLayout = tmpLayout
        
        allowIndividualExportSettingSubscribber = UserDefaults.standard
                .publisher(for: \.settings_allowIndividualExport)
                .sink(receiveValue: {_ in self.changeVisibilityOfEditinButton()})
        archiveCollectionView.dragDelegate = (archiveCollectionView!)
        archiveCollectionView.dropDelegate = (archiveCollectionView!)
    }

    
    func changeVisibilityOfEditinButton(){

        if(UserDefaults.standard.value(forKey: "settings_allowIndividualExport") == nil){
            UserDefaults.standard.set(false, forKey: "settings_allowIndividualExport")
        }
        if(UserDefaults.standard.bool(forKey: "settings_allowIndividualExport") == true){
            editButton.tintColor = view.tintColor
            editButton.isEnabled = true
        }
        else{
            editButton.tintColor = .clear
            editButton.isEnabled = false
        }
    }
    
    // initialize cell
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "archiveCell", for: indexPath)
        
        // remove all subviews
        for subview in cell.contentView.subviews{
            subview.removeFromSuperview()
        }
        
        // define width of current gameFieldView
        let tmpLabel = UILabel()
        tmpLabel.text = "1"
        tmpLabel.font = UIFont.systemFont(ofSize: heightOfTileLabelInArchive)
        tmpLabel.sizeToFit()
        
        let numberOfTiles = listOfArchiveEntries[indexPath.item].listOfColors.count
        var widthOfBarView = CGFloat(numberOfTiles)*(heightOfCell-tmpLabel.frame.height)
        widthOfBarView += CGFloat(numberOfTiles-1)*smallSpaceBetweenTiles
        widthOfBarView += CGFloat((numberOfTiles-1)/5)*(largeSpaceBetweenTiles-smallSpaceBetweenTiles)
    
        // create gameFieldView with circles and thumb
        let gameFieldView = UIView(frame: CGRect(x: widthOfLabel, y: 0, width: widthOfBarView, height: heightOfCell))
        gameFieldView.restorationIdentifier = "gameFieldView"
        gameFieldView.tag = 1
        gameFieldView.clipsToBounds = true
        cell.contentView.addSubview(gameFieldView)
        gameFieldView.translatesAutoresizingMaskIntoConstraints = false
        gameFieldView.widthAnchor.constraint(equalToConstant: widthOfBarView).isActive = true
        gameFieldView.heightAnchor.constraint(equalToConstant: heightOfCell).isActive = true
        gameFieldView.topAnchor.constraint(equalTo: cell.contentView.topAnchor).isActive = true


        let tileBar = createTileBar(gameFieldView: gameFieldView, numberOfTiles: listOfArchiveEntries[indexPath.item].listOfColors.count, align: .left)

        for i in 0 ..< tileBar.count{
            drawCircle(tileView: tileBar[i], contentColor: listOfArchiveEntries[indexPath.item].listOfColors[i])
        }
        if let lastTile = tileBar.last{
            lastTile.thumbMode = .archive
            lastTile.winMode = listOfArchiveEntries[indexPath.item].winMode
            lastTile.changeThumbColor()
            lastTile.changeThumbImage()
            lastTile.bringSubviewToFront(lastTile.thumb)
        }

        // create shadow view
        let shadowView = UIView(frame: CGRect(x: 0, y: tmpLabel.frame.height, width: widthOfLabel, height: heightOfCell-tmpLabel.frame.height))
        shadowView.restorationIdentifier = "shadowView"
        shadowView.backgroundColor = .clear
        shadowView.alpha = 0
        shadowView.layer.shadowRadius = 5
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 1
        shadowView.layer.shadowOffset = .zero
        shadowView.layer.shadowPath = UIBezierPath(rect: shadowView.bounds).cgPath
        cell.contentView.addSubview(shadowView)
        
        // create view over shadow
        let curtainView = UIView(frame: CGRect(x: 0, y: 0, width: widthOfLabel, height: heightOfCell))
        curtainView.restorationIdentifier = "curtainView"
        curtainView.backgroundColor = .systemBackground
        curtainView.alpha = 0
        cell.contentView.addSubview(curtainView)
    
        // create number label
        let label = UILabel()
        cell.contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor, constant: tmpLabel.frame.height/2).isActive = true
        label.widthAnchor.constraint(equalToConstant: 40).isActive = true
        label.textAlignment = .inversed
        label.font = UIFont.monospacedDigitSystemFont(ofSize: label.font.pointSize, weight: .semibold)// UIFont(name: "Menlo", size: label.font.pointSize)
        label.text = "\(indexPath.item+1)"
        
        gameFieldView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10).isActive = true
        // create view for research button
        let researchView = UIView(frame: CGRect(x: widthOfBarView+smallSpaceBetweenTiles, y: tmpLabel.frame.height, width: widthOfLabel, height: heightOfCell-tmpLabel.frame.height))
        researchView.restorationIdentifier = "researchView"
        researchView.backgroundColor = UIColor(named: "researchBackgroundColor")!
        gameFieldView.addSubview(researchView)

        let researchButton = UIButton(type: .system)
        researchButton.addTarget(self, action: #selector(researchCellBySwipeButton), for: .touchUpInside)
        researchButton.tintColor = .label
        researchButton.setBackgroundImage(UIImage(systemName: "magnifyingglass"), for: .normal)
        researchView.addSubview(researchButton)
        researchButton.translatesAutoresizingMaskIntoConstraints = false
        researchButton.centerXAnchor.constraint(equalTo: researchView.centerXAnchor).isActive = true
        researchButton.centerYAnchor.constraint(equalTo: researchView.centerYAnchor).isActive = true

        // create view for delete button
        let deleteView = UIView(frame: CGRect(x: widthOfBarView+smallSpaceBetweenTiles, y: tmpLabel.frame.height, width: widthOfLabel, height: heightOfCell-tmpLabel.frame.height))
        deleteView.restorationIdentifier = "deleteView"
        deleteView.backgroundColor = UIColor.systemRed
        gameFieldView.addSubview(deleteView)
        
        let deleteButton = UIButton(type: .system)
        deleteButton.addTarget(self, action: #selector(removeCellBySwipeButton), for: .touchUpInside)
        deleteButton.tintColor = .systemBackground
        deleteButton.setBackgroundImage(UIImage(systemName: "trash"), for: .normal)
        deleteView.addSubview(deleteButton)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.centerXAnchor.constraint(equalTo: deleteView.centerXAnchor).isActive = true
        deleteButton.centerYAnchor.constraint(equalTo: deleteView.centerYAnchor).isActive = true

        //add gesture recognizers to barView
        if let barView = gameFieldView.subviews.first(where: {$0.restorationIdentifier == "barView"}){
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapCell))
            barView.addGestureRecognizer(tapRecognizer)
            
            let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeCellLeft))
            swipeLeftRecognizer.delegate = self
            swipeLeftRecognizer.direction = .left
            
            let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeCellRight))
            swipeRightRecognizer.delegate = self
            swipeRightRecognizer.direction = .right
            
            if #available(iOS 13.4, *) {
                let pointerInteraction = UIPointerInteraction()
                barView.addInteraction(pointerInteraction)
            }
        }

        
        if(editingIsActive && !setOfSelectedCellIndizes.contains(indexPath.item)){
            cell.contentView.alpha = 0.25
        }
        else{
            cell.contentView.alpha = 1
        }
        
        return cell
    }
    
    
    
    // MARK: Gestures inside Cells

    // allow simultaniously gesture recognizers
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if(gestureRecognizer is UISwipeGestureRecognizer){
            return true
        }
        return false
    }

    // swipe cell left
    @objc func swipeCellLeft(sender: UISwipeGestureRecognizer){
        presentedViewController?.dismiss(animated: true, completion: nil)
        if let barView = sender.view?.superview{
            moveViewLeft(gameFieldView: barView)
        }
    }

    // move cell content left and show buttons to research and delete
    func moveViewLeft(gameFieldView: UIView){
        if let shadowView = gameFieldView.superview?.subviews.first(where: {$0.restorationIdentifier == "shadowView"}), let curtainView = gameFieldView.superview?.subviews.first(where: {$0.restorationIdentifier == "curtainView"}), let deleteView = gameFieldView.subviews.first(where: {$0.restorationIdentifier == "deleteView"}){
            if(gameFieldView.tag == 1){
                gameFieldView.tag = -1
                curtainView.alpha = 1
                UIView.animate(withDuration: 0.5, animations: {
                    for subView in gameFieldView.subviews{
                        subView.frame.origin.x -= 2*self.widthOfLabel+smallSpaceBetweenTiles
                    }
                    deleteView.frame.origin.x += self.widthOfLabel
                    shadowView.alpha = 1
                })
            }
        }
    }
    
    // swipe cell right
    @objc func swipeCellRight(sender: UISwipeGestureRecognizer){
        if let barView = sender.view?.superview{
            moveViewRight(gameFieldView: barView)
        }
    }
    
    // move cell content right and hide buttons to research and delete
    func moveViewRight(gameFieldView: UIView){
        if let shadowView = gameFieldView.superview?.subviews.first(where: {$0.restorationIdentifier == "shadowView"}), let curtainView = gameFieldView.superview?.subviews.first(where: {$0.restorationIdentifier == "curtainView"}), let deleteView = gameFieldView.subviews.first(where: {$0.restorationIdentifier == "deleteView"}){
            if(gameFieldView.tag == -1){
                gameFieldView.tag = 1
                UIView.animate(withDuration: 0.5, animations: {
                    for subView in gameFieldView.subviews{
                        subView.frame.origin.x += 2*self.widthOfLabel+smallSpaceBetweenTiles
                    }
                    deleteView.frame.origin.x -= self.widthOfLabel
                }, completion: {_ in
                    shadowView.alpha = 0
                    curtainView.alpha = 0
                })
            }
        }
    }
    
    
    
    var setOfSelectedCellIndizes : Set<Int> = []
    
    // tap cell
    @objc func tapCell(sender: UITapGestureRecognizer){
        // show popover with research and delete button
        if let gameFieldView = sender.view?.superview{
            if(gameFieldView.tag == 1){
                
                
         
                if let currentIndexPath = archiveCollectionView.indexPathForItem(at: sender.location(in: archiveCollectionView)){
                    
                    if(editingIsActive){

                        if(!setOfSelectedCellIndizes.contains(currentIndexPath.item)){
                            setOfSelectedCellIndizes.insert(currentIndexPath.item)
                            archiveCollectionView.cellForItem(at: currentIndexPath)!.contentView.alpha = 1
                        }
                        else{
                            setOfSelectedCellIndizes.remove(currentIndexPath.item)
                            archiveCollectionView.cellForItem(at: currentIndexPath)!.contentView.alpha = 0.2
                        }
                        
                    }
                    
                    else{
                        
                        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "cellOptionVC")
                        
                        vc.modalPresentationStyle = .popover
                        vc.presentationController?.delegate = self
                        vc.preferredContentSize = vc.view.systemLayoutSizeFitting(
                            UIView.layoutFittingCompressedSize
                        )
                        vc.popoverPresentationController?.sourceView = sender.view
                        vc.popoverPresentationController?.sourceRect = sender.view!.bounds
                        vc.popoverPresentationController?.permittedArrowDirections = [.left, .right]
                        vc.popoverPresentationController?.canOverlapSourceViewRect = true
                        
//                        if let researchButton = vc.view.subviews.first(where: {$0.restorationIdentifier == "exploreView"})?.subviews.first as? UIButton{
//                            researchButton.tag = -currentIndexPath.item
//                            researchButton.addTarget(self, action: #selector(researchCellByPopoverButton), for: .touchUpInside)
//                        }
                        for researchButton in vc.view.subviews.first(where: {$0.restorationIdentifier == "exploreView"})?.subviews as! [UIButton]{
                            researchButton.tag = -currentIndexPath.item
                            researchButton.addTarget(self, action: #selector(researchCellByPopoverButton), for: .touchUpInside)
                        }

                        for removeButton in vc.view.subviews.first(where: {$0.restorationIdentifier == "removeView"})?.subviews as! [UIButton]{
                            removeButton.tag = -currentIndexPath.item
                            removeButton.addTarget(self, action: #selector(removeCellByPopoverButton), for: .touchUpInside)
                        }
                        for clipboardButton in vc.view.subviews.first(where: {$0.restorationIdentifier == "screenshotView"})?.subviews as! [UIButton]{
                            clipboardButton.tag = -currentIndexPath.item
                            clipboardButton.addTarget(self, action: #selector(clipboardCell), for: .touchUpInside)
                        }
                        if let dismissButton = vc.view.subviews.first(where: {$0.restorationIdentifier == "buttonView"})?.subviews.first as? UIButton{
                            dismissButton.addTarget(self, action: #selector(dismissPopover), for: .touchUpInside)
                        }
                        self.present(vc, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    // make button for dismissing visible if popover is shown on small screens
    func presentationController(_ presentationController: UIPresentationController, willPresentWithAdaptiveStyle style: UIModalPresentationStyle, transitionCoordinator: UIViewControllerTransitionCoordinator?) {
        if let constraint = presentationController.presentedViewController.view.subviews.first(where: {$0.restorationIdentifier=="buttonView"})?.constraints.first(where: {$0.firstAttribute == .height}){
            if(style != .formSheet){
                constraint.constant = 0
            }
            else{
                constraint.constant = 60
                
            }
            presentationController.presentedViewController.view.layoutSubviews()
        }
    }
    @objc func dismissPopover(){
        self.presentedViewController?.dismiss(animated: true, completion: nil)
    }
    
    
    
    // MARK: Research Cells

    func researchCellByIndex(index: Int){
        referenceArchiveEntry = listOfArchiveEntries[index]
        
        let researchVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "researchVC") as! GameResearchViewController
        self.navigationController?.show(researchVC, sender: self)
    }
    
    @objc func researchCellByPopoverButton(sender: UIButton){
        self.presentedViewController?.dismiss(animated: false, completion: {
            self.researchCellByIndex(index: -sender.tag)
        })
    }
    
    @objc func researchCellBySwipeButton(sender: UIButton){
        if let currentIndexPath = archiveCollectionView.indexPathForItem(at: sender.convert(.zero, to: archiveCollectionView))?.item{
            researchCellByIndex(index: currentIndexPath)
        }
    }
    
    
    
    // MARK: Deleting Cells
    
    @objc func removeCellBySwipeButton(sender: UIButton){
        if let currentIndexPath = archiveCollectionView.indexPathForItem(at: sender.convert(.zero, to: archiveCollectionView))?.item{
            removeCellByIndex(index: currentIndexPath)
        }
    }
    @IBOutlet weak var trashButton: UIBarButtonItem!
    
    @IBAction func pressTrashButton(_ sender: UIBarButtonItem) {
        let alertVC = UIAlertController(title: NSLocalizedString("deleteAlert", comment: "Delete all games?"), message: NSLocalizedString("deleteAlertText", comment: "Do you really want to delete all games?"), preferredStyle: .alert)
        alertVC.view.tintColor = exampleColor
        alertVC.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
        alertVC.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "Delete"), style: .destructive, handler: { _ in
            listOfArchiveEntries = []
            saveArchive()
            self.archiveCollectionView.reloadData()
        }))
        self.present(alertVC, animated: true)
    }

    @objc func removeCellByPopoverButton(sender: UIButton){
        self.presentedViewController?.dismiss(animated: false, completion: {
            self.removeCellByIndex(index: -sender.tag)
        })
    }

    @objc func clipboardCell(sender: UIButton){
        clipbordCellByIndex(index: -sender.tag)
    }
    
    func clipbordCellByIndex(index: Int){
        let renderer = UIGraphicsImageRenderer(bounds: archiveCollectionView.cellForItem(at: IndexPath(row: index, section: 0))!.convert(archiveCollectionView.cellForItem(at: IndexPath(row: index, section: 0))!.bounds, to: archiveCollectionView))
        let image = renderer.image { rendererContext in
            archiveCollectionView.layer.render(in: rendererContext.cgContext)
        }
        let passPort = UIPasteboard.general
        passPort.image = image
        let snapshotView = UIView(frame: archiveCollectionView.cellForItem(at: IndexPath(row: index, section: 0))!.convert(archiveCollectionView.cellForItem(at: IndexPath(row: index, section: 0))!.bounds, to: view))
        view.addSubview(snapshotView)
        snapshotView.backgroundColor = .systemBackground
        UIView.animate(withDuration: 0.5, animations: {
            snapshotView.alpha = 0
        }) { _ in
            snapshotView.removeFromSuperview()
        }
    }
    
    
    
    func removeCellByIndex(index: Int){

        archiveCollectionView.cellForItem(at: IndexPath(item: index, section: 0))?.alpha = 0.5

        let alertVC = UIAlertController(title: NSLocalizedString("deleteAlertSingle", comment: "Delete game?"), message: String(format: NSLocalizedString("deleteAlertTextSingle", comment: "Do you really want to delete game %d?"), index+1), preferredStyle: .alert)
        alertVC.view.tintColor = exampleColor
        alertVC.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel, handler: { _ in
            self.archiveCollectionView.cellForItem(at: IndexPath(item: index, section: 0))?.alpha = 1
        }))
        alertVC.addAction(UIAlertAction(title: NSLocalizedString("delete", comment: "Delete"), style: .destructive, handler: { _ in
            listOfArchiveEntries.remove(at: index)
            saveArchive()
            self.archiveCollectionView.performBatchUpdates({
                self.archiveCollectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }, completion: {_ in
                self.archiveCollectionView.reloadData()
            })
        }))
        self.present(alertVC, animated: true)
    }
    

    
    // MARK: Movement of Cells
    
    // allow to move cells
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // enable movement
//    @objc func handleLongGesture(sender: UILongPressGestureRecognizer){
//
//        if(!editingIsActive){
//            switch(sender.state){
//
//            case .began:
//
//                guard let selectedIndexPath = archiveCollectionView.indexPathForItem(at: sender.location(in: archiveCollectionView))
//                else{
//                    break
//                }
//                archiveCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
//
//                if let barView = archiveCollectionView.cellForItem(at: selectedIndexPath)?.contentView.subviews.first(where: {$0.restorationIdentifier == "gameFieldView"}){
//                    moveViewRight(gameFieldView: barView)
//                }
//            case .changed:
//                archiveCollectionView.updateInteractiveMovementTargetPosition(sender.location(in: sender.view!))
//            case .ended:
//                archiveCollectionView.endInteractiveMovement()
//
//            default:
//                archiveCollectionView.cancelInteractiveMovement()
//            }
//        }
//    }
    
//    var offsetForCollectionViewCellBeingMoved: CGPoint = .zero
    
//    func offsetOfTouchFrom(recognizer: UIGestureRecognizer, inCell cell: UICollectionViewCell) -> CGPoint {
//
//        let locationOfTouchInCell = recognizer.location(in: cell)
//
//        let cellCenterX = cell.frame.width / 2
//        let cellCenterY = cell.frame.height / 2
//
//        let cellCenter = CGPoint(x: cellCenterX, y: cellCenterY)
//
//        var offSetPoint = CGPoint.zero
//
//        offSetPoint.y = cellCenter.y - locationOfTouchInCell.y
//        offSetPoint.x = cellCenter.x - locationOfTouchInCell.x
//
//        return offSetPoint
//
//    }
    
    
    
    // change cells when moved
    /*
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let archiveEntryAtSourceIndex = listOfArchiveEntries[sourceIndexPath.item]
        listOfArchiveEntries.remove(at: sourceIndexPath.item)
        listOfArchiveEntries.insert(archiveEntryAtSourceIndex, at: destinationIndexPath.item)
        saveArchive()
        collectionView.reloadData()
    }
     */

    //reorder all cells, depending on length of bar
    var orderingIsAscent = Bool(true)
    @IBAction func pressReorderingButton(_ sender: UIBarButtonItem) {
        let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {orderingIsAscent ? $0.listOfColors.count < $1.listOfColors.count : $0.listOfColors.count > $1.listOfColors.count})
        orderingIsAscent = !orderingIsAscent
            for i in 0..<orderedListOfArchiveEntries.count{
                if let j = listOfArchiveEntries[i..<listOfArchiveEntries.count] .firstIndex(where: {$0 == orderedListOfArchiveEntries[i]}){
                    archiveCollectionView.performBatchUpdates({
                        archiveCollectionView.moveItem(at: IndexPath(row: j, section: 0), to: IndexPath(row: i, section: 0))
                    }, completion: {_ in
                        self.archiveCollectionView.reloadData()
                    })

                    let archiveEntryAtSourceIndex = listOfArchiveEntries[j]
                    listOfArchiveEntries.remove(at: j)
                    listOfArchiveEntries.insert(archiveEntryAtSourceIndex, at: i)
                }
            }
        saveArchive()
    }
    

    
    // MARK: Sharing
    
    
    @IBOutlet weak var pdfButton: UIBarButtonItem!
    @IBOutlet weak var editButton: UIBarButtonItem!
    
    @IBOutlet weak var shareButton: UIBarButtonItem!
    var editingIsActive = Bool(false)
    @IBAction func pressEditButton(_ sender: UIBarButtonItem) {
        
        self.presentedViewController?.dismiss(animated: true)
        if(!editingIsActive){
            setOfSelectedCellIndizes = []
            sender.image = UIImage(systemName: "ellipsis.circle.fill")
            shareButton.image = UIImage(systemName: "square.and.arrow.up.fill")
            pdfButton.image = UIImage(systemName: "doc.text.fill")
            
            self.navigationController?.navigationBar.backItem?.backBarButtonItem?.isEnabled = false
            self.navigationController?.navigationBar.topItem?.rightBarButtonItem?.isEnabled = false
            numberModeSegmentControl.isEnabled = false
            trashButton.isEnabled = false
            

        }
        else{
            sender.image = UIImage(systemName: "ellipsis.circle")
            shareButton.image = UIImage(systemName: "square.and.arrow.up")
            pdfButton.image = UIImage(systemName: "doc.text")
            
            self.navigationController?.navigationBar.backItem?.backBarButtonItem?.isEnabled = true
            self.navigationController?.navigationBar.topItem?.rightBarButtonItem?.isEnabled = true
            numberModeSegmentControl.isEnabled = true
            trashButton.isEnabled = true


        }
        editingIsActive = !editingIsActive
        archiveCollectionView.reloadData()
    }
    
    @IBAction func pressShareButton(_ sender: UIBarButtonItem) {

        self.presentedViewController?.dismiss(animated: true)
        
        let date = Date()
        let urlString = "\(UIDevice.current.name)_\(dateFormatterForFileName.string(from: date)).nim".replacingOccurrences(of: " ", with: "-")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            
            if(UserDefaults.standard.value(forKey: "settings_namesAreAnonymized") == nil){
                UserDefaults.standard.set(true, forKey: "settings_namesAreAnonymized")
            }
            namesAreAnonymized = UserDefaults.standard.bool(forKey: "settings_namesAreAnonymized")

            
            var exportableListOfArchiveEntries : [ArchiveEntry] = []
            for inde in setOfSelectedCellIndizes{
                exportableListOfArchiveEntries.append(listOfArchiveEntries[inde])
            }
            if(!editingIsActive){
                exportableListOfArchiveEntries = listOfArchiveEntries
            }
            var newListOfArchiveEntries : [ArchiveEntry] = []

            if(namesAreAnonymized){
                for archiveEntry in exportableListOfArchiveEntries{
                    let newArchiveEntry = ArchiveEntry(listOfColors: archiveEntry.listOfColors, winMode: archiveEntry.winMode, numberOfMaximalCircles: archiveEntry.numberOfMaximalCircles, leftPlayerColor: archiveEntry.leftPlayerColor, rightPlayerColor: archiveEntry.rightPlayerColor, leftPlayerName: "", rightPlayerName: "", gameNumber: archiveEntry.gameNumber)
                    newListOfArchiveEntries.append(newArchiveEntry)
                }
            }
            else{
                newListOfArchiveEntries = exportableListOfArchiveEntries
            }
            
            
            let data = try encoder.encode(newListOfArchiveEntries)
            try data.write(to: url)
            
            #if targetEnvironment(macCatalyst)
            if #available(iOS 14, *) {
                let controller = UIDocumentPickerViewController(forExporting: [url])
                self.present(controller, animated: true)
            } else {
                let controller = UIDocumentPickerViewController(url: url, in: .exportToService)
                self.present(controller, animated: true)
            }
            #else
            print("iPad")
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = sender
            self.present(activityVC, animated: true)
            #endif
            
        }
        catch {
        }
    }
    
    
    @IBAction func pressDocumentButton(_ sender: UIBarButtonItem) {
        
        
        self.presentedViewController?.dismiss(animated: true)

        
        // pathes createt with https://swiftvg.mike-engel.com
        
        let thumpUp = UIBezierPath()
        thumpUp.move(to: CGPoint(x: 0, y: 59.47))
        thumpUp.addCurve(to: CGPoint(x: 2.54, y: 71.51), controlPoint1: CGPoint(x: 0, y: 63.83), controlPoint2: CGPoint(x: 0.85, y: 67.85))
        thumpUp.addCurve(to: CGPoint(x: 9.37, y: 80.3), controlPoint1: CGPoint(x: 4.23, y: 75.17), controlPoint2: CGPoint(x: 6.51, y: 78.1))
        thumpUp.addCurve(to: CGPoint(x: 18.85, y: 83.59), controlPoint1: CGPoint(x: 12.24, y: 82.5), controlPoint2: CGPoint(x: 15.4, y: 83.59))
        thumpUp.addLine(to: CGPoint(x: 31.69, y: 83.59))
        thumpUp.addCurve(to: CGPoint(x: 40.26, y: 86.82), controlPoint1: CGPoint(x: 34.29, y: 84.96), controlPoint2: CGPoint(x: 37.15, y: 86.04))
        thumpUp.addCurve(to: CGPoint(x: 50.2, y: 87.99), controlPoint1: CGPoint(x: 43.37, y: 87.6), controlPoint2: CGPoint(x: 46.68, y: 87.99))
        thumpUp.addLine(to: CGPoint(x: 55.57, y: 87.99))
        thumpUp.addCurve(to: CGPoint(x: 62.23, y: 87.77), controlPoint1: CGPoint(x: 57.98, y: 87.99), controlPoint2: CGPoint(x: 60.2, y: 87.92))
        thumpUp.addCurve(to: CGPoint(x: 67.38, y: 87.01), controlPoint1: CGPoint(x: 64.27, y: 87.62), controlPoint2: CGPoint(x: 65.98, y: 87.37))
        thumpUp.addCurve(to: CGPoint(x: 74, y: 83.25), controlPoint1: CGPoint(x: 70.18, y: 86.33), controlPoint2: CGPoint(x: 72.39, y: 85.07))
        thumpUp.addCurve(to: CGPoint(x: 76.42, y: 76.81), controlPoint1: CGPoint(x: 75.61, y: 81.43), controlPoint2: CGPoint(x: 76.42, y: 79.28))
        thumpUp.addCurve(to: CGPoint(x: 76.07, y: 74.22), controlPoint1: CGPoint(x: 76.42, y: 75.93), controlPoint2: CGPoint(x: 76.3, y: 75.07))
        thumpUp.addCurve(to: CGPoint(x: 80.18, y: 65.92), controlPoint1: CGPoint(x: 78.81, y: 72.07), controlPoint2: CGPoint(x: 80.18, y: 69.3))
        thumpUp.addCurve(to: CGPoint(x: 79.39, y: 61.62), controlPoint1: CGPoint(x: 80.18, y: 64.36), controlPoint2: CGPoint(x: 79.92, y: 62.92))
        thumpUp.addCurve(to: CGPoint(x: 81.42, y: 58.23), controlPoint1: CGPoint(x: 80.27, y: 60.64), controlPoint2: CGPoint(x: 80.95, y: 59.51))
        thumpUp.addCurve(to: CGPoint(x: 82.13, y: 54.2), controlPoint1: CGPoint(x: 81.89, y: 56.94), controlPoint2: CGPoint(x: 82.13, y: 55.6))
        thumpUp.addCurve(to: CGPoint(x: 80.96, y: 49.07), controlPoint1: CGPoint(x: 82.13, y: 52.31), controlPoint2: CGPoint(x: 81.74, y: 50.6))
        thumpUp.addCurve(to: CGPoint(x: 82.62, y: 43.02), controlPoint1: CGPoint(x: 82.06, y: 47.38), controlPoint2: CGPoint(x: 82.62, y: 45.36))
        thumpUp.addCurve(to: CGPoint(x: 79.52, y: 35.35), controlPoint1: CGPoint(x: 82.62, y: 39.99), controlPoint2: CGPoint(x: 81.58, y: 37.43))
        thumpUp.addCurve(to: CGPoint(x: 71.92, y: 32.23), controlPoint1: CGPoint(x: 77.45, y: 33.27), controlPoint2: CGPoint(x: 74.92, y: 32.23))
        thumpUp.addLine(to: CGPoint(x: 57.13, y: 32.23))
        thumpUp.addCurve(to: CGPoint(x: 56.47, y: 32.06), controlPoint1: CGPoint(x: 56.87, y: 32.23), controlPoint2: CGPoint(x: 56.65, y: 32.17))
        thumpUp.addCurve(to: CGPoint(x: 56.2, y: 31.49), controlPoint1: CGPoint(x: 56.29, y: 31.94), controlPoint2: CGPoint(x: 56.2, y: 31.75))
        thumpUp.addCurve(to: CGPoint(x: 57.2, y: 27.51), controlPoint1: CGPoint(x: 56.2, y: 30.49), controlPoint2: CGPoint(x: 56.53, y: 29.16))
        thumpUp.addCurve(to: CGPoint(x: 59.5, y: 22.05), controlPoint1: CGPoint(x: 57.87, y: 25.87), controlPoint2: CGPoint(x: 58.63, y: 24.05))
        thumpUp.addCurve(to: CGPoint(x: 61.79, y: 15.84), controlPoint1: CGPoint(x: 60.36, y: 20.04), controlPoint2: CGPoint(x: 61.12, y: 17.98))
        thumpUp.addCurve(to: CGPoint(x: 62.79, y: 9.67), controlPoint1: CGPoint(x: 62.46, y: 13.71), controlPoint2: CGPoint(x: 62.79, y: 11.65))
        thumpUp.addCurve(to: CGPoint(x: 60.16, y: 2.73), controlPoint1: CGPoint(x: 62.79, y: 6.87), controlPoint2: CGPoint(x: 61.91, y: 4.56))
        thumpUp.addCurve(to: CGPoint(x: 53.47, y: 0), controlPoint1: CGPoint(x: 58.4, y: 0.91), controlPoint2: CGPoint(x: 56.17, y: 0))
        thumpUp.addCurve(to: CGPoint(x: 48.32, y: 1.64), controlPoint1: CGPoint(x: 51.48, y: 0), controlPoint2: CGPoint(x: 49.76, y: 0.55))
        thumpUp.addCurve(to: CGPoint(x: 44.19, y: 7.03), controlPoint1: CGPoint(x: 46.87, y: 2.73), controlPoint2: CGPoint(x: 45.49, y: 4.52))
        thumpUp.addCurve(to: CGPoint(x: 40.43, y: 13.7), controlPoint1: CGPoint(x: 43.02, y: 9.24), controlPoint2: CGPoint(x: 41.76, y: 11.47))
        thumpUp.addCurve(to: CGPoint(x: 36.04, y: 20.51), controlPoint1: CGPoint(x: 39.1, y: 15.93), controlPoint2: CGPoint(x: 37.63, y: 18.2))
        thumpUp.addCurve(to: CGPoint(x: 30.84, y: 27.64), controlPoint1: CGPoint(x: 34.44, y: 22.82), controlPoint2: CGPoint(x: 32.71, y: 25.2))
        thumpUp.addCurve(to: CGPoint(x: 24.71, y: 35.25), controlPoint1: CGPoint(x: 28.96, y: 30.08), controlPoint2: CGPoint(x: 26.92, y: 32.62))
        thumpUp.addLine(to: CGPoint(x: 17.43, y: 35.25))
        thumpUp.addCurve(to: CGPoint(x: 8.62, y: 38.55), controlPoint1: CGPoint(x: 14.18, y: 35.25), controlPoint2: CGPoint(x: 11.24, y: 36.35))
        thumpUp.addCurve(to: CGPoint(x: 2.34, y: 47.36), controlPoint1: CGPoint(x: 6, y: 40.75), controlPoint2: CGPoint(x: 3.91, y: 43.68))
        thumpUp.addCurve(to: CGPoint(x: 0, y: 59.47), controlPoint1: CGPoint(x: 0.78, y: 51.04), controlPoint2: CGPoint(x: 0, y: 55.08))
        thumpUp.close()
        thumpUp.move(to: CGPoint(x: 23.34, y: 59.23))
        thumpUp.addCurve(to: CGPoint(x: 24.93, y: 48.46), controlPoint1: CGPoint(x: 23.34, y: 55.09), controlPoint2: CGPoint(x: 23.87, y: 51.51))
        thumpUp.addCurve(to: CGPoint(x: 30.42, y: 38.67), controlPoint1: CGPoint(x: 25.98, y: 45.42), controlPoint2: CGPoint(x: 27.82, y: 42.16))
        thumpUp.addCurve(to: CGPoint(x: 40.23, y: 25.78), controlPoint1: CGPoint(x: 33.32, y: 34.8), controlPoint2: CGPoint(x: 36.59, y: 30.5))
        thumpUp.addCurve(to: CGPoint(x: 50.05, y: 10.01), controlPoint1: CGPoint(x: 43.88, y: 21.06), controlPoint2: CGPoint(x: 47.15, y: 15.8))
        thumpUp.addCurve(to: CGPoint(x: 51.93, y: 7.2), controlPoint1: CGPoint(x: 50.77, y: 8.58), controlPoint2: CGPoint(x: 51.39, y: 7.64))
        thumpUp.addCurve(to: CGPoint(x: 53.71, y: 6.54), controlPoint1: CGPoint(x: 52.47, y: 6.76), controlPoint2: CGPoint(x: 53.06, y: 6.54))
        thumpUp.addCurve(to: CGPoint(x: 55.52, y: 7.35), controlPoint1: CGPoint(x: 54.46, y: 6.54), controlPoint2: CGPoint(x: 55.06, y: 6.81))
        thumpUp.addCurve(to: CGPoint(x: 56.2, y: 9.67), controlPoint1: CGPoint(x: 55.97, y: 7.89), controlPoint2: CGPoint(x: 56.2, y: 8.66))
        thumpUp.addCurve(to: CGPoint(x: 55.22, y: 14.82), controlPoint1: CGPoint(x: 56.2, y: 11.23), controlPoint2: CGPoint(x: 55.88, y: 12.95))
        thumpUp.addCurve(to: CGPoint(x: 52.93, y: 20.58), controlPoint1: CGPoint(x: 54.57, y: 16.69), controlPoint2: CGPoint(x: 53.81, y: 18.61))
        thumpUp.addCurve(to: CGPoint(x: 50.63, y: 26.34), controlPoint1: CGPoint(x: 52.05, y: 22.55), controlPoint2: CGPoint(x: 51.29, y: 24.47))
        thumpUp.addCurve(to: CGPoint(x: 49.66, y: 31.49), controlPoint1: CGPoint(x: 49.98, y: 28.21), controlPoint2: CGPoint(x: 49.66, y: 29.93))
        thumpUp.addCurve(to: CGPoint(x: 52.12, y: 36.84), controlPoint1: CGPoint(x: 49.66, y: 33.77), controlPoint2: CGPoint(x: 50.48, y: 35.56))
        thumpUp.addCurve(to: CGPoint(x: 58.11, y: 38.77), controlPoint1: CGPoint(x: 53.77, y: 38.13), controlPoint2: CGPoint(x: 55.76, y: 38.77))
        thumpUp.addLine(to: CGPoint(x: 71.92, y: 38.77))
        thumpUp.addCurve(to: CGPoint(x: 74.85, y: 39.99), controlPoint1: CGPoint(x: 73.1, y: 38.77), controlPoint2: CGPoint(x: 74.07, y: 39.18))
        thumpUp.addCurve(to: CGPoint(x: 76.03, y: 43.02), controlPoint1: CGPoint(x: 75.63, y: 40.8), controlPoint2: CGPoint(x: 76.03, y: 41.81))
        thumpUp.addCurve(to: CGPoint(x: 73.83, y: 47.56), controlPoint1: CGPoint(x: 76.03, y: 44.58), controlPoint2: CGPoint(x: 75.29, y: 46.09))
        thumpUp.addCurve(to: CGPoint(x: 73.32, y: 48.56), controlPoint1: CGPoint(x: 73.5, y: 47.88), controlPoint2: CGPoint(x: 73.33, y: 48.22))
        thumpUp.addCurve(to: CGPoint(x: 73.63, y: 49.56), controlPoint1: CGPoint(x: 73.3, y: 48.9), controlPoint2: CGPoint(x: 73.41, y: 49.24))
        thumpUp.addCurve(to: CGPoint(x: 75.1, y: 52.12), controlPoint1: CGPoint(x: 74.32, y: 50.6), controlPoint2: CGPoint(x: 74.8, y: 51.46))
        thumpUp.addCurve(to: CGPoint(x: 75.54, y: 54.2), controlPoint1: CGPoint(x: 75.39, y: 52.79), controlPoint2: CGPoint(x: 75.54, y: 53.48))
        thumpUp.addCurve(to: CGPoint(x: 72.85, y: 58.89), controlPoint1: CGPoint(x: 75.54, y: 55.96), controlPoint2: CGPoint(x: 74.64, y: 57.52))
        thumpUp.addCurve(to: CGPoint(x: 71.92, y: 60.18), controlPoint1: CGPoint(x: 72.4, y: 59.24), controlPoint2: CGPoint(x: 72.09, y: 59.68))
        thumpUp.addCurve(to: CGPoint(x: 72.12, y: 61.77), controlPoint1: CGPoint(x: 71.76, y: 60.69), controlPoint2: CGPoint(x: 71.83, y: 61.21))
        thumpUp.addCurve(to: CGPoint(x: 73.22, y: 64.06), controlPoint1: CGPoint(x: 72.61, y: 62.78), controlPoint2: CGPoint(x: 72.97, y: 63.54))
        thumpUp.addCurve(to: CGPoint(x: 73.58, y: 65.92), controlPoint1: CGPoint(x: 73.46, y: 64.58), controlPoint2: CGPoint(x: 73.58, y: 65.2))
        thumpUp.addCurve(to: CGPoint(x: 69.43, y: 70.95), controlPoint1: CGPoint(x: 73.58, y: 67.77), controlPoint2: CGPoint(x: 72.2, y: 69.45))
        thumpUp.addCurve(to: CGPoint(x: 68.6, y: 71.83), controlPoint1: CGPoint(x: 68.98, y: 71.18), controlPoint2: CGPoint(x: 68.7, y: 71.47))
        thumpUp.addCurve(to: CGPoint(x: 68.7, y: 72.9), controlPoint1: CGPoint(x: 68.51, y: 72.18), controlPoint2: CGPoint(x: 68.54, y: 72.54))
        thumpUp.addCurve(to: CGPoint(x: 69.65, y: 75.49), controlPoint1: CGPoint(x: 69.22, y: 74.24), controlPoint2: CGPoint(x: 69.54, y: 75.1))
        thumpUp.addCurve(to: CGPoint(x: 69.82, y: 76.81), controlPoint1: CGPoint(x: 69.77, y: 75.88), controlPoint2: CGPoint(x: 69.82, y: 76.32))
        thumpUp.addCurve(to: CGPoint(x: 65.82, y: 80.62), controlPoint1: CGPoint(x: 69.82, y: 78.66), controlPoint2: CGPoint(x: 68.49, y: 79.93))
        thumpUp.addCurve(to: CGPoint(x: 61.47, y: 81.25), controlPoint1: CGPoint(x: 64.68, y: 80.91), controlPoint2: CGPoint(x: 63.23, y: 81.12))
        thumpUp.addCurve(to: CGPoint(x: 55.57, y: 81.4), controlPoint1: CGPoint(x: 59.72, y: 81.38), controlPoint2: CGPoint(x: 57.75, y: 81.43))
        thumpUp.addLine(to: CGPoint(x: 50.24, y: 81.35))
        thumpUp.addCurve(to: CGPoint(x: 36.13, y: 78.47), controlPoint1: CGPoint(x: 44.87, y: 81.32), controlPoint2: CGPoint(x: 40.17, y: 80.35))
        thumpUp.addCurve(to: CGPoint(x: 26.71, y: 70.68), controlPoint1: CGPoint(x: 32.1, y: 76.58), controlPoint2: CGPoint(x: 28.96, y: 73.98))
        thumpUp.addCurve(to: CGPoint(x: 23.34, y: 59.23), controlPoint1: CGPoint(x: 24.46, y: 67.37), controlPoint2: CGPoint(x: 23.34, y: 63.56))
        thumpUp.close()
        thumpUp.move(to: CGPoint(x: 6.59, y: 59.47))
        thumpUp.addCurve(to: CGPoint(x: 8.11, y: 50.66), controlPoint1: CGPoint(x: 6.59, y: 56.28), controlPoint2: CGPoint(x: 7.1, y: 53.34))
        thumpUp.addCurve(to: CGPoint(x: 12.09, y: 44.24), controlPoint1: CGPoint(x: 9.11, y: 47.97), controlPoint2: CGPoint(x: 10.44, y: 45.83))
        thumpUp.addCurve(to: CGPoint(x: 17.43, y: 41.85), controlPoint1: CGPoint(x: 13.73, y: 42.64), controlPoint2: CGPoint(x: 15.51, y: 41.85))
        thumpUp.addCurve(to: CGPoint(x: 18.95, y: 41.85), controlPoint1: CGPoint(x: 17.92, y: 41.85), controlPoint2: CGPoint(x: 18.42, y: 41.85))
        thumpUp.addCurve(to: CGPoint(x: 20.51, y: 41.85), controlPoint1: CGPoint(x: 19.47, y: 41.85), controlPoint2: CGPoint(x: 19.99, y: 41.85))
        thumpUp.addCurve(to: CGPoint(x: 17.65, y: 49.98), controlPoint1: CGPoint(x: 19.21, y: 44.42), controlPoint2: CGPoint(x: 18.25, y: 47.13))
        thumpUp.addCurve(to: CGPoint(x: 16.75, y: 59.08), controlPoint1: CGPoint(x: 17.05, y: 52.82), controlPoint2: CGPoint(x: 16.75, y: 55.86))
        thumpUp.addCurve(to: CGPoint(x: 18.46, y: 68.85), controlPoint1: CGPoint(x: 16.75, y: 62.57), controlPoint2: CGPoint(x: 17.32, y: 65.82))
        thumpUp.addCurve(to: CGPoint(x: 23.39, y: 77), controlPoint1: CGPoint(x: 19.6, y: 71.88), controlPoint2: CGPoint(x: 21.24, y: 74.59))
        thumpUp.addCurve(to: CGPoint(x: 21.12, y: 77), controlPoint1: CGPoint(x: 22.64, y: 77), controlPoint2: CGPoint(x: 21.88, y: 77))
        thumpUp.addCurve(to: CGPoint(x: 18.85, y: 77), controlPoint1: CGPoint(x: 20.35, y: 77), controlPoint2: CGPoint(x: 19.6, y: 77))
        thumpUp.addCurve(to: CGPoint(x: 12.79, y: 74.61), controlPoint1: CGPoint(x: 16.67, y: 77), controlPoint2: CGPoint(x: 14.65, y: 76.2))
        thumpUp.addCurve(to: CGPoint(x: 8.3, y: 68.21), controlPoint1: CGPoint(x: 10.94, y: 73.01), controlPoint2: CGPoint(x: 9.44, y: 70.88))
        thumpUp.addCurve(to: CGPoint(x: 6.59, y: 59.47), controlPoint1: CGPoint(x: 7.16, y: 65.54), controlPoint2: CGPoint(x: 6.59, y: 62.63))
        thumpUp.close()
        
        
        let filledThumbUp = UIBezierPath()
        filledThumbUp.move(to: CGPoint(x: 0, y: 56.64))
        filledThumbUp.addCurve(to: CGPoint(x: 2.3, y: 67.53), controlPoint1: CGPoint(x: 0, y: 60.58), controlPoint2: CGPoint(x: 0.77, y: 64.21))
        filledThumbUp.addCurve(to: CGPoint(x: 8.55, y: 75.51), controlPoint1: CGPoint(x: 3.82, y: 70.85), controlPoint2: CGPoint(x: 5.91, y: 73.51))
        filledThumbUp.addCurve(to: CGPoint(x: 17.48, y: 78.52), controlPoint1: CGPoint(x: 11.18, y: 77.51), controlPoint2: CGPoint(x: 14.16, y: 78.52))
        filledThumbUp.addLine(to: CGPoint(x: 24.12, y: 78.52))
        filledThumbUp.addCurve(to: CGPoint(x: 16.38, y: 68.73), controlPoint1: CGPoint(x: 20.61, y: 75.85), controlPoint2: CGPoint(x: 18.03, y: 72.58))
        filledThumbUp.addCurve(to: CGPoint(x: 14.01, y: 56.25), controlPoint1: CGPoint(x: 14.74, y: 64.87), controlPoint2: CGPoint(x: 13.95, y: 60.71))
        filledThumbUp.addCurve(to: CGPoint(x: 16.58, y: 43.34), controlPoint1: CGPoint(x: 14.11, y: 51.27), controlPoint2: CGPoint(x: 14.97, y: 46.96))
        filledThumbUp.addCurve(to: CGPoint(x: 21.68, y: 34.57), controlPoint1: CGPoint(x: 18.19, y: 39.71), controlPoint2: CGPoint(x: 19.89, y: 36.78))
        filledThumbUp.addLine(to: CGPoint(x: 15.97, y: 34.57))
        filledThumbUp.addCurve(to: CGPoint(x: 7.86, y: 37.52), controlPoint1: CGPoint(x: 12.97, y: 34.57), controlPoint2: CGPoint(x: 10.27, y: 35.56))
        filledThumbUp.addCurve(to: CGPoint(x: 2.12, y: 45.46), controlPoint1: CGPoint(x: 5.45, y: 39.49), controlPoint2: CGPoint(x: 3.54, y: 42.14))
        filledThumbUp.addCurve(to: CGPoint(x: 0, y: 56.64), controlPoint1: CGPoint(x: 0.71, y: 48.78), controlPoint2: CGPoint(x: 0, y: 52.51))
        filledThumbUp.close()
        filledThumbUp.move(to: CGPoint(x: 19.87, y: 56.35))
        filledThumbUp.addCurve(to: CGPoint(x: 23.44, y: 69.51), controlPoint1: CGPoint(x: 19.78, y: 61.23), controlPoint2: CGPoint(x: 20.96, y: 65.62))
        filledThumbUp.addCurve(to: CGPoint(x: 34.01, y: 78.78), controlPoint1: CGPoint(x: 25.91, y: 73.4), controlPoint2: CGPoint(x: 29.44, y: 76.49))
        filledThumbUp.addCurve(to: CGPoint(x: 50.2, y: 82.28), controlPoint1: CGPoint(x: 38.58, y: 81.08), controlPoint2: CGPoint(x: 43.98, y: 82.24))
        filledThumbUp.addLine(to: CGPoint(x: 55.71, y: 82.32))
        filledThumbUp.addCurve(to: CGPoint(x: 62.45, y: 82.1), controlPoint1: CGPoint(x: 58.32, y: 82.36), controlPoint2: CGPoint(x: 60.56, y: 82.28))
        filledThumbUp.addCurve(to: CGPoint(x: 66.94, y: 81.4), controlPoint1: CGPoint(x: 64.34, y: 81.93), controlPoint2: CGPoint(x: 65.84, y: 81.69))
        filledThumbUp.addCurve(to: CGPoint(x: 71.19, y: 79.27), controlPoint1: CGPoint(x: 68.51, y: 81.01), controlPoint2: CGPoint(x: 69.92, y: 80.3))
        filledThumbUp.addCurve(to: CGPoint(x: 73.1, y: 74.9), controlPoint1: CGPoint(x: 72.46, y: 78.25), controlPoint2: CGPoint(x: 73.1, y: 76.79))
        filledThumbUp.addCurve(to: CGPoint(x: 72.85, y: 72.88), controlPoint1: CGPoint(x: 73.1, y: 74.12), controlPoint2: CGPoint(x: 73.01, y: 73.45))
        filledThumbUp.addCurve(to: CGPoint(x: 72.17, y: 71.34), controlPoint1: CGPoint(x: 72.69, y: 72.31), controlPoint2: CGPoint(x: 72.46, y: 71.79))
        filledThumbUp.addCurve(to: CGPoint(x: 72.41, y: 70.21), controlPoint1: CGPoint(x: 71.84, y: 70.78), controlPoint2: CGPoint(x: 71.92, y: 70.41))
        filledThumbUp.addCurve(to: CGPoint(x: 75.63, y: 67.77), controlPoint1: CGPoint(x: 73.65, y: 69.73), controlPoint2: CGPoint(x: 74.72, y: 68.91))
        filledThumbUp.addCurve(to: CGPoint(x: 77, y: 63.67), controlPoint1: CGPoint(x: 76.55, y: 66.63), controlPoint2: CGPoint(x: 77, y: 65.27))
        filledThumbUp.addCurve(to: CGPoint(x: 75.59, y: 59.13), controlPoint1: CGPoint(x: 77, y: 61.85), controlPoint2: CGPoint(x: 76.53, y: 60.34))
        filledThumbUp.addCurve(to: CGPoint(x: 75.93, y: 57.57), controlPoint1: CGPoint(x: 75.13, y: 58.51), controlPoint2: CGPoint(x: 75.24, y: 57.99))
        filledThumbUp.addCurve(to: CGPoint(x: 78.15, y: 55.2), controlPoint1: CGPoint(x: 76.84, y: 57.05), controlPoint2: CGPoint(x: 77.58, y: 56.26))
        filledThumbUp.addCurve(to: CGPoint(x: 79, y: 51.66), controlPoint1: CGPoint(x: 78.72, y: 54.14), controlPoint2: CGPoint(x: 79, y: 52.96))
        filledThumbUp.addCurve(to: CGPoint(x: 78.56, y: 48.93), controlPoint1: CGPoint(x: 79, y: 50.75), controlPoint2: CGPoint(x: 78.86, y: 49.84))
        filledThumbUp.addCurve(to: CGPoint(x: 77.34, y: 46.83), controlPoint1: CGPoint(x: 78.27, y: 48.01), controlPoint2: CGPoint(x: 77.86, y: 47.31))
        filledThumbUp.addCurve(to: CGPoint(x: 77.49, y: 45.31), controlPoint1: CGPoint(x: 76.79, y: 46.34), controlPoint2: CGPoint(x: 76.84, y: 45.83))
        filledThumbUp.addCurve(to: CGPoint(x: 78.98, y: 43.14), controlPoint1: CGPoint(x: 78.11, y: 44.76), controlPoint2: CGPoint(x: 78.61, y: 44.03))
        filledThumbUp.addCurve(to: CGPoint(x: 79.54, y: 40.14), controlPoint1: CGPoint(x: 79.35, y: 42.24), controlPoint2: CGPoint(x: 79.54, y: 41.24))
        filledThumbUp.addCurve(to: CGPoint(x: 77.54, y: 35.16), controlPoint1: CGPoint(x: 79.54, y: 38.18), controlPoint2: CGPoint(x: 78.87, y: 36.52))
        filledThumbUp.addCurve(to: CGPoint(x: 72.51, y: 33.11), controlPoint1: CGPoint(x: 76.2, y: 33.79), controlPoint2: CGPoint(x: 74.53, y: 33.11))
        filledThumbUp.addLine(to: CGPoint(x: 58.4, y: 33.11))
        filledThumbUp.addCurve(to: CGPoint(x: 54.03, y: 31.81), controlPoint1: CGPoint(x: 56.58, y: 33.11), controlPoint2: CGPoint(x: 55.12, y: 32.67))
        filledThumbUp.addCurve(to: CGPoint(x: 52.39, y: 28.27), controlPoint1: CGPoint(x: 52.94, y: 30.95), controlPoint2: CGPoint(x: 52.39, y: 29.77))
        filledThumbUp.addCurve(to: CGPoint(x: 53.42, y: 23.54), controlPoint1: CGPoint(x: 52.39, y: 26.94), controlPoint2: CGPoint(x: 52.73, y: 25.36))
        filledThumbUp.addCurve(to: CGPoint(x: 55.76, y: 17.72), controlPoint1: CGPoint(x: 54.1, y: 21.71), controlPoint2: CGPoint(x: 54.88, y: 19.78))
        filledThumbUp.addCurve(to: CGPoint(x: 58.11, y: 11.62), controlPoint1: CGPoint(x: 56.64, y: 15.67), controlPoint2: CGPoint(x: 57.42, y: 13.64))
        filledThumbUp.addCurve(to: CGPoint(x: 59.13, y: 5.91), controlPoint1: CGPoint(x: 58.79, y: 9.6), controlPoint2: CGPoint(x: 59.13, y: 7.7))
        filledThumbUp.addCurve(to: CGPoint(x: 57.54, y: 1.56), controlPoint1: CGPoint(x: 59.13, y: 4.05), controlPoint2: CGPoint(x: 58.6, y: 2.6))
        filledThumbUp.addCurve(to: CGPoint(x: 53.56, y: 0), controlPoint1: CGPoint(x: 56.49, y: 0.52), controlPoint2: CGPoint(x: 55.16, y: 0))
        filledThumbUp.addCurve(to: CGPoint(x: 50.17, y: 1.37), controlPoint1: CGPoint(x: 52.13, y: 0), controlPoint2: CGPoint(x: 51, y: 0.46))
        filledThumbUp.addCurve(to: CGPoint(x: 47.75, y: 4.98), controlPoint1: CGPoint(x: 49.34, y: 2.28), controlPoint2: CGPoint(x: 48.54, y: 3.48))
        filledThumbUp.addCurve(to: CGPoint(x: 37.77, y: 20.9), controlPoint1: CGPoint(x: 44.76, y: 10.81), controlPoint2: CGPoint(x: 41.43, y: 16.11))
        filledThumbUp.addCurve(to: CGPoint(x: 27.69, y: 34.13), controlPoint1: CGPoint(x: 34.11, y: 25.68), controlPoint2: CGPoint(x: 30.75, y: 30.09))
        filledThumbUp.addCurve(to: CGPoint(x: 21.92, y: 44.24), controlPoint1: CGPoint(x: 25.11, y: 37.55), controlPoint2: CGPoint(x: 23.19, y: 40.92))
        filledThumbUp.addCurve(to: CGPoint(x: 19.87, y: 56.35), controlPoint1: CGPoint(x: 20.65, y: 47.56), controlPoint2: CGPoint(x: 19.97, y: 51.6))
        filledThumbUp.close()
        
        
        let thumbDown = UIBezierPath()
        thumbDown.move(to: CGPoint(x: 82.62, y: 28.52))
        thumbDown.addCurve(to: CGPoint(x: 80.05, y: 16.48), controlPoint1: CGPoint(x: 82.62, y: 24.15), controlPoint2: CGPoint(x: 81.76, y: 20.14))
        thumbDown.addCurve(to: CGPoint(x: 73.22, y: 7.69), controlPoint1: CGPoint(x: 78.34, y: 12.82), controlPoint2: CGPoint(x: 76.07, y: 9.89))
        thumbDown.addCurve(to: CGPoint(x: 63.72, y: 4.39), controlPoint1: CGPoint(x: 70.37, y: 5.49), controlPoint2: CGPoint(x: 67.2, y: 4.39))
        thumbDown.addLine(to: CGPoint(x: 50.93, y: 4.39))
        thumbDown.addCurve(to: CGPoint(x: 42.36, y: 1.17), controlPoint1: CGPoint(x: 48.32, y: 3.03), controlPoint2: CGPoint(x: 45.47, y: 1.95))
        thumbDown.addCurve(to: CGPoint(x: 32.42, y: 0), controlPoint1: CGPoint(x: 39.25, y: 0.39), controlPoint2: CGPoint(x: 35.94, y: 0))
        thumbDown.addLine(to: CGPoint(x: 27.05, y: 0))
        thumbDown.addCurve(to: CGPoint(x: 20.39, y: 0.22), controlPoint1: CGPoint(x: 24.64, y: 0), controlPoint2: CGPoint(x: 22.42, y: 0.07))
        thumbDown.addCurve(to: CGPoint(x: 15.23, y: 0.98), controlPoint1: CGPoint(x: 18.35, y: 0.37), controlPoint2: CGPoint(x: 16.63, y: 0.62))
        thumbDown.addCurve(to: CGPoint(x: 8.62, y: 4.74), controlPoint1: CGPoint(x: 12.43, y: 1.66), controlPoint2: CGPoint(x: 10.23, y: 2.91))
        thumbDown.addCurve(to: CGPoint(x: 6.2, y: 11.18), controlPoint1: CGPoint(x: 7.01, y: 6.56), controlPoint2: CGPoint(x: 6.2, y: 8.71))
        thumbDown.addCurve(to: CGPoint(x: 6.49, y: 13.77), controlPoint1: CGPoint(x: 6.2, y: 12.06), controlPoint2: CGPoint(x: 6.3, y: 12.92))
        thumbDown.addCurve(to: CGPoint(x: 2.44, y: 22.07), controlPoint1: CGPoint(x: 3.79, y: 15.92), controlPoint2: CGPoint(x: 2.44, y: 18.68))
        thumbDown.addCurve(to: CGPoint(x: 3.22, y: 26.37), controlPoint1: CGPoint(x: 2.44, y: 23.63), controlPoint2: CGPoint(x: 2.7, y: 25.07))
        thumbDown.addCurve(to: CGPoint(x: 1.2, y: 29.76), controlPoint1: CGPoint(x: 2.34, y: 27.34), controlPoint2: CGPoint(x: 1.67, y: 28.48))
        thumbDown.addCurve(to: CGPoint(x: 0.49, y: 33.79), controlPoint1: CGPoint(x: 0.72, y: 31.05), controlPoint2: CGPoint(x: 0.49, y: 32.39))
        thumbDown.addCurve(to: CGPoint(x: 1.66, y: 38.92), controlPoint1: CGPoint(x: 0.49, y: 35.68), controlPoint2: CGPoint(x: 0.88, y: 37.39))
        thumbDown.addCurve(to: CGPoint(x: 0, y: 44.97), controlPoint1: CGPoint(x: 0.55, y: 40.61), controlPoint2: CGPoint(x: 0, y: 42.63))
        thumbDown.addCurve(to: CGPoint(x: 3.1, y: 52.64), controlPoint1: CGPoint(x: 0, y: 48), controlPoint2: CGPoint(x: 1.03, y: 50.55))
        thumbDown.addCurve(to: CGPoint(x: 10.69, y: 55.76), controlPoint1: CGPoint(x: 5.17, y: 54.72), controlPoint2: CGPoint(x: 7.7, y: 55.76))
        thumbDown.addLine(to: CGPoint(x: 25.49, y: 55.76))
        thumbDown.addCurve(to: CGPoint(x: 26.12, y: 55.93), controlPoint1: CGPoint(x: 25.75, y: 55.76), controlPoint2: CGPoint(x: 25.96, y: 55.82))
        thumbDown.addCurve(to: CGPoint(x: 26.37, y: 56.49), controlPoint1: CGPoint(x: 26.29, y: 56.05), controlPoint2: CGPoint(x: 26.37, y: 56.23))
        thumbDown.addCurve(to: CGPoint(x: 25.39, y: 60.47), controlPoint1: CGPoint(x: 26.37, y: 57.5), controlPoint2: CGPoint(x: 26.04, y: 58.83))
        thumbDown.addCurve(to: CGPoint(x: 23.1, y: 65.94), controlPoint1: CGPoint(x: 24.74, y: 62.12), controlPoint2: CGPoint(x: 23.97, y: 63.94))
        thumbDown.addCurve(to: CGPoint(x: 20.8, y: 72.14), controlPoint1: CGPoint(x: 22.22, y: 67.94), controlPoint2: CGPoint(x: 21.45, y: 70.01))
        thumbDown.addCurve(to: CGPoint(x: 19.82, y: 78.32), controlPoint1: CGPoint(x: 20.15, y: 74.28), controlPoint2: CGPoint(x: 19.82, y: 76.33))
        thumbDown.addCurve(to: CGPoint(x: 22.46, y: 85.25), controlPoint1: CGPoint(x: 19.82, y: 81.12), controlPoint2: CGPoint(x: 20.7, y: 83.43))
        thumbDown.addCurve(to: CGPoint(x: 29.15, y: 87.99), controlPoint1: CGPoint(x: 24.22, y: 87.08), controlPoint2: CGPoint(x: 26.45, y: 87.99))
        thumbDown.addCurve(to: CGPoint(x: 34.3, y: 86.35), controlPoint1: CGPoint(x: 31.14, y: 87.99), controlPoint2: CGPoint(x: 32.85, y: 87.44))
        thumbDown.addCurve(to: CGPoint(x: 38.43, y: 80.96), controlPoint1: CGPoint(x: 35.75, y: 85.26), controlPoint2: CGPoint(x: 37.13, y: 83.46))
        thumbDown.addCurve(to: CGPoint(x: 42.16, y: 74.29), controlPoint1: CGPoint(x: 39.57, y: 78.74), controlPoint2: CGPoint(x: 40.81, y: 76.52))
        thumbDown.addCurve(to: CGPoint(x: 46.58, y: 67.48), controlPoint1: CGPoint(x: 43.51, y: 72.06), controlPoint2: CGPoint(x: 44.99, y: 69.79))
        thumbDown.addCurve(to: CGPoint(x: 51.78, y: 60.35), controlPoint1: CGPoint(x: 48.18, y: 65.17), controlPoint2: CGPoint(x: 49.91, y: 62.79))
        thumbDown.addCurve(to: CGPoint(x: 57.86, y: 52.73), controlPoint1: CGPoint(x: 53.65, y: 57.91), controlPoint2: CGPoint(x: 55.68, y: 55.37))
        thumbDown.addLine(to: CGPoint(x: 65.19, y: 52.73))
        thumbDown.addCurve(to: CGPoint(x: 73.97, y: 49.44), controlPoint1: CGPoint(x: 68.41, y: 52.73), controlPoint2: CGPoint(x: 71.34, y: 51.64))
        thumbDown.addCurve(to: CGPoint(x: 80.27, y: 40.63), controlPoint1: CGPoint(x: 76.61, y: 47.24), controlPoint2: CGPoint(x: 78.71, y: 44.3))
        thumbDown.addCurve(to: CGPoint(x: 82.62, y: 28.52), controlPoint1: CGPoint(x: 81.84, y: 36.95), controlPoint2: CGPoint(x: 82.62, y: 32.91))
        thumbDown.close()
        thumbDown.move(to: CGPoint(x: 59.28, y: 28.76))
        thumbDown.addCurve(to: CGPoint(x: 57.69, y: 39.53), controlPoint1: CGPoint(x: 59.28, y: 32.89), controlPoint2: CGPoint(x: 58.75, y: 36.48))
        thumbDown.addCurve(to: CGPoint(x: 52.2, y: 49.32), controlPoint1: CGPoint(x: 56.63, y: 42.57), controlPoint2: CGPoint(x: 54.8, y: 45.83))
        thumbDown.addCurve(to: CGPoint(x: 42.36, y: 62.21), controlPoint1: CGPoint(x: 49.3, y: 53.19), controlPoint2: CGPoint(x: 46.02, y: 57.49))
        thumbDown.addCurve(to: CGPoint(x: 32.52, y: 77.98), controlPoint1: CGPoint(x: 38.7, y: 66.93), controlPoint2: CGPoint(x: 35.42, y: 72.18))
        thumbDown.addCurve(to: CGPoint(x: 30.66, y: 80.79), controlPoint1: CGPoint(x: 31.84, y: 79.41), controlPoint2: CGPoint(x: 31.22, y: 80.35))
        thumbDown.addCurve(to: CGPoint(x: 28.86, y: 81.45), controlPoint1: CGPoint(x: 30.11, y: 81.23), controlPoint2: CGPoint(x: 29.51, y: 81.45))
        thumbDown.addCurve(to: CGPoint(x: 27.1, y: 80.64), controlPoint1: CGPoint(x: 28.14, y: 81.45), controlPoint2: CGPoint(x: 27.56, y: 81.18))
        thumbDown.addCurve(to: CGPoint(x: 26.42, y: 78.32), controlPoint1: CGPoint(x: 26.64, y: 80.1), controlPoint2: CGPoint(x: 26.42, y: 79.33))
        thumbDown.addCurve(to: CGPoint(x: 27.39, y: 73.17), controlPoint1: CGPoint(x: 26.42, y: 76.76), controlPoint2: CGPoint(x: 26.74, y: 75.04))
        thumbDown.addCurve(to: CGPoint(x: 29.66, y: 67.41), controlPoint1: CGPoint(x: 28.04, y: 71.3), controlPoint2: CGPoint(x: 28.8, y: 69.38))
        thumbDown.addCurve(to: CGPoint(x: 31.96, y: 61.65), controlPoint1: CGPoint(x: 30.53, y: 65.44), controlPoint2: CGPoint(x: 31.29, y: 63.52))
        thumbDown.addCurve(to: CGPoint(x: 32.96, y: 56.49), controlPoint1: CGPoint(x: 32.63, y: 59.77), controlPoint2: CGPoint(x: 32.96, y: 58.06))
        thumbDown.addCurve(to: CGPoint(x: 30.47, y: 51.15), controlPoint1: CGPoint(x: 32.96, y: 54.22), controlPoint2: CGPoint(x: 32.13, y: 52.43))
        thumbDown.addCurve(to: CGPoint(x: 24.46, y: 49.22), controlPoint1: CGPoint(x: 28.81, y: 49.86), controlPoint2: CGPoint(x: 26.81, y: 49.22))
        thumbDown.addLine(to: CGPoint(x: 10.69, y: 49.22))
        thumbDown.addCurve(to: CGPoint(x: 7.76, y: 48), controlPoint1: CGPoint(x: 9.52, y: 49.22), controlPoint2: CGPoint(x: 8.54, y: 48.81))
        thumbDown.addCurve(to: CGPoint(x: 6.59, y: 44.97), controlPoint1: CGPoint(x: 6.98, y: 47.18), controlPoint2: CGPoint(x: 6.59, y: 46.18))
        thumbDown.addCurve(to: CGPoint(x: 8.79, y: 40.43), controlPoint1: CGPoint(x: 6.59, y: 43.41), controlPoint2: CGPoint(x: 7.32, y: 41.89))
        thumbDown.addCurve(to: CGPoint(x: 9.28, y: 39.43), controlPoint1: CGPoint(x: 9.08, y: 40.1), controlPoint2: CGPoint(x: 9.24, y: 39.77))
        thumbDown.addCurve(to: CGPoint(x: 8.98, y: 38.43), controlPoint1: CGPoint(x: 9.31, y: 39.09), controlPoint2: CGPoint(x: 9.21, y: 38.75))
        thumbDown.addCurve(to: CGPoint(x: 7.52, y: 35.86), controlPoint1: CGPoint(x: 8.3, y: 37.39), controlPoint2: CGPoint(x: 7.81, y: 36.53))
        thumbDown.addCurve(to: CGPoint(x: 7.08, y: 33.79), controlPoint1: CGPoint(x: 7.23, y: 35.2), controlPoint2: CGPoint(x: 7.08, y: 34.51))
        thumbDown.addCurve(to: CGPoint(x: 9.72, y: 29.1), controlPoint1: CGPoint(x: 7.08, y: 32.03), controlPoint2: CGPoint(x: 7.96, y: 30.47))
        thumbDown.addCurve(to: CGPoint(x: 10.69, y: 27.81), controlPoint1: CGPoint(x: 10.21, y: 28.74), controlPoint2: CGPoint(x: 10.53, y: 28.31))
        thumbDown.addCurve(to: CGPoint(x: 10.5, y: 26.22), controlPoint1: CGPoint(x: 10.86, y: 27.3), controlPoint2: CGPoint(x: 10.79, y: 26.77))
        thumbDown.addCurve(to: CGPoint(x: 9.4, y: 23.93), controlPoint1: CGPoint(x: 10.01, y: 25.21), controlPoint2: CGPoint(x: 9.64, y: 24.45))
        thumbDown.addCurve(to: CGPoint(x: 9.03, y: 22.07), controlPoint1: CGPoint(x: 9.16, y: 23.41), controlPoint2: CGPoint(x: 9.03, y: 22.79))
        thumbDown.addCurve(to: CGPoint(x: 13.18, y: 17.04), controlPoint1: CGPoint(x: 9.03, y: 20.21), controlPoint2: CGPoint(x: 10.42, y: 18.54))
        thumbDown.addCurve(to: CGPoint(x: 14.01, y: 16.16), controlPoint1: CGPoint(x: 13.64, y: 16.81), controlPoint2: CGPoint(x: 13.92, y: 16.52))
        thumbDown.addCurve(to: CGPoint(x: 13.92, y: 15.09), controlPoint1: CGPoint(x: 14.11, y: 15.8), controlPoint2: CGPoint(x: 14.08, y: 15.45))
        thumbDown.addCurve(to: CGPoint(x: 12.94, y: 12.5), controlPoint1: CGPoint(x: 13.39, y: 13.75), controlPoint2: CGPoint(x: 13.07, y: 12.89))
        thumbDown.addCurve(to: CGPoint(x: 12.74, y: 11.18), controlPoint1: CGPoint(x: 12.81, y: 12.11), controlPoint2: CGPoint(x: 12.74, y: 11.67))
        thumbDown.addCurve(to: CGPoint(x: 16.75, y: 7.37), controlPoint1: CGPoint(x: 12.74, y: 9.33), controlPoint2: CGPoint(x: 14.08, y: 8.06))
        thumbDown.addCurve(to: CGPoint(x: 21.12, y: 6.74), controlPoint1: CGPoint(x: 17.92, y: 7.08), controlPoint2: CGPoint(x: 19.38, y: 6.87))
        thumbDown.addCurve(to: CGPoint(x: 27, y: 6.59), controlPoint1: CGPoint(x: 22.86, y: 6.61), controlPoint2: CGPoint(x: 24.82, y: 6.56))
        thumbDown.addLine(to: CGPoint(x: 32.37, y: 6.64))
        thumbDown.addCurve(to: CGPoint(x: 46.44, y: 9.52), controlPoint1: CGPoint(x: 37.71, y: 6.67), controlPoint2: CGPoint(x: 42.4, y: 7.63))
        thumbDown.addCurve(to: CGPoint(x: 55.88, y: 17.31), controlPoint1: CGPoint(x: 50.47, y: 11.41), controlPoint2: CGPoint(x: 53.62, y: 14.01))
        thumbDown.addCurve(to: CGPoint(x: 59.28, y: 28.76), controlPoint1: CGPoint(x: 58.15, y: 20.61), controlPoint2: CGPoint(x: 59.28, y: 24.43))
        thumbDown.addLine(to: CGPoint(x: 59.28, y: 28.76))
        thumbDown.close()
        thumbDown.move(to: CGPoint(x: 76.03, y: 28.52))
        thumbDown.addCurve(to: CGPoint(x: 74.51, y: 37.33), controlPoint1: CGPoint(x: 76.03, y: 31.71), controlPoint2: CGPoint(x: 75.52, y: 34.64))
        thumbDown.addCurve(to: CGPoint(x: 70.51, y: 43.75), controlPoint1: CGPoint(x: 73.5, y: 40.01), controlPoint2: CGPoint(x: 72.17, y: 42.16))
        thumbDown.addCurve(to: CGPoint(x: 65.19, y: 46.14), controlPoint1: CGPoint(x: 68.85, y: 45.35), controlPoint2: CGPoint(x: 67.07, y: 46.14))
        thumbDown.addCurve(to: CGPoint(x: 63.67, y: 46.14), controlPoint1: CGPoint(x: 64.7, y: 46.14), controlPoint2: CGPoint(x: 64.19, y: 46.14))
        thumbDown.addCurve(to: CGPoint(x: 62.11, y: 46.14), controlPoint1: CGPoint(x: 63.15, y: 46.14), controlPoint2: CGPoint(x: 62.63, y: 46.14))
        thumbDown.addCurve(to: CGPoint(x: 64.97, y: 38.01), controlPoint1: CGPoint(x: 63.41, y: 43.57), controlPoint2: CGPoint(x: 64.36, y: 40.86))
        thumbDown.addCurve(to: CGPoint(x: 65.87, y: 28.91), controlPoint1: CGPoint(x: 65.57, y: 35.16), controlPoint2: CGPoint(x: 65.87, y: 32.13))
        thumbDown.addCurve(to: CGPoint(x: 64.14, y: 19.14), controlPoint1: CGPoint(x: 65.87, y: 25.42), controlPoint2: CGPoint(x: 65.29, y: 22.17))
        thumbDown.addCurve(to: CGPoint(x: 59.23, y: 10.99), controlPoint1: CGPoint(x: 62.98, y: 16.11), controlPoint2: CGPoint(x: 61.34, y: 13.4))
        thumbDown.addCurve(to: CGPoint(x: 61.47, y: 10.99), controlPoint1: CGPoint(x: 59.98, y: 10.99), controlPoint2: CGPoint(x: 60.73, y: 10.99))
        thumbDown.addCurve(to: CGPoint(x: 63.72, y: 10.99), controlPoint1: CGPoint(x: 62.22, y: 10.99), controlPoint2: CGPoint(x: 62.97, y: 10.99))
        thumbDown.addCurve(to: CGPoint(x: 69.82, y: 13.4), controlPoint1: CGPoint(x: 65.93, y: 10.99), controlPoint2: CGPoint(x: 67.97, y: 11.79))
        thumbDown.addCurve(to: CGPoint(x: 74.32, y: 19.8), controlPoint1: CGPoint(x: 71.68, y: 15.01), controlPoint2: CGPoint(x: 73.18, y: 17.15))
        thumbDown.addCurve(to: CGPoint(x: 76.03, y: 28.52), controlPoint1: CGPoint(x: 75.46, y: 22.45), controlPoint2: CGPoint(x: 76.03, y: 25.36))
        thumbDown.close()
        

        let filledThumbDown = UIBezierPath()
        filledThumbDown.move(to: CGPoint(x: 79.54, y: 25.69))
        filledThumbDown.addCurve(to: CGPoint(x: 77.25, y: 14.8), controlPoint1: CGPoint(x: 79.54, y: 21.75), controlPoint2: CGPoint(x: 78.78, y: 18.12))
        filledThumbDown.addCurve(to: CGPoint(x: 71, y: 6.82), controlPoint1: CGPoint(x: 75.72, y: 11.48), controlPoint2: CGPoint(x: 73.63, y: 8.82))
        filledThumbDown.addCurve(to: CGPoint(x: 62.06, y: 3.82), controlPoint1: CGPoint(x: 68.36, y: 4.82), controlPoint2: CGPoint(x: 65.38, y: 3.82))
        filledThumbDown.addLine(to: CGPoint(x: 55.42, y: 3.82))
        filledThumbDown.addCurve(to: CGPoint(x: 63.16, y: 13.61), controlPoint1: CGPoint(x: 58.94, y: 6.49), controlPoint2: CGPoint(x: 61.52, y: 9.75))
        filledThumbDown.addCurve(to: CGPoint(x: 65.48, y: 26.08), controlPoint1: CGPoint(x: 64.8, y: 17.46), controlPoint2: CGPoint(x: 65.58, y: 21.62))
        filledThumbDown.addCurve(to: CGPoint(x: 62.96, y: 39), controlPoint1: CGPoint(x: 65.41, y: 31.06), controlPoint2: CGPoint(x: 64.58, y: 35.37))
        filledThumbDown.addCurve(to: CGPoint(x: 57.86, y: 47.76), controlPoint1: CGPoint(x: 61.35, y: 42.63), controlPoint2: CGPoint(x: 59.65, y: 45.55))
        filledThumbDown.addLine(to: CGPoint(x: 63.57, y: 47.76))
        filledThumbDown.addCurve(to: CGPoint(x: 71.68, y: 44.81), controlPoint1: CGPoint(x: 66.57, y: 47.76), controlPoint2: CGPoint(x: 69.27, y: 46.78))
        filledThumbDown.addCurve(to: CGPoint(x: 77.42, y: 36.87), controlPoint1: CGPoint(x: 74.09, y: 42.84), controlPoint2: CGPoint(x: 76, y: 40.19))
        filledThumbDown.addCurve(to: CGPoint(x: 79.54, y: 25.69), controlPoint1: CGPoint(x: 78.83, y: 33.55), controlPoint2: CGPoint(x: 79.54, y: 29.83))
        filledThumbDown.close()
        filledThumbDown.move(to: CGPoint(x: 59.67, y: 25.98))
        filledThumbDown.addCurve(to: CGPoint(x: 56.08, y: 12.82), controlPoint1: CGPoint(x: 59.73, y: 21.1), controlPoint2: CGPoint(x: 58.54, y: 16.71))
        filledThumbDown.addCurve(to: CGPoint(x: 45.51, y: 3.55), controlPoint1: CGPoint(x: 53.62, y: 8.93), controlPoint2: CGPoint(x: 50.1, y: 5.84))
        filledThumbDown.addCurve(to: CGPoint(x: 29.3, y: 0.06), controlPoint1: CGPoint(x: 40.92, y: 1.25), controlPoint2: CGPoint(x: 35.51, y: 0.09))
        filledThumbDown.addLine(to: CGPoint(x: 23.83, y: 0.01))
        filledThumbDown.addCurve(to: CGPoint(x: 17.07, y: 0.23), controlPoint1: CGPoint(x: 21.22, y: -0.03), controlPoint2: CGPoint(x: 18.97, y: 0.05))
        filledThumbDown.addCurve(to: CGPoint(x: 12.6, y: 0.94), controlPoint1: CGPoint(x: 15.16, y: 0.41), controlPoint2: CGPoint(x: 13.67, y: 0.64))
        filledThumbDown.addCurve(to: CGPoint(x: 8.33, y: 3.06), controlPoint1: CGPoint(x: 11.04, y: 1.33), controlPoint2: CGPoint(x: 9.61, y: 2.03))
        filledThumbDown.addCurve(to: CGPoint(x: 6.4, y: 7.43), controlPoint1: CGPoint(x: 7.04, y: 4.08), controlPoint2: CGPoint(x: 6.4, y: 5.54))
        filledThumbDown.addCurve(to: CGPoint(x: 6.67, y: 9.46), controlPoint1: CGPoint(x: 6.4, y: 8.21), controlPoint2: CGPoint(x: 6.49, y: 8.89))
        filledThumbDown.addCurve(to: CGPoint(x: 7.32, y: 10.99), controlPoint1: CGPoint(x: 6.84, y: 10.03), controlPoint2: CGPoint(x: 7.06, y: 10.54))
        filledThumbDown.addCurve(to: CGPoint(x: 7.08, y: 12.12), controlPoint1: CGPoint(x: 7.65, y: 11.55), controlPoint2: CGPoint(x: 7.57, y: 11.92))
        filledThumbDown.addCurve(to: CGPoint(x: 3.88, y: 14.56), controlPoint1: CGPoint(x: 5.84, y: 12.61), controlPoint2: CGPoint(x: 4.78, y: 13.42))
        filledThumbDown.addCurve(to: CGPoint(x: 2.54, y: 18.66), controlPoint1: CGPoint(x: 2.99, y: 15.7), controlPoint2: CGPoint(x: 2.54, y: 17.06))
        filledThumbDown.addCurve(to: CGPoint(x: 3.96, y: 23.2), controlPoint1: CGPoint(x: 2.54, y: 20.48), controlPoint2: CGPoint(x: 3.01, y: 22))
        filledThumbDown.addCurve(to: CGPoint(x: 3.61, y: 24.76), controlPoint1: CGPoint(x: 4.41, y: 23.82), controlPoint2: CGPoint(x: 4.3, y: 24.34))
        filledThumbDown.addCurve(to: CGPoint(x: 1.39, y: 27.13), controlPoint1: CGPoint(x: 2.7, y: 25.28), controlPoint2: CGPoint(x: 1.96, y: 26.07))
        filledThumbDown.addCurve(to: CGPoint(x: 0.54, y: 30.67), controlPoint1: CGPoint(x: 0.82, y: 28.19), controlPoint2: CGPoint(x: 0.54, y: 29.37))
        filledThumbDown.addCurve(to: CGPoint(x: 0.95, y: 33.41), controlPoint1: CGPoint(x: 0.54, y: 31.58), controlPoint2: CGPoint(x: 0.68, y: 32.49))
        filledThumbDown.addCurve(to: CGPoint(x: 2.2, y: 35.51), controlPoint1: CGPoint(x: 1.23, y: 34.32), controlPoint2: CGPoint(x: 1.64, y: 35.02))
        filledThumbDown.addCurve(to: CGPoint(x: 2.05, y: 37.02), controlPoint1: CGPoint(x: 2.72, y: 35.99), controlPoint2: CGPoint(x: 2.67, y: 36.5))
        filledThumbDown.addCurve(to: CGPoint(x: 0.54, y: 39.19), controlPoint1: CGPoint(x: 1.4, y: 37.57), controlPoint2: CGPoint(x: 0.9, y: 38.3))
        filledThumbDown.addCurve(to: CGPoint(x: 0, y: 42.2), controlPoint1: CGPoint(x: 0.18, y: 40.09), controlPoint2: CGPoint(x: 0, y: 41.09))
        filledThumbDown.addCurve(to: CGPoint(x: 2, y: 47.18), controlPoint1: CGPoint(x: 0, y: 44.15), controlPoint2: CGPoint(x: 0.67, y: 45.81))
        filledThumbDown.addCurve(to: CGPoint(x: 6.98, y: 49.23), controlPoint1: CGPoint(x: 3.34, y: 48.54), controlPoint2: CGPoint(x: 5, y: 49.23))
        filledThumbDown.addLine(to: CGPoint(x: 21.14, y: 49.23))
        filledThumbDown.addCurve(to: CGPoint(x: 25.49, y: 50.52), controlPoint1: CGPoint(x: 22.93, y: 49.23), controlPoint2: CGPoint(x: 24.38, y: 49.66))
        filledThumbDown.addCurve(to: CGPoint(x: 27.15, y: 54.06), controlPoint1: CGPoint(x: 26.6, y: 51.38), controlPoint2: CGPoint(x: 27.15, y: 52.56))
        filledThumbDown.addCurve(to: CGPoint(x: 26.12, y: 58.8), controlPoint1: CGPoint(x: 27.15, y: 55.39), controlPoint2: CGPoint(x: 26.81, y: 56.97))
        filledThumbDown.addCurve(to: CGPoint(x: 23.78, y: 64.61), controlPoint1: CGPoint(x: 25.44, y: 60.62), controlPoint2: CGPoint(x: 24.66, y: 62.56))
        filledThumbDown.addCurve(to: CGPoint(x: 21.44, y: 70.71), controlPoint1: CGPoint(x: 22.9, y: 66.66), controlPoint2: CGPoint(x: 22.12, y: 68.69))
        filledThumbDown.addCurve(to: CGPoint(x: 20.41, y: 76.42), controlPoint1: CGPoint(x: 20.75, y: 72.73), controlPoint2: CGPoint(x: 20.41, y: 74.63))
        filledThumbDown.addCurve(to: CGPoint(x: 22, y: 80.77), controlPoint1: CGPoint(x: 20.41, y: 78.28), controlPoint2: CGPoint(x: 20.94, y: 79.73))
        filledThumbDown.addCurve(to: CGPoint(x: 25.98, y: 82.33), controlPoint1: CGPoint(x: 23.06, y: 81.81), controlPoint2: CGPoint(x: 24.38, y: 82.33))
        filledThumbDown.addCurve(to: CGPoint(x: 29.37, y: 80.96), controlPoint1: CGPoint(x: 27.41, y: 82.33), controlPoint2: CGPoint(x: 28.54, y: 81.88))
        filledThumbDown.addCurve(to: CGPoint(x: 31.79, y: 77.35), controlPoint1: CGPoint(x: 30.2, y: 80.05), controlPoint2: CGPoint(x: 31.01, y: 78.85))
        filledThumbDown.addCurve(to: CGPoint(x: 41.77, y: 61.43), controlPoint1: CGPoint(x: 34.78, y: 71.52), controlPoint2: CGPoint(x: 38.11, y: 66.22))
        filledThumbDown.addCurve(to: CGPoint(x: 51.81, y: 48.2), controlPoint1: CGPoint(x: 45.43, y: 56.65), controlPoint2: CGPoint(x: 48.78, y: 52.24))
        filledThumbDown.addCurve(to: CGPoint(x: 57.59, y: 38.09), controlPoint1: CGPoint(x: 54.38, y: 44.78), controlPoint2: CGPoint(x: 56.31, y: 41.41))
        filledThumbDown.addCurve(to: CGPoint(x: 59.67, y: 25.98), controlPoint1: CGPoint(x: 58.88, y: 34.77), controlPoint2: CGPoint(x: 59.57, y: 30.74))
        filledThumbDown.close()
        

        
        // 1
        let pdfMetaData = [
            kCGPDFContextCreator: NSLocalizedString("Nim", comment: "Nim"),
            kCGPDFContextTitle: NSLocalizedString("NimArchive", comment: "Nim Archive")
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // 2
        let pageWidth = 8.3 * 72.0
        let pageHeight = 11.7 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let centimeter = pageWidth/21.0
        let point = 0.0352778*centimeter
        
        let leadingBorder = 2.5*centimeter
    
        let trailingBorder = 2*centimeter
        
        let topBorder = 2*centimeter
        let bottomBorder = 3*centimeter
        

        

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        
        
        let date = Date()

        let data = renderer.pdfData { (context) in

            context.beginPage()

            let normalParagraphStyle = NSMutableParagraphStyle()
            normalParagraphStyle.alignment = .natural
            
            let invertedParagraphStyle = NSMutableParagraphStyle()
            invertedParagraphStyle.alignment = .inversed
            
            let headline = NSLocalizedString("NimArchive", comment: "Nim Archive")
            headline.draw(
                in: CGRect(x: (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? leadingBorder : trailingBorder, y: topBorder, width: pageWidth-leadingBorder-trailingBorder, height: centimeter),
                withAttributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14*point),
                    NSAttributedString.Key.paragraphStyle: normalParagraphStyle]
            )
 
            let subHeadline = "\(UIDevice.current.name) – \(dateFormatterForContent.string(from: date))"
            subHeadline.draw(
                in: CGRect(x: (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? leadingBorder : trailingBorder, y: topBorder+21*point, width: pageWidth-leadingBorder-trailingBorder, height: centimeter),
                withAttributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12*point),
                    NSAttributedString.Key.paragraphStyle: normalParagraphStyle]
            )

            
            let leftText = NSLocalizedString("left", comment: "Left")
            let rightText = NSLocalizedString("right", comment: "right")

            let maximumTextWidth = max(leftText.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point)]).width,rightText.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point)]).width)
            let textheight = max(leftText.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point)]).height,rightText.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point)]).height)
            
            
            leftText.draw(
                in: CGRect(x: (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? pageWidth-trailingBorder-maximumTextWidth : trailingBorder, y: topBorder, width: maximumTextWidth, height: centimeter),
                withAttributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point),
                    NSAttributedString.Key.paragraphStyle: normalParagraphStyle]
            )
            
            rightText.draw(
                in: CGRect(x: (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? pageWidth-trailingBorder-maximumTextWidth : trailingBorder, y: topBorder+21*point, width: maximumTextWidth, height: centimeter),
                withAttributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point),
                    NSAttributedString.Key.paragraphStyle: normalParagraphStyle]
            )

            let widthOfField = 0.75*centimeter

            let circleX = (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? pageWidth-trailingBorder-maximumTextWidth-widthOfField : trailingBorder+maximumTextWidth+0.2*widthOfField
            let circlerect = CGRect(x: circleX, y: topBorder+textheight/2-0.4*widthOfField, width: 0.8*widthOfField, height: 0.8*widthOfField)
            context.cgContext.setFillColor(UIColor.lightGray.cgColor)
            context.cgContext.fillEllipse(in: circlerect)
            
            let circleLineWidth = 2*point
            context.cgContext.setLineWidth(circleLineWidth)
            context.cgContext.setStrokeColor(UIColor.darkGray.cgColor)
            context.cgContext.strokeEllipse(in: CGRect(x: circleX+0.5*circleLineWidth, y: topBorder+21*point+textheight/2-0.4*widthOfField+0.5*circleLineWidth, width: 0.8*widthOfField-circleLineWidth, height: 0.8*widthOfField-circleLineWidth))
            
            
            
            
            context.cgContext.setLineWidth(0.5*point)
            
            

            var x = (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? leadingBorder : pageWidth-leadingBorder-widthOfField
            var y = 4*centimeter

            var n = 1
            
            var exportableListOfArchiveEntries : [ArchiveEntry] = []
            for inde in setOfSelectedCellIndizes{
                exportableListOfArchiveEntries.append(listOfArchiveEntries[inde])
            }
            if(!editingIsActive){
                exportableListOfArchiveEntries = listOfArchiveEntries
            }
            

            for archiveEntry in exportableListOfArchiveEntries{

                if(y > pageHeight-bottomBorder){
                    context.beginPage()
                    
                    let header = "\(NSLocalizedString("NimArchive", comment: "Nim Archive"))\u{202C} – \(UIDevice.current.name) – \u{202C}\(dateFormatterForContent.string(from: date))"
                    let headerAttributes = [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10*point),
                        NSAttributedString.Key.paragraphStyle: invertedParagraphStyle,
                        NSAttributedString.Key.foregroundColor: UIColor.gray
                    ]
                    
                    
                    header.draw(
                        in: CGRect(x: (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? leadingBorder : trailingBorder, y: centimeter, width: pageWidth-leadingBorder-trailingBorder, height: centimeter),
                        withAttributes: headerAttributes
                    )
                    
                    y = topBorder
                }

                
                
                let attributes = [
                    NSAttributedString.Key.font: UIFont.monospacedDigitSystemFont(ofSize: 10*point, weight: .regular),
                    NSAttributedString.Key.paragraphStyle: invertedParagraphStyle
                ]
                let text = "\(n)"
                let textHeight = text.size(withAttributes: attributes).height
                
                
                if(UIApplication.shared.userInterfaceLayoutDirection == .leftToRight){
                    text.draw(in: CGRect(x: x-widthOfField, y: y+0.5*widthOfField-textHeight/2, width: 0.8*widthOfField, height: widthOfField), withAttributes: attributes)
                }
                else{
                    text.draw(in: CGRect(x: x+1.2*widthOfField, y: y+0.5*widthOfField-textHeight/2, width: 0.8*widthOfField, height: widthOfField), withAttributes: attributes)
                }
                
                
                
                n+=1
                
                for i in 1...archiveEntry.listOfColors.count{
                    
                    let rect = CGRect(x: x, y: y, width: widthOfField, height: widthOfField)
//                    : CGRect(x: x-widthOfField, y: y, width: widthOfField, height: widthOfField)
                    
                    context.cgContext.setFillColor(tileBackgroundColor.cgColor)
                    context.cgContext.setLineWidth(0.5*point)
                    context.cgContext.setStrokeColor(UIColor.black.cgColor)
                    context.cgContext.stroke(rect)
                    
                    let circlerect = CGRect(x: x+0.1*widthOfField, y: y+0.1*widthOfField, width: 0.8*widthOfField, height: 0.8*widthOfField)
//                    : CGRect(x: x-0.9*widthOfField, y: y+0.1*widthOfField, width: 0.8*widthOfField, height: 0.8*widthOfField)
                    
                    
                    if(archiveEntry.listOfColors[i-1] == archiveEntry.leftPlayerColor){
                        context.cgContext.setFillColor(UIColor.lightGray.cgColor)
                        context.cgContext.fillEllipse(in: circlerect)
                    }
                    
                    else{
                        let circleLineWidth = 2*point
                        context.cgContext.setLineWidth(circleLineWidth)
                        context.cgContext.setStrokeColor(UIColor.darkGray.cgColor)
                        
                        context.cgContext.strokeEllipse(in: CGRect(x: x+0.1*widthOfField+0.5*circleLineWidth, y: y+0.1*widthOfField+0.5*circleLineWidth, width: 0.8*widthOfField-circleLineWidth, height: 0.8*widthOfField-circleLineWidth))
                    }
                    
                    if(i==archiveEntry.listOfColors.count){
                        
                        context.cgContext.setFillColor(UIColor.darkGray.cgColor)
                        
                        var thumb: UIBezierPath {
                            switch (archiveEntry.winMode, archiveEntry.listOfColors[i-1] == archiveEntry.leftPlayerColor){
                            case (.lastWins,true):
                                return filledThumbUp
                            case (.lastWins,false):
                                return thumpUp
                            case (.lastLoses,true):
                                return filledThumbDown
                            case (.lastLoses,false):
                                return thumbDown
                            }
                        }
                        
                        var thumbOffset: CGFloat {
                            switch (archiveEntry.winMode, archiveEntry.listOfColors[i-1] == archiveEntry.leftPlayerColor){
                            case (.lastWins,true):
                                return -0.02*widthOfField
                            case (.lastWins,false):
                                return -0.02*widthOfField
                            case (.lastLoses,true):
                                return 0.02*widthOfField
                            case (.lastLoses,false):
                                return 0.02*widthOfField
                            }
                        }
                        
                        let scale = 0.5*widthOfField/thumb.bounds.size.height
                        thumb.apply(CGAffineTransform(scaleX: scale, y: scale))
                        thumb.apply(CGAffineTransform(translationX: x+0.26*widthOfField, y: y+0.25*widthOfField+thumbOffset))
                        thumb.fill()
                        thumb.apply(CGAffineTransform(translationX: -x-0.26*widthOfField, y: -y-0.25*widthOfField-thumbOffset))
                        thumb.apply(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
                    }

                    if(UIApplication.shared.userInterfaceLayoutDirection == .leftToRight){
                        x += 1.1*widthOfField
                        if(i%5==0){
                            x += 0.2*widthOfField
                        }
                    }
                    else{
                        x -= 1.1*widthOfField
                        if(i%5==0){
                            x -= 0.2*widthOfField
                        }
                    }
                }
                
                x = (UIApplication.shared.userInterfaceLayoutDirection == .leftToRight) ? leadingBorder : pageWidth-leadingBorder-widthOfField
                y += 2*widthOfField
            }
        }
        

        let urlString = "\(UIDevice.current.name)_\(dateFormatterForFileName.string(from: date)).pdf".replacingOccurrences(of: " ", with: "-")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
      
        
        
        do {
            try data.write(to: url)
            
            #if targetEnvironment(macCatalyst)
            if #available(iOS 14, *) {
                let controller = UIDocumentPickerViewController(forExporting: [url])
                self.present(controller, animated: true)
            } else {
                let controller = UIDocumentPickerViewController(url: url, in: .exportToService)
                self.present(controller, animated: true)
            }
            #else
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = sender
            self.present(activityVC, animated: true)
            #endif
        }
        catch {
        }
       
    }
    
    
    
    // MARK: Numbering

    @IBOutlet weak var numberModeSegmentControl: UISegmentedControl!
    @IBAction func changeNumberMode(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: "settings_numberMode")
        renewNumbersInViews(currentNavigationController: self.navigationController!)
    }
    
}




class SortViewController : UIViewController, UIPopoverPresentationControllerDelegate{
    
    //fit layout to constraints
    override func viewWillAppear(_ animated: Bool) {
        self.preferredContentSize = self.view.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.presentationController?.delegate = self
        
        

    }
    
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
    
    @IBAction func dismissView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func sortAscent(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.listOfColors.count > $1.listOfColors.count})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    @IBAction func sortDescent(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.listOfColors.count < $1.listOfColors.count})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    @IBAction func sortChronological(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.gameNumber < $1.gameNumber})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    
    @IBAction func sortDescentChronological(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.gameNumber > $1.gameNumber})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    
    @IBAction func sortLeft(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.listOfColors.first!.position < $1.listOfColors.first!.position})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    
    
    @IBAction func sortRight(_ sender: UIButton) {
        if let archiveVC = (self.presentingViewController as? UINavigationController)?.topViewController as? ArchiveViewController{
            let orderedListOfArchiveEntries = listOfArchiveEntries.sorted(by: {$0.listOfColors.first!.position > $1.listOfColors.first!.position})
            reorderArchive(orderedListOfArchiveEntries: orderedListOfArchiveEntries, archiveVC: archiveVC)
        }
    }
    
    
    func reorderArchive(orderedListOfArchiveEntries: [ArchiveEntry], archiveVC: ArchiveViewController){
        for i in 0..<orderedListOfArchiveEntries.count{
            if let j = listOfArchiveEntries[i..<listOfArchiveEntries.count] .firstIndex(where: {$0 == orderedListOfArchiveEntries[i]}){
                archiveVC.archiveCollectionView.performBatchUpdates({
                    archiveVC.archiveCollectionView.moveItem(at: IndexPath(row: j, section: 0), to: IndexPath(row: i, section: 0))
                }, completion: {_ in
                    archiveVC.archiveCollectionView.reloadData()
                })
                
                let archiveEntryAtSourceIndex = listOfArchiveEntries[j]
                listOfArchiveEntries.remove(at: j)
                listOfArchiveEntries.insert(archiveEntryAtSourceIndex, at: i)
            }
        }
        saveArchive()
        if(heightConstraint.constant == 60){
            self.dismiss(animated: true, completion: nil)
        }
    }
    
}
