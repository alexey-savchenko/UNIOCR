
import UIKit
import Vision
import CoreImage
import Moya

public class OCRService {
  let token: String
  let provider = MoyaProvider<Backend>()

  public init(token: String) {
    self.token = token
  }

  public func process(
    _ image: UIImage,
    mode: Mode,
    debug: Bool = false,
    completion: @escaping (Result<OCRResult, OCRError>) -> Void
  ) {
    guard
      let cgImage = image.cgImage
    else {
      completion(.failure(.invalidInputImage))
      return
    }
    
    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
    let request = VNRecognizeTextRequest { [weak self] request, error in
      guard let self = self else { return }
      if let error = error {
        completion(.failure(.other(error: error)))
        return
      }

      self.requestHandler(
        request: request,
        inputImage: image,
        mode: mode,
        completion: completion
      )
    }

    request.recognitionLevel = .accurate

    if #available(iOS 14.0, *) {
      let langs2 = try! VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision2)
      request.revision = VNRecognizeTextRequestRevision2
      request.recognitionLanguages = langs2
    }

    do {
      try requestHandler.perform([request])
    } catch {
      completion(.failure(.other(error: error)))
    }
  }

  private func requestHandler(
    request: VNRequest,
    inputImage: UIImage,
    mode: Mode,
    debug: Bool = false,
    completion: @escaping (Result<OCRResult, OCRError>) -> Void
  ) {
    let overlay = CIImage(color: CIColor(color: UIColor.white.withAlphaComponent(0.5)))
      .cropped(to: CGRect(origin: .zero, size: inputImage.size))
    let ciImage = CIImage(image: inputImage)!
      .applyingGaussianBlur(sigma: 10)
      .clampedToExtent()
      .cropped(to: CGRect(origin: .zero, size: inputImage.size))
    let res = overlay.composited(over: ciImage)
    let ctx = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)
    let filteredImage = ctx.createCGImage(res, from: res.extent).flatMap(UIImage.init)!

    switch mode {
    case .server:
      let rawResults = self.processRawResults(request: request)
      let requestDataArray = rawResults.compactMap { rawResult -> OCRRequestData? in
        autoreleasepool {
          let intermediateResult = self.processResult(rawResult, imageSize: filteredImage.size)
          let croppedCIImage = CIImage(image: inputImage)!
            .transformed(by: .init(scaleX: 1, y: -1))
            .transformed(by: .init(translationX: 0, y: inputImage.size.height))
            .cropped(to: intermediateResult.rect)
            .transformed(by: .init(scaleX: 1, y: -1))
            .transformed(by: .init(translationX: 0, y: inputImage.size.height))

          let croppedUIImage = ctx.createCGImage(croppedCIImage, from: croppedCIImage.extent).flatMap(UIImage.init)
          return croppedUIImage.map { value in OCRRequestData(image: value, intermediateResult: intermediateResult) }
        }
      }

      var drawableResults = [DrawableRecognizedTextResult]()

      let dispatchGroup = DispatchGroup()

      requestDataArray.forEach { value in
        dispatchGroup.enter()
        provider.request(.ocr(image: value.image, token: self.token)) { result in

          switch result {
          case .success(let response):
            if let text = (try? JSONDecoder().decode(OCRServerResponse.self, from: response.data))?.text {
              let s = try! NSAttributedString(
                data: Data(text.utf8),
                options: [
                  .documentType: NSAttributedString.DocumentType.html,
                  .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
              .string
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .replacingOccurrences(of: "\n", with: " ")

              if s.lowercased().contains("техника") {
                print("")
              }

              drawableResults.append(
                DrawableRecognizedTextResult(
                  string: s,
                  rect: value.intermediateResult.rect,
                  fontSize: value.intermediateResult.fontSize,
                  rawQuad: value.intermediateResult.rawQuad
                )
              )
            }
          case .failure(let error):
            print(error)
          }

          dispatchGroup.leave()
        }
      }

      dispatchGroup.notify(queue: .main) {
        let transcribedString = drawableResults.reduce(into: "") { result, recogResult in
          result.append(recogResult.string.appending("\n"))
        }
        let data = self.makePDFData(drawableResults: drawableResults, backgroundImage: filteredImage)

        completion(.success(.init(pdfData: data, content: transcribedString)))
      }

    case .vision:
      let rawResults = self.processRawResults(request: request)

      let transcribedString = rawResults.reduce(into: "") { result, recogResult in
        result.append(recogResult.string.appending("\n"))
      }

      let drawableResults = rawResults.map { r in self.processResult(r, imageSize: filteredImage.size) }
      let data = self.makePDFData(drawableResults: drawableResults, backgroundImage: filteredImage)
      completion(.success(.init(pdfData: data, content: transcribedString)))
    }
  }

  private func makePDFData(
    drawableResults: [DrawableRecognizedTextResult],
    backgroundImage: UIImage,
    debug: Bool = false
  ) -> Data {
    let pageRect = CGRect(origin: .zero, size: backgroundImage.size)
    let render = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
    return render.pdfData { ctx in
      ctx.beginPage()
      backgroundImage.draw(in: pageRect)
      drawableResults.forEach { result in

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .natural
        let attrString = NSAttributedString(
          string: result.string,
          attributes: [
            .font: UIFont.systemFont(ofSize: result.fontSize),
            .paragraphStyle: paragraphStyle,
          ]
        )

        // try rotate
        //        ctx.cgContext.saveGState()
        //        let absQuad = result.rawQuad.toCartesian().toAbsolutePointsRelativeTo(backgroundImage.size)
        //        var rotation: CGFloat {
        //          let a = atan2(absQuad.bottomLeft.y - absQuad.bottomRight.y, absQuad.bottomLeft.x - absQuad.bottomRight.x)
        //          let b = atan2(0 - CGFloat.infinity, 0)
        //          var c = (b - a) * 180 / .pi
        //          if c < 0 {
        //            c += 360
        //          }
        //          return c * .pi / 180
        //        }
        //        print("\(result.string) \(rotation * 180.0 / .pi)")
        //        ctx.cgContext.translateBy(x: absQuad.bottomLeft.x, y: absQuad.bottomLeft.y)
        //        ctx.cgContext.rotate(by: rotation)
        //        ctx.cgContext.translateBy(x: -absQuad.bottomLeft.x, y: -absQuad.bottomLeft.y)

        attrString.draw(at: result.rect.origin.applying(.init(translationX: 0, y: -result.rect.height * 0.3)))
        //        ctx.cgContext.restoreGState()

        if debug {
          UIColor.red.withAlphaComponent(0.5).setFill()
          ctx.cgContext.fill(result.rect)
          let dot = UIBezierPath(ovalIn: .init(x: result.rect.origin.x - 5, y: result.rect.origin.y - 5, width: 10, height: 10)).cgPath
          ctx.cgContext.addPath(dot)
          UIColor.blue.withAlphaComponent(0.5).setFill()
          ctx.cgContext.fillPath()
          let absQuad = result.rawQuad.toCartesian().toAbsolutePointsRelativeTo(backgroundImage.size)
          let path = absQuad.bezierPath()
          ctx.cgContext.addPath(path.cgPath)
          ctx.cgContext.fillPath()
        }
      }
    }
  }

  private func processRawResults(request: VNRequest) -> [RecognizedTextResult] {
    guard
      let observations = request.results as? [VNRecognizedTextObservation]
    else {
      return []
    }

    let recognizedTexts = observations.compactMap { (observation: VNRecognizedTextObservation) -> RecognizedTextResult in
      let candidate = observation.topCandidates(1)[0]

      return RecognizedTextResult(
        quad: Quadrilateral(
          bottomLeft: observation.bottomLeft,
          bottomRight: observation.bottomRight,
          topLeft: observation.topLeft,
          topRight: observation.topRight
        ),
        string: candidate.string
      )
    }

    return recognizedTexts
  }

  private func processResult(_ result: RecognizedTextResult, imageSize: CGSize) -> DrawableRecognizedTextResult {
    return DispatchQueue.main.sync {
      let label = UILabel()
      var frame = result.quad.toCartesian().toAbsolutePointsRelativeTo(imageSize).cgRect()
      frame = frame.applying(.init(translationX: 0, y: -frame.height))
      label.font = UIFont.systemFont(ofSize: 100)
      label.frame = frame
      label.text = result.string
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.01
      label.baselineAdjustment = .alignCenters
      let fontSize = label.actualFontSize
      return .init(string: result.string, rect: frame, fontSize: fontSize, rawQuad: result.quad)
    }
  }
}
