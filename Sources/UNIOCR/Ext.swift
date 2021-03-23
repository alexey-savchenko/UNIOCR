//
//  File.swift
//
//
//  Created by Alexey Savchenko on 22.03.2021.
//

import UIKit

public extension UILabel {
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
