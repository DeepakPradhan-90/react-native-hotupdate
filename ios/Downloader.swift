//
//  Downloader.swift
//  TestProject
//
//  Created by Deepak Pradhan on 12/01/25.
//
import Foundation

@objc public class Downloader: NSObject {
  @objc public class func load(url: URL, to localUrl: URL, completion: @escaping () -> ()) {
    let sessionConfig = URLSessionConfiguration.default
    let session = URLSession(configuration: sessionConfig)
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
      if let tempLocalUrl = tempLocalUrl, error == nil {
        // Success
        if let statusCode = (response as? HTTPURLResponse)?.statusCode {
          print("Success: \(statusCode)")
        }
        
        do {
          try FileManager.default.copyItem(at: tempLocalUrl, to: localUrl)
          completion()
        } catch (let writeError) {
          print("error writing file \(localUrl) : \(writeError)")
        }
        
      } else {
        print("Failure: %@", error?.localizedDescription);
      }
    }
    task.resume()
  }
}
