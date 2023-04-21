//
//  ModelDataHandler.swift
//  ASMR
//
//  Created by Li Cheuk Yin on 20/1/2021.
//  Copyright © 2021 Li Cheuk Yin. All rights reserved.
//

import Foundation
import CoreImage
import TensorFlowLite
import UIKit
import Accelerate

struct Result {
  let inferenceTime: Double
  let inferences: [Inference]
}

struct Inference {
  let confidence: Float
  let label: String
}

typealias FileInfo = (name: String, extension: String)

enum MobileNet {
  static let modelInfo: FileInfo = (name: "model_unquant", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "labels", extension: "txt")
}
class ModelDataHandler {

  let threadCount: Int
  let threadCountLimit = 10
  private var labels: [String] = []
  private var interpreter: Interpreter
  private let alphaComponent = (baseOffset: 4, moduloRemainder: 3)

  init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, threadCount: Int = 1) {
    let modelFilename = modelFileInfo.name
    guard let modelPath = Bundle.main.path(
      forResource: modelFilename,
      ofType: modelFileInfo.extension
    ) else {
      print("Error")
      return nil
    }

    self.threadCount = threadCount
    var options = InterpreterOptions()
    options.threadCount = threadCount
    do {
      interpreter = try Interpreter(modelPath: modelPath, options: options)
      try interpreter.allocateTensors()
    } catch let error {
      print("Error")
      return nil
    }
    loadLabels(fileInfo: labelsFileInfo)
  }
  func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
    
    let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
             sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)


    let imageChannels = 4
    assert(imageChannels >= 3)

    let scaledSize = CGSize(width: 224, height: 224)
    guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: scaledSize) else {
      return nil
    }

    let interval: TimeInterval
    let outputTensor: Tensor
    do {
      let inputTensor = try interpreter.input(at: 0)
      guard let rgbData = rgbDataFromBuffer(
        thumbnailPixelBuffer,
        byteCount: 1 * 224 * 224 * 3,
        isModelQuantized: inputTensor.dataType == .uInt8
      ) else {
        print("Error")
        return nil
      }

      try interpreter.copy(rgbData, toInputAt: 0)

      let startDate = Date()
      try interpreter.invoke()
      interval = Date().timeIntervalSince(startDate) * 1000

      outputTensor = try interpreter.output(at: 0)
    } catch let error {
      print("Error")
      return nil
    }

    let results: [Float]
    switch outputTensor.dataType {
    case .uInt8:
      guard let quantization = outputTensor.quantizationParameters else {
        print("Error")
        return nil
      }
      let quantizedResults = [UInt8](outputTensor.data)
      results = quantizedResults.map {
        quantization.scale * Float(Int($0) - quantization.zeroPoint)
      }
    case .float32:
      results = [Float32](unsafeData: outputTensor.data) ?? []
    default:
      print("Error")
      return nil
    }


    let topNInferences = getTopN(results: results)
    return Result(inferenceTime: interval, inferences: topNInferences)
  }

  private func getTopN(results: [Float]) -> [Inference] {
    let zippedResults = zip(labels.indices, results)
    let sortedResults = zippedResults.sorted { $0.1 > $1.1 }.prefix(1)
    return sortedResults.map { result in Inference(confidence: result.1, label: labels[result.0]) }
  }


  private func loadLabels(fileInfo: FileInfo) {
    let filename = fileInfo.name
    let fileExtension = fileInfo.extension
    guard let fileURL = Bundle.main.url(forResource: filename, withExtension: fileExtension) else {
      fatalError("Error")
    }
    do {
      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      labels = contents.components(separatedBy: .newlines)
    } catch {
      fatalError("Error")
    }
  }

  private func rgbDataFromBuffer(
    _ buffer: CVPixelBuffer,
    byteCount: Int,
    isModelQuantized: Bool
  ) -> Data? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
    guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
      return nil
    }
    
    var sourceBuffer = vImage_Buffer(data: sourceData,
                                     height: vImagePixelCount(CVPixelBufferGetHeight(buffer)),
                                     width: vImagePixelCount(CVPixelBufferGetWidth(buffer)),
                                     rowBytes: CVPixelBufferGetBytesPerRow(buffer))
    
    guard let destinationData = malloc(CVPixelBufferGetHeight(buffer) * 3 * CVPixelBufferGetWidth(buffer)) else {
      print("Error")
      return nil
    }
    
    defer {
        free(destinationData)
    }

    var destinationBuffer = vImage_Buffer(data: destinationData,
                                          height: vImagePixelCount(CVPixelBufferGetHeight(buffer)),
                                          width: vImagePixelCount(CVPixelBufferGetWidth(buffer)),
                                          rowBytes: 3 * CVPixelBufferGetWidth(buffer))

    let pixelBufferFormat = CVPixelBufferGetPixelFormatType(buffer)

    switch (pixelBufferFormat) {
    case kCVPixelFormatType_32BGRA:
        vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    case kCVPixelFormatType_32ARGB:
        vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    case kCVPixelFormatType_32RGBA:
        vImageConvert_RGBA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    default:

        return nil
    }

    let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * CVPixelBufferGetHeight(buffer))
    if isModelQuantized {
        return byteData
    }

    let bytes = Array<UInt8>(unsafeData: byteData)!
    var floats = [Float]()
    for i in 0..<bytes.count {
        floats.append(Float(bytes[i]) / 255.0)
    }
    return Data(copyingBufferOf: floats)
  }
}


extension Data {
  init<T>(copyingBufferOf array: [T]) {
    self = array.withUnsafeBufferPointer(Data.init)
  }
}

extension Array {
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif
  }
}
