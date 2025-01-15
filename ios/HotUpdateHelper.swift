//
//  HotUpdate.swift
//  TestProject
//
//  Created by Deepak Pradhan on 12/01/25.
//
import Foundation
import FirebaseStorage
import SSZipArchive
import CryptoKit

@objc public class HotUpdate: NSObject {
  
  static let DEFAULT_JS_BUNDLE_NAME = "main.jsbundle"
  static let DEFAULT_DOWNLOAD_FILE_NAME = "bundle.zip"
  static let UPDATE_VERSION_KEY = "HBHotUpdateVersion"
  static let UPDATE_BUNDLE_HASH = "HBHotUpdateBundleHash"
  static let UPDATE_DIRECTORY_NAME = "HotUpdate"
  static let DOWNLOAD_DIRECTORY_NAME = "temp"
  
  @objc public class func getBundleURL() -> URL {
    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let preferences = UserDefaults.standard
    if let version = preferences.string(forKey: UPDATE_VERSION_KEY) {
      let updateDirectoryUrl = documentsUrl.appendingPathComponent(UPDATE_DIRECTORY_NAME)
      let bundleUrl = updateDirectoryUrl.appendingPathComponent("\(version)/\(DEFAULT_JS_BUNDLE_NAME)")
      if FileManager().fileExists(atPath: bundleUrl.path) {
        if let bundleHash = preferences.string(forKey: UPDATE_VERSION_KEY) {
          if (verifyFileAt(path: bundleUrl, expectedHash: bundleHash)) {
            return bundleUrl
          } else {
            deleteFiles(at: updateDirectoryUrl.path)
          }
        }
      }
    }
    return Bundle.main.url(forResource: "main", withExtension: "jsbundle")!
  }
  
  @objc public class func getUpdatedBundle(for version: String, with archiveHash: String, and bundleHash: String) {
    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let updateDirectoryUrl = documentsUrl.appendingPathComponent(UPDATE_DIRECTORY_NAME)
    let destinationUrl = updateDirectoryUrl.appendingPathComponent(version)
    let existingUpdatePath = destinationUrl.appendingPathComponent(DEFAULT_JS_BUNDLE_NAME)
    if FileManager().fileExists(atPath: existingUpdatePath.path) {
      return
    }
    
    //Remove any previous downloads
    deleteFiles(at: updateDirectoryUrl.path)
    
    // Get a reference to the storage service using the default Firebase App
    let storage = Storage.storage()
    
    // Create a storage reference from our storage service
    let storageRef = storage.reference()
    
    //Create temp directory to download
    let tempDirectoryUrl = documentsUrl.appendingPathComponent(DOWNLOAD_DIRECTORY_NAME)
    let downloadFileUrl = tempDirectoryUrl.appendingPathComponent(DEFAULT_DOWNLOAD_FILE_NAME)
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    
    let childPath = "\(UPDATE_DIRECTORY_NAME)/ios/\(appVersion)/\(version)/\(DEFAULT_DOWNLOAD_FILE_NAME)"
    
    let bundleRef = storageRef.child(childPath)
    
    // Download to the local filesystem
    let _ = bundleRef.write(toFile: downloadFileUrl) { url, error in
      if let error = error {
        print("Uh-oh, an error occurred!: %@", error.localizedDescription)
      } else {
        let isValidArchive = verifyFileAt(path: downloadFileUrl, expectedHash: archiveHash)
        if isValidArchive {
          let success = SSZipArchive.unzipFile(atPath: downloadFileUrl.path, toDestination: destinationUrl.path)
          if success {
            if (verifyFileAt(path: destinationUrl.appendingPathComponent(DEFAULT_JS_BUNDLE_NAME), expectedHash: bundleHash)) {
              let preferences = UserDefaults.standard
              preferences.set(version, forKey: UPDATE_VERSION_KEY)
              preferences.set(bundleHash, forKey: UPDATE_BUNDLE_HASH)
              preferences.synchronize()
            }
            deleteFiles(at: updateDirectoryUrl.path)
          }
        }
        deleteFiles(at: tempDirectoryUrl.path)
      }
    }
  }
  
  class func deleteFiles(at path: String) {
    do {
      try FileManager.default.removeItem(atPath: path)
    } catch {
      print("Uh-oh, an error occurred!: %@", error.localizedDescription)
    }
  }
  
  class func verifyFileAt(path: URL, expectedHash: String) -> Bool {
    do {
      let data = try Data(contentsOf: path)
      let hashString = getSHA256HashFor(data: data)
      return hashString == expectedHash
    } catch {
      return false
    }
  }
  
  class func getSHA256HashFor(data: Data) -> String {
    let hashedData = SHA256.hash(data: data)
    return hashedData.map { String(format: "%02x", $0) }.joined()
  }
}
