//
//  File.swift
//
//
//  Created by Alexey Savchenko on 22.03.2021.
//

import UIKit

extension CGSize: Comparable {
  public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
    return (lhs.width * lhs.height) < (rhs.width * rhs.height)
  }
}

extension UILabel {
  var actualFontSize: CGFloat {
    // initial label
    let fullSizeLabel = UILabel()
    fullSizeLabel.font = self.font
    fullSizeLabel.text = self.text
    fullSizeLabel.sizeToFit()

    var actualFontSize: CGFloat = self.font.pointSize * (self.bounds.size.width / fullSizeLabel.bounds.size.width)

    // correct, if new font size bigger than initial
    actualFontSize = actualFontSize < self.font.pointSize ? actualFontSize : self.font.pointSize

    return actualFontSize
  }
}

extension UIImage {
  func fixedOrientation() -> UIImage? {
    guard imageOrientation != UIImage.Orientation.up else {
      // This is default orientation, don't need to do anything
      return self.copy() as? UIImage
    }

    guard let cgImage = self.cgImage else {
      // CGImage is not available
      return nil
    }

    guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(
      data: nil,
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: cgImage.bitsPerComponent,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil // Not able to create CGContext
    }

    var transform: CGAffineTransform = CGAffineTransform.identity

    switch imageOrientation {
    case .down, .downMirrored:
      transform = transform.translatedBy(x: size.width, y: size.height)
      transform = transform.rotated(by: CGFloat.pi)
    case .left, .leftMirrored:
      transform = transform.translatedBy(x: size.width, y: 0)
      transform = transform.rotated(by: CGFloat.pi / 2.0)
    case .right, .rightMirrored:
      transform = transform.translatedBy(x: 0, y: size.height)
      transform = transform.rotated(by: CGFloat.pi / -2.0)
    case .up, .upMirrored:
      break
    @unknown default:
      break
    }

    // Flip image one more time if needed to, this is to prevent flipped image
    switch imageOrientation {
    case .upMirrored, .downMirrored:
      transform = transform.translatedBy(x: size.width, y: 0)
      transform = transform.scaledBy(x: -1, y: 1)
    case .leftMirrored, .rightMirrored:
      transform = transform.translatedBy(x: size.height, y: 0)
      transform = transform.scaledBy(x: -1, y: 1)
    case .up, .down, .left, .right:
      break
    @unknown default:
      break
    }

    ctx.concatenate(transform)

    switch imageOrientation {
    case .left, .leftMirrored, .right, .rightMirrored:
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
    default:
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    guard let newCGImage = ctx.makeImage() else { return nil }
    return UIImage(cgImage: newCGImage, scale: 1, orientation: .up)
  }

  /// Represents a scaling mode
  enum ScalingMode {
    case aspectFill
    case aspectFit

    /// Calculates the aspect ratio between two sizes
    ///
    /// - parameters:
    ///     - size:      the first size used to calculate the ratio
    ///     - otherSize: the second size used to calculate the ratio
    ///
    /// - return: the aspect ratio between the two sizes
    func aspectRatio(between size: CGSize, and otherSize: CGSize) -> CGFloat {
      let aspectWidth = size.width / otherSize.width
      let aspectHeight = size.height / otherSize.height

      switch self {
      case .aspectFill:
        return max(aspectWidth, aspectHeight)
      case .aspectFit:
        return min(aspectWidth, aspectHeight)
      }
    }
  }

  /// Scales an image to fit within a bounds with a size governed by the passed size. Also keeps the aspect ratio.
  ///
  /// - parameter:
  ///     - newSize:     the size of the bounds the image must fit within.
  ///     - scalingMode: the desired scaling mode
  ///
  /// - returns: a new scaled image.
  func scaled(to newSize: CGSize, scalingMode: UIImage.ScalingMode = .aspectFill) -> UIImage {
    let aspectRatio = scalingMode.aspectRatio(between: newSize, and: size)

    /* Build the rectangle representing the area to be drawn */
    var scaledImageRect = CGRect.zero

    scaledImageRect.size.width = size.width * aspectRatio
    scaledImageRect.size.height = size.height * aspectRatio
    scaledImageRect.origin.x = (newSize.width - size.width * aspectRatio) / 2.0
    scaledImageRect.origin.y = (newSize.height - size.height * aspectRatio) / 2.0

    /* Draw and retrieve the scaled image */
    UIGraphicsBeginImageContext(newSize)

    draw(in: scaledImageRect)
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()

    return scaledImage!
  }
}
