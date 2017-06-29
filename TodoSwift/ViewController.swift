//
//  ViewController.swift
//  TodoSwift
//
//  Created by Hijazi on 28/12/16.
//  Copyright © 2016 iReka Soft. All rights reserved.
//

import UIKit
import KCFloatingActionButton
import CoreData
import DZNEmptyDataSet
import CloudKit
import UserNotifications
import AudioToolbox

class ViewController: UIViewController,UITableViewDataSource, UITableViewDelegate, KCFloatingActionButtonDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, UNUserNotificationCenterDelegate {
  
  @IBOutlet var emptyView: UIView!
  
  
  
  @IBOutlet weak var tableView: UITableView!
  var ck : CloudKitHelper!
  
  var isUsingICloud = false
  
  var coreData = CoreDataConnection.sharedInstance
  
  var itemsFromCoreData: [NSManagedObject] {
    
    get {
      
      var resultArray:Array<NSManagedObject>!
      let managedContext = coreData.persistentContainer.viewContext
      //2
      let fetchRequest =
        NSFetchRequest<NSManagedObject>(entityName: CoreDataConnection.kItem)
      //3
      do {
        resultArray = try managedContext.fetch(fetchRequest)
      } catch let error as NSError {
        print("Could not fetch. \(error), \(error.userInfo)")
      }
      
      return resultArray
    }
    
  }
  
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    let managedContext =
      CoreDataConnection.sharedInstance.persistentContainer.viewContext
    //2
    let fetchRequest =
      NSFetchRequest<NSManagedObject>(entityName: CoreDataConnection.kItem)
    
    
   
  }
  
  func longPressHandler(sender: UILongPressGestureRecognizer){
    
    if sender.state == UIGestureRecognizerState.began {
      
      let touchPoint = sender.location(in: self.view)
      if let indexPath = self.tableView.indexPathForRow(at:touchPoint) {
        print("in \(indexPath)")
        
      }
      
    }
  }
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    
    UNUserNotificationCenter.current().delegate = self
    
    UNUserNotificationCenter.current().getDeliveredNotifications { (notifications) in
      print("delivered notif \(notifications)")
    }
    
    let fab = KCFloatingActionButton()
    fab.fabDelegate = self
    
    self.view.addSubview(fab)
    
    self.tableView.tableFooterView = UIView()
    self.tableView.emptyDataSetSource = self
    self.tableView.emptyDataSetDelegate = self
    
    // check iCloud
    
    let val = CloudKitHelper.isICloudContainerAvailable()
    print("have icloud? \(val)")
    
    if (val == true){
      ck = CloudKitHelper.sharedInstance()
      
      // ask user to download from iCloud since your row is empty
      
      // normal sync is when to update matching sync
      sync()
      
      // subscribe notif
      subscribeForNotification()
      
      isUsingICloud = true
      
    }else{
      isUsingICloud = false
    }
    
    // add long press
    // tapRecognizer, placed in viewDidLoad
    let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressHandler))
    self.tableView.addGestureRecognizer(longPressRecognizer)
    
  }
  
  // MARK: KCFloatingActionButtonDelegate
  func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
    return UIImage(named: "add");
  }
  
  func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
    let text = "empty"
    
    let attributes = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: 23.0),
                      NSForegroundColorAttributeName: UIColor.darkGray];
    
    return NSAttributedString.init(string: text, attributes: attributes)
    
  }
  
  func emptyKCFABSelected(_ fab: KCFloatingActionButton){
    let alert = UIAlertController(title: "New Item",
                                  message: "Name of the new item",
                                  preferredStyle: .alert)
    
    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .cancel)
    alert.addAction(cancelAction)
    
    let saveAction = UIAlertAction(title: "Save",style: .default) {
      [unowned self] action in
      
      guard let textField = alert.textFields?.first,
        let nameToSave = textField.text else {
          return
      }
      self.saveToCoreData(nameToSave, progress:0.0)
      self.tableView.reloadData()
    }
    
    alert.addTextField()
    alert.addAction(saveAction)
    
    present(alert, animated: true)
  }
  
  // MARK: - CoreData
  
  func saveToCoreData(_ title: String, progress: Double){

    // SAVE to CloudKit
    let todoRecord = CKRecord(recordType: "TodoList")
    
    if isUsingICloud == true {
      
      todoRecord.setValue(title, forKey: "title")
      todoRecord.setValue(progress, forKey: "progress")
      
      ck.privateDB.save(todoRecord) { (record, error) in
        
        print("cloudkit \(record!)")

      }
      
    }
    
    
    // save core data
    let managedContext =
      CoreDataConnection.sharedInstance.persistentContainer.viewContext
    
    let entity =
      NSEntityDescription.entity(forEntityName: CoreDataConnection.kItem,
                                 in: managedContext)!
    
    let item = NSManagedObject(entity: entity,
                               insertInto: managedContext) as! Item
    
    item.title = title
    item.progress = progress
    item.recordID = todoRecord.recordID.recordName
    
    // 4
    do {
      try managedContext.save()
    } catch let error as NSError {
      print("Could not save. \(error), \(error.userInfo)")
    }
    
  }
  
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
  // MARK: - UITableViewDataSource
  func tableView(_ tableView: UITableView,
                 numberOfRowsInSection section: Int) -> Int {
    return itemsFromCoreData.count
  }
  func tableView(_ tableView: UITableView,
                 cellForRowAt indexPath: IndexPath)
    -> UITableViewCell {
      let cell =
        tableView.dequeueReusableCell(withIdentifier:"Cell",
                                      for: indexPath)
      
      let item = itemsFromCoreData[indexPath.row] as! Item
      
      cell.textLabel?.text = item.title
      cell.detailTextLabel?.text = "\(item.progress)"
      
      return cell
  }
  
  // MARK: - UITableViewDelegate
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
    tableView.deselectRow(at: indexPath, animated: true)
    
    let item = itemsFromCoreData[indexPath.row] as! Item
    
    if (item.progress == 1.0){
      
      item.progress = 0.0
      
    }else{
      
      AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
      item.progress = 1.0
      
    }
    
    do {
      
      try CoreDataConnection.sharedInstance.persistentContainer.viewContext.save()
      
    } catch let error as NSError {
      
      print("Could not save. \(error), \(error.userInfo)")
      
    }
    
    tableView.reloadRows(at: [indexPath], with: .automatic)
    
    // update to cloudkit

    
    if isUsingICloud == true {
      
      let recordID = CKRecordID(recordName: item.recordID!)
      
      ck.privateDB.fetch(withRecordID: recordID) { (record, error) in
        
        record?.setValue(item.progress, forKey: "progress")
        
        self.ck.privateDB.save(record!) { (record, error) in
          
          print("cloudkit \(record)")
          
        }
        
      }
      
    }

    
  }
  
  // Fetch records for first time when user deside to use iCloud
  func fetchAndBuildRecords(){
    
    // check for not any duplication
    
    let predicate = NSPredicate(value: true)
    let sort = NSSortDescriptor(key: "creationDate", ascending: false)
    
    let query = CKQuery(recordType: "TodoList",
                        predicate:  predicate)
    query.sortDescriptors = [sort]
    
    ck.privateDB.perform(query, inZoneWith: nil) { (results : [CKRecord]?, error) in
      
      // no error
      if error == nil {
        
        print("error \(error)")
        
        for record in results! {
          
          let title = record.object(forKey: "title")
          print("title: \(title!), record: \(record.recordID.recordName)")
          
          let ck_recordID = record.recordID.recordName
          
          print("\(record.lastModifiedUserRecordID!.recordName)")
          print("\(record.recordType)")
          
          var hasRecordID = false
          for index in 0..<self.itemsFromCoreData.count {
            let item = self.itemsFromCoreData[index] as! Item
            
            if (ck_recordID == item.recordID){
              hasRecordID = true
            }
            
          }
          
          if (hasRecordID == false){
            
            // save core data
            let managedContext =
              CoreDataConnection.sharedInstance.persistentContainer.viewContext
            
            let entity =
              NSEntityDescription.entity(forEntityName: CoreDataConnection.kItem,
                                         in: managedContext)!
            
            let item = NSManagedObject(entity: entity,
                                       insertInto: managedContext) as! Item
            
            item.title = record.value(forKey: "title") as? String
            
            if let progress = record.value(forKey: "progress") as? Double{
              item.progress = progress
            }
            
            
            item.recordID = record.recordID.recordName
            
            
            do {
              try managedContext.save()

            } catch let error as NSError {
              print("Could not save. \(error), \(error.userInfo)")
            }

            
            DispatchQueue.main.async {
              self.tableView.reloadData()
            }
            
            
          }
          
        }
        
      }
      
    }
  }
  
  // Fetch records for first time when user deside to use iCloud
  func fetchRecords(){
    
    let predicate = NSPredicate(value: true)
    let sort = NSSortDescriptor(key: "creationDate", ascending: false)
    
    let query = CKQuery(recordType: "TodoList",
                        predicate:  predicate)
    query.sortDescriptors = [sort]
    
    ck.privateDB.perform(query, inZoneWith: nil) { (results : [CKRecord]?, error) in
      
      // no error
      if error == nil {
        
        DispatchQueue.main.async {
          self.tableView.reloadData()
        }
        
        print("error \(error)")
        
        for record in results! {
          let title = record.object(forKey: "title")
          print("title: \(title!), record: \(record.recordID.recordName)")
          
          print("\(record.lastModifiedUserRecordID!.recordName)")
          print("\(record.recordType)")
          
        }
        
      }
      
    }
    
  }
  
  func subscribeForNotification(){
    
    ck.privateDB.fetchAllSubscriptions { (subscriptions, error) in
      
      print("all subsription \(subscriptions)")
      
    }
    
    //
    let predicate = NSPredicate(value: true)
    let subscription = CKQuerySubscription(recordType: "TodoList", predicate: predicate, options: [.firesOnRecordUpdate , .firesOnRecordCreation , .firesOnRecordDeletion, .firesOnce])
    
    let notification = CKNotificationInfo()
    notification.alertBody = "There's a changes."
    notification.soundName = "Default"
    
    subscription.notificationInfo = notification
    
    ck.privateDB.save(subscription) { result, error in
      if let error = error {
        print("subscription error \(error.localizedDescription)")
      }
    }
    
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {

    return true
    
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    
    if (editingStyle == .delete){
      
      let item = itemsFromCoreData[indexPath.row] as! Item
      
      if isUsingICloud == true {
        let recordID = CKRecordID(recordName: item.recordID!)
        self.ck.privateDB.delete(withRecordID: recordID, completionHandler: { (record, error) in
          print("cloudkit \(record)")
        })
      }
      
      self.coreData.deleteManagedObject(managedObject: item, completion: { (success) in
        
        if (success){
          tableView.deleteRows(at:[indexPath], with: .automatic)
        }
        
      })
      
      
    }
  }
  
  
  // MARK: - UNUserNotificationCenterDelegate
  
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
    print("get notification \(notification.request)")
    
    completionHandler([.alert, .sound, .badge])
    
    sync()
    
  }
  
  @IBAction func refresh(_ sender: Any) {

    tableView.reloadData()
//    sync()
  
  }
  
  func sync(){
    
    // we will check with the recordID. the meta data.
    // we will check which one is the latest made changes.
    // the latest will win.
    
    let predicate = NSPredicate(value: true)
    let sort = NSSortDescriptor(key: "creationDate", ascending: false)
    
    let query = CKQuery(recordType: "TodoList",
                        predicate:  predicate)
    query.sortDescriptors = [sort]
    
    ck.privateDB.perform(query, inZoneWith: nil) { (results : [CKRecord]?, error) in
      
      // no error
      if error == nil {
        
        
        print("error \(error)")
        
        for record in results! {
          
          let title = record.object(forKey: "title")
          print("title: \(title!), record: \(record.recordID.recordName)")
          
          let ck_recordID = record.recordID.recordName
          
          print("\(record.lastModifiedUserRecordID!.recordName)")
          print("\(record.recordType)")
          
          
          var hasRecordID = false
          for index in 0..<self.itemsFromCoreData.count {
            
            let item = self.itemsFromCoreData[index] as! Item
            
            if (ck_recordID == item.recordID){
              hasRecordID = true
              item.title = record.value(forKey: "title") as? String
              if let progress = record.value(forKey: "progress") as? Double{
                item.progress = progress
              }
              
            }
            
            
          }
          // finish check with local db
          if (hasRecordID == false){
            
            // save core data
            let managedContext =
              CoreDataConnection.sharedInstance.persistentContainer.viewContext
            
            let entity =
              NSEntityDescription.entity(forEntityName: CoreDataConnection.kItem,
                                         in: managedContext)!
            
            let item = NSManagedObject(entity: entity,
                                       insertInto: managedContext) as! Item
            
            item.title = record.value(forKey: "title") as? String
            
            if let progress = record.value(forKey: "progress") as? Double{
              item.progress = progress
            }
            
            
            item.recordID = record.recordID.recordName
            
            
            do {
              try managedContext.save()
//              self.itemsFromCoreData.append(item)
            } catch let error as NSError {
              print("Could not save. \(error), \(error.userInfo)")
            }
            
            
            DispatchQueue.main.async {
              self.tableView.reloadData()
            }
            
            
          }
          
          
          
        }
        
      }
      
      do {
        try CoreDataConnection.sharedInstance.persistentContainer.viewContext.save()
      } catch let error as NSError {
        print("Could not save. \(error), \(error.userInfo)")
      }
      
      DispatchQueue.main.async {
        self.tableView.reloadData()
      }
      
    }
    
    
    
  }
  
  
  
  
}

