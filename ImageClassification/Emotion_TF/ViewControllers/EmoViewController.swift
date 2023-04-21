//
//  EmoViewController.swift
//  ASMR
//
//  Created by Li Cheuk Yin on 20/1/2021.
//  Copyright © 2021 Li Cheuk Yin. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class EmoViewController: UIViewController {


    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var cameraUnavailableLabel: UILabel!
    @IBOutlet weak var resumeButton: UIButton!
    @IBOutlet weak var bottomSheetView: CurvedView!
    @IBOutlet weak var showResult: UILabel!
    @IBOutlet weak var bottomSheetViewBottomSpace: NSLayoutConstraint!
    @IBOutlet weak var bottomSheetStateImageView: UIImageView!

    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -40.0
    private let expandThransitionThreshold: CGFloat = 40.0
    private let delayBetweenInferencesMs: Double = 1000


    private var result: Result?
    private var initialBottomSpace: CGFloat = 0.0
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000

    private lazy var cameraCapture = CameraFeedManager(previewView: previewView)


    private var modelDataHandler: ModelDataHandler? =
      ModelDataHandler(modelFileInfo: MobileNet.modelInfo, labelsFileInfo: MobileNet.labelsInfo)


    private var inferenceViewController: InferenceViewController?
    var counting = 3
    static var timer = Timer()
      static var datected = ""
    override func viewDidLoad() {
      super.viewDidLoad()

      guard modelDataHandler != nil else {
        fatalError("Error")
          
      }

      cameraCapture.delegate = self
        EmoViewController.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(showResultfunc), userInfo: nil, repeats: true)

     
    }

    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)

      changeBottomViewState()

      cameraCapture.checkCameraConfigurationAndStartSession()
    }


    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      cameraCapture.stopSession()
    }


    override var preferredStatusBarStyle: UIStatusBarStyle {
      return .lightContent
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
      super.prepare(for: segue, sender: sender)

      if segue.identifier == "EMBED" {

        guard let tempModelDataHandler = modelDataHandler else {
          return
        }
        inferenceViewController = segue.destination as? InferenceViewController
        inferenceViewController?.wantedInputHeight = 224
        inferenceViewController?.wantedInputWidth = 224
        inferenceViewController?.maxResults = 1
        inferenceViewController?.threadCountLimit = tempModelDataHandler.threadCountLimit
        inferenceViewController?.delegate = self

      }
    }

    @objc func classifyPasteboardImage() {
      guard let image = UIPasteboard.general.images?.first else {
        return
      }

      guard let buffer = CVImageBuffer.buffer(from: image) else {
        return
      }

      previewView.image = image

      DispatchQueue.global().async {
        self.didOutput(pixelBuffer: buffer)
      }
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

  }

  extension EmoViewController: InferenceViewControllerDelegate {

    func didChangeThreadCount(to count: Int) {
      if modelDataHandler?.threadCount == count { return }
      modelDataHandler = ModelDataHandler(
        modelFileInfo: MobileNet.modelInfo,
        labelsFileInfo: MobileNet.labelsInfo,
        threadCount: count
      )
    }
  }


  extension EmoViewController: CameraFeedManagerDelegate {

    func didOutput(pixelBuffer: CVPixelBuffer) {
      let currentTimeMs = Date().timeIntervalSince1970 * 1000
      guard (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else { return }
      previousInferenceTimeMs = currentTimeMs

      result = modelDataHandler?.runModel(onFrame: pixelBuffer)

      DispatchQueue.main.async {
        let resolution = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        self.inferenceViewController?.inferenceResult = self.result
        self.inferenceViewController?.resolution = resolution
        self.inferenceViewController?.tableView.reloadData()
        
      }
    }

    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
    }

    func sessionInterruptionEnded() {
    }

    func sessionRunTimeErrorOccured() {
    }

    func presentCameraPermissionsDeniedAlert() {
      
        let alert = UIAlertController(title: "Go to Setting page", message: "Grant Permission for Camera", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
        previewView.shouldUseClipboardImage = true
    }

    func presentVideoConfigurationErrorAlert() {
      let alert = UIAlertController(title: "Error", message: "", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      self.present(alert, animated: true)
      previewView.shouldUseClipboardImage = true
    }
  }

  extension EmoViewController {

    private func changeBottomViewState() {

      guard let inferenceVC = inferenceViewController else {
        return
      }

      if bottomSheetViewBottomSpace.constant == inferenceVC.collapsedHeight - bottomSheetView.bounds.size.height {

        bottomSheetViewBottomSpace.constant = 0.0
      }
      else {
        bottomSheetViewBottomSpace.constant = inferenceVC.collapsedHeight - bottomSheetView.bounds.size.height
      }
      setImageBasedOnBottomViewState()
    }


    private func setImageBasedOnBottomViewState() {

      if bottomSheetViewBottomSpace.constant == 0.0 {
        bottomSheetStateImageView.image = UIImage(named: "down_icon")
      }
      else {
        bottomSheetStateImageView.image = UIImage(named: "up_icon")
      }
    }



    private func translateBottomSheet(withVerticalTranslation verticalTranslation: CGFloat) {

      let bottomSpace = initialBottomSpace - verticalTranslation
      guard bottomSpace <= 0.0 && bottomSpace >= inferenceViewController!.collapsedHeight - bottomSheetView.bounds.size.height else {
        return
      }
      setBottomSheetLayout(withBottomSpace: bottomSpace)
    }

    private func translateBottomSheetAtEndOfPan(withVerticalTranslation verticalTranslation: CGFloat) {


      let bottomSpace = bottomSpaceAtEndOfPan(withVerticalTranslation: verticalTranslation)
      setBottomSheetLayout(withBottomSpace: bottomSpace)
    }
    private func bottomSpaceAtEndOfPan(withVerticalTranslation verticalTranslation: CGFloat) -> CGFloat {


      var bottomSpace = initialBottomSpace - verticalTranslation

      var height: CGFloat = 0.0
      if initialBottomSpace == 0.0 {
        height = bottomSheetView.bounds.size.height
      }
      else {
        height = inferenceViewController!.collapsedHeight
      }

      let currentHeight = bottomSheetView.bounds.size.height + bottomSpace

      if currentHeight - height <= collapseTransitionThreshold {
        bottomSpace = inferenceViewController!.collapsedHeight - bottomSheetView.bounds.size.height
      }
      else if currentHeight - height >= expandThransitionThreshold {
        bottomSpace = 0.0
      }
      else {
        bottomSpace = initialBottomSpace
      }

      return bottomSpace
    }

    func setBottomSheetLayout(withBottomSpace bottomSpace: CGFloat) {

      view.setNeedsLayout()
      bottomSheetViewBottomSpace.constant = bottomSpace
      view.setNeedsLayout()
    }

      @objc func showResultfunc(){
          if counting == 5 {
                 }
                 if counting > 0 {
                  //showResult.text = InferenceViewController.getResult
                     counting -= 1
                 } else if counting == 0{
                     if InferenceViewController.getResult == "Underripe" || InferenceViewController.getResult == "Barely ripe" || InferenceViewController.getResult == "Ripe"{
                         let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                         let vc: UIViewController = storyboard.instantiateViewController(withIdentifier: "GoodQualityViewController")
                                 self.present(vc, animated: true, completion: nil)
                     }
                     else{
                         let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                         let vc: UIViewController = storyboard.instantiateViewController(withIdentifier: "BadQualityViewController")
                                 self.present(vc, animated: true, completion: nil)
                     }

                  print(InferenceViewController.getResult)
                    EmoViewController.datected = InferenceViewController.getResult
                  print(EmoViewController.datected)
                  print("stopped")
                EmoViewController.timer.invalidate()
                 }
      }
}
