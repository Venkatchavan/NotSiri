// CloudKit/CloudKitSchema.swift – AgentOS
// Documents the CloudKit record types for lightweight metadata sync
// IMPORTANT: Only metadata is synced. Email bodies, file content, and AI summaries NEVER sync.

/*
 CloudKit Container: iCloud.com.agentos.app
 Database: Private (user-scoped, end-to-end encrypted via iCloud)

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: AgentTask                                              │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    title       String                                                │
 │    priority    Int64  (0=low, 1=medium, 2=high, 3=critical)         │
 │    isCompleted Int64  (0/1 boolean)                                  │
 │    createdAt   Date                                                  │
 │    updatedAt   Date                                                  │
 │    projectRef  CKRecord.Reference → Project                         │
 │    deadlineRef CKRecord.Reference → Deadline (optional)             │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: Project                                                │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    name        String                                                │
 │    status      String  (Active/Paused/Completed/Archived)            │
 │    colorHex    String                                                │
 │    createdAt   Date                                                  │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: Deadline                                               │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    dueDate     Date                                                  │
 │    isCompleted Int64                                                 │
 │    taskRef     CKRecord.Reference → AgentTask                       │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: Meeting                                                │
 │  Fields:                                                             │
 │    id                    CKRecord.ID                                 │
 │    title                 String                                      │
 │    startDate             Date                                        │
 │    endDate               Date                                        │
 │    location              String (optional)                           │
 │    eventKitIdentifier    String (optional)                           │
 │    participantRefs       [CKRecord.Reference] → Person               │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: Person (METADATA ONLY)                                 │
 │  Fields:                                                             │
 │    id                  CKRecord.ID                                   │
 │    name                String                                        │
 │    contactIdentifier   String (CNContact stable ID)                  │
 │    Note: email and phone NOT synced via CloudKit                     │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: AgentNote (title + tags only)                          │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    title       String                                                │
 │    source      String  (Local/Obsidian/Notion)                       │
 │    externalID  String (optional)                                     │
 │    tags        [String]                                              │
 │    updatedAt   Date                                                  │
 │    Note: content NOT synced – privacy boundary                       │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: AgentEmail (subject + metadata ONLY)                   │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    messageID   String (RFC 2822 Message-ID)                          │
 │    subject     String                                                │
 │    isRead      Int64                                                 │
 │    isReplied   Int64                                                 │
 │    receivedAt  Date                                                  │
 │    Note: bodyPreview and full body NEVER synced                      │
 └─────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────────┐
 │  Record Type: AgentFile (references only)                            │
 │  Fields:                                                             │
 │    id          CKRecord.ID                                           │
 │    name        String                                                │
 │    extension   String                                                │
 │    tags        [String]                                              │
 │    lastModified Date                                                 │
 │    Note: bookmarkData and file content NEVER synced                  │
 └─────────────────────────────────────────────────────────────────────┘

 Indexes (for query performance):
   AgentTask:   queryableIndex on isCompleted, priority, updatedAt
   Meeting:     queryableIndex on startDate
   AgentEmail:  queryableIndex on isReplied, receivedAt
   Deadline:    queryableIndex on dueDate, isCompleted

 Subscription:
   CKQuerySubscription on AgentTask for isCompleted=0 changes
   → triggers local notification on other devices when task state changes

 Data Protection:
   CKContainer.default().privateCloudDatabase
   Encrypted at rest via iCloud end-to-end encryption
   Data Protection class: .completeUntilFirstUnlock (set on SwiftData store)
*/

import Foundation
import CloudKit

/// Utility for checking CloudKit availability before sync
enum CloudKitAvailability {
    static func check() async -> Bool {
        do {
            let status = try await CKContainer(identifier: "iCloud.com.agentos.app")
                .accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
}
