//
//  Backend.swift
//  ReaddleOCR
//
//  Created by Alexey Savchenko on 19.03.2021.
//

import UIKit
import Moya

enum Backend: TargetType {
  case ocr(image: UIImage, token: String)

  var token: String {
    switch self {
    case .ocr(_, let token):
      return token
    }
  }

  var baseURL: URL {
    return URL(string: "https://develop.scanguru.app")!
  }

  var path: String {
    return "/api/v1/vision/"
  }

  var method: Moya.Method {
    return .post
  }

  var sampleData: Data {
    return Data()
  }

  var task: Task {
    switch self {
    case .ocr(let image, let token):
      let data = image.jpegData(compressionQuality: 0.8) ?? Data()
      return .uploadCompositeMultipart(
        [
          MultipartFormData(
            provider: MultipartFormData.FormDataProvider.data(data),
            name: "file",
            fileName: "page",
            mimeType: "image/jpeg"
          )
        ],
        urlParameters: ["token": token]
      )
    }
  }

  var headers: [String: String]? {
    return nil
  }
}
