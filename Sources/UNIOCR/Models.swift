//
//  Models.swift
//  ReaddleOCR
//
//  Created by Alexey Savchenko on 22.03.2021.
//

import Foundation
import UIKit

public enum OCRError: Error {
  case invalidInputImage
  case other(error: Error)
}

public struct OCRResult {
  public let pdfData: Data
  public let content: String
}

public enum Mode: Int {
  case vision
  case external

  var name: String {
    switch self {
    case .external:
      return "External"
    case .vision:
      return "Vision"
    }
  }
}

public struct Quadrilateral {
  public let bottomLeft: CGPoint
  public let bottomRight: CGPoint
  public let topLeft: CGPoint
  public let topRight: CGPoint

  public init(
    bottomLeft: CGPoint,
    bottomRight: CGPoint,
    topLeft: CGPoint,
    topRight: CGPoint
  ) {
    self.bottomLeft = bottomLeft
    self.bottomRight = bottomRight
    self.topLeft = topLeft
    self.topRight = topRight
  }

  public func toCartesian() -> Quadrilateral {
    return .init(
      bottomLeft: bottomLeft.applying(.init(scaleX: 1, y: -1)).applying(.init(translationX: 0, y: 1)),
      bottomRight: bottomRight.applying(.init(scaleX: 1, y: -1)).applying(.init(translationX: 0, y: 1)),
      topLeft: topLeft.applying(.init(scaleX: 1, y: -1)).applying(.init(translationX: 0, y: 1)),
      topRight: topRight.applying(.init(scaleX: 1, y: -1)).applying(.init(translationX: 0, y: 1))
    )
  }

  public func toAbsolutePointsRelativeTo(_ realSize: CGSize) -> Quadrilateral {
    return .init(
      bottomLeft: CGPoint(
        x: bottomLeft.x * realSize.width,
        y: bottomLeft.y * realSize.height
      ),
      bottomRight: CGPoint(
        x: bottomRight.x * realSize.width,
        y: bottomRight.y * realSize.height
      ),
      topLeft: CGPoint(
        x: topLeft.x * realSize.width,
        y: topLeft.y * realSize.height
      ),
      topRight: CGPoint(
        x: topRight.x * realSize.width,
        y: topRight.y * realSize.height
      )
    )
  }

  public func cgRect() -> CGRect {
    return .init(
      x: bottomLeft.x,
      y: bottomLeft.y,
      width: max(bottomRight.x, bottomLeft.x) - min(bottomRight.x, bottomLeft.x),
      height: max(topRight.y, bottomRight.y) - min(topRight.y, bottomRight.y)
    )
  }

  public func bezierPath() -> UIBezierPath {
    let path = UIBezierPath()
    path.move(to: bottomLeft)
    path.addLine(to: bottomRight)
    path.addLine(to: topRight)
    path.addLine(to: topLeft)
    path.addLine(to: bottomLeft)
    return path
  }
  
  func applying(_ transform: CGAffineTransform) -> Quadrilateral {
    return Quadrilateral(
      bottomLeft: bottomLeft.applying(transform),
      bottomRight: bottomRight.applying(transform),
      topLeft: topLeft.applying(transform),
      topRight: topRight.applying(transform)
    )
  }
}

struct RecognizedTextResult {
  let quad: Quadrilateral
  let string: String
}

struct DrawableRecognizedTextResult {
  let string: String
  let rect: CGRect
  let fontSize: CGFloat
  let rawQuad: Quadrilateral
}

struct OCRRequestData {
  let image: UIImage
  let intermediateResult: DrawableRecognizedTextResult
}
