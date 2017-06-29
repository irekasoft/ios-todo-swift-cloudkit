//
//  CloudKitHelper.swift
//  P Cloud Kit
//
//  Created by Hijazi on 23/10/16.
//  Copyright © 2016 iReka Soft. All rights reserved.
//

import UIKit
import CloudKit

protocol CloudKitDelegate {
  
  func errorUpdating(error: NSError)
  func modelUpdated()
  
}

let cloudKitHelper = CloudKitHelper()

class CloudKitHelper {
  
  var container : CKContainer
  var publicDB : CKDatabase
  let privateDB : CKDatabase
  var delegate : CloudKitDelegate?
  var itemList = [Item]()
  
  class func sharedInstance()-> CloudKitHelper {
    return cloudKitHelper
  }
  
  class func isICloudContainerAvailable()->Bool {
    if FileManager.default.ubiquityIdentityToken != nil {
      return true
    }
    else {
      return false
    }
  }
  
  init() {
    container = CKContainer.default()
    publicDB = container.publicCloudDatabase
    privateDB = container.privateCloudDatabase
  }
  
  
}
