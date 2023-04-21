//
//  InferenceViewController.swift
//  ASMR
//
//  Created by Li Cheuk Yin on 20/1/2021.
//  Copyright © 2021 Li Cheuk Yin. All rights reserved.
//


import UIKit

protocol InferenceViewControllerDelegate {
  func didChangeThreadCount(to count: Int)

}

class InferenceViewController: UIViewController {
    static var getResult:String = ""
  private enum InferenceSections: Int, CaseIterable {
    case Results
  }

  private enum InferenceInfo: Int, CaseIterable {
    case Resolution
    case Crop
    case InferenceTime

    func displayString() -> String {

      var toReturn = ""

      switch self {
      case .Resolution:
        toReturn = "Resolution"
      case .Crop:
        toReturn = "Crop"
      case .InferenceTime:
        toReturn = "Inference Time"

      }
      return toReturn
    }
  }

  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var threadStepper: UIStepper!
  @IBOutlet weak var stepperValueLabel: UILabel!


  var inferenceResult: Result? = nil
  var wantedInputWidth: Int = 0
  var wantedInputHeight: Int = 0
  var resolution: CGSize = CGSize.zero
  var maxResults: Int = 0
  var threadCountLimit: Int = 0
  private var currentThreadCount: Int = 0
  private var infoTextColor = UIColor.black

  var delegate: InferenceViewControllerDelegate?
  var collapsedHeight: CGFloat {
    return 27.0 * CGFloat(maxResults - 1) + 42.0 + 44.0

  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }
}

extension InferenceViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return InferenceSections.allCases.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

    guard let inferenceSection = InferenceSections(rawValue: section) else {
      return 0
    }

    var rowCount = 0
    switch inferenceSection {
    case .Results:
      rowCount = maxResults
    }
    return rowCount
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

    var height: CGFloat = 0.0

    guard let inferenceSection = InferenceSections(rawValue: indexPath.section) else {
      return height
    }

    switch inferenceSection {
    case .Results:
      if indexPath.row == maxResults - 1 {
        height = 42.0 + 21.0
      }
      else {
        height = 27.0
      }
    }
    return height
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let cell = tableView.dequeueReusableCell(withIdentifier: "INFO_CELL") as! InfoCell

    guard let inferenceSection = InferenceSections(rawValue: indexPath.section) else {
      return cell
    }

    var fieldName = ""
    var info = ""
    var font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
    var color = infoTextColor

    switch inferenceSection {
    case .Results:

      let tuple = displayStringsForResults(atRow: indexPath.row)
      fieldName = tuple.0
      info = tuple.1

      if indexPath.row == 0 {
        font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        color = infoTextColor
      }
      else {
        font = UIFont.systemFont(ofSize: 14.0, weight: .regular)
        color = UIColor(displayP3Red: 117.0/255.0, green: 117.0/255.0, blue: 117.0/255.0, alpha: 1.0)
      }


    }
    cell.fieldNameLabel.font = font
    cell.fieldNameLabel.textColor = color
    cell.fieldNameLabel.text = fieldName
    InferenceViewController.getResult = fieldName
    return cell
  }

  func displayStringsForResults(atRow row: Int) -> (String, String) {

    var fieldName: String = ""
    var info: String = ""

    guard let tempResult = inferenceResult, tempResult.inferences.count > 0 else {

      if row == 1 {
        fieldName = "No Results"
        info = ""
      }
      else {
        fieldName = ""
        info = ""
      }
      return (fieldName, info)
    }

    if row < tempResult.inferences.count {
      let inference = tempResult.inferences[row]
      fieldName = inference.label
      info =  String(format: "%.2f", inference.confidence * 100.0) + "%"
    }
    else {
      fieldName = ""
      info = ""
    }

    return (fieldName, info)
  }
  func displayStringsForInferenceInfo(atRow row: Int) -> (String, String) {

    var fieldName: String = ""
    var info: String = ""

    guard let inferenceInfo = InferenceInfo(rawValue: row) else {
      return (fieldName, info)
    }

    fieldName = inferenceInfo.displayString()

    switch inferenceInfo {
    case .Resolution:
      info = "\(Int(resolution.width))x\(Int(resolution.height))"
    case .Crop:
      info = "\(wantedInputWidth)x\(wantedInputHeight)"
    case .InferenceTime:
      guard let finalResults = inferenceResult else {
        info = "0ms"
        break
      }
      info = String(format: "%.2fms", finalResults.inferenceTime)
    }

    return(fieldName, info)
  }
}
