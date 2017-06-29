import UIKit
import CoreData

class CoreDataConnection: NSObject {
  
  static let sharedInstance = CoreDataConnection()
  
  static let kItem = "Item"
  static let kFilename = "TodoSwift"
  
  // MARK: - Core Data stack
  
  lazy var persistentContainer: NSPersistentContainer = {
    
    let container = NSPersistentContainer(name: CoreDataConnection.kFilename)
    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
      if let error = error as NSError? {
        
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    })
    return container
  }()
  
  // MARK: - Core Data Saving support
  
  func saveContext () {
    let context = CoreDataConnection.sharedInstance.persistentContainer.viewContext
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }
  
  func deleteManagedObject( managedObject: NSManagedObject, completion:(_ result: Bool ) -> Void) {
    
    let managedContext =
      CoreDataConnection.sharedInstance.persistentContainer.viewContext
    
    managedContext.delete(managedObject)
    
    do {

      try managedContext.save()
      completion(true)
      
    } catch let error as NSError {
      print("Could not save. \(error), \(error.userInfo)")
      completion(false)
    }
    
  }
  
}
