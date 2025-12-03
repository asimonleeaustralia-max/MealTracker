//
//  PersistenceController.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let container = NSPersistentContainer(name: "MealTracker")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration attempts
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Preflight compatibility (on-disk only) and nuke in Debug if incompatible
        if !inMemory, let storeURL = description.url {
            do {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                                                                           at: storeURL,
                                                                                           options: description.options)
                let compatible = container.managedObjectModel
                    .isConfiguration(withName: description.configuration, compatibleWithStoreMetadata: metadata)
                #if DEBUG
                if !compatible {
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL,
                                                                                    ofType: NSSQLiteStoreType,
                                                                                    options: description.options)
                }
                #endif
            } catch {
                // If metadata can't be read, continue; we'll also handle failure in load below.
            }
        }

        // Important: avoid capturing self in the escaping closure during init.
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                #if DEBUG
                // Development fallback: destroy incompatible store and retry once
                if let url = storeDescription.url {
                    do {
                        try container.persistentStoreCoordinator.destroyPersistentStore(at: url,
                                                                                        ofType: NSSQLiteStoreType,
                                                                                        options: storeDescription.options)
                        container.loadPersistentStores { _, retryError in
                            if let retryError = retryError {
                                let nserr = retryError as NSError
                                fatalError("Unresolved error after destroying store: \(nserr), \(nserr.userInfo)")
                            }
                        }
                        return
                    } catch {
                        let nserr = error as NSError
                        fatalError("Unresolved error \(nserr), \(nserr.userInfo)")
                    }
                }
                #endif
                fatalError("Unresolved error \(error), \((error as NSError).userInfo)")
            }
        }

        // Recommended context settings
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Assign to property last
        self.container = container
    }
}
