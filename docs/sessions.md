Of course. Here is a step-by-step markdown guide for an AI developer to implement the complete Firestore structure and application flow for the recurring group sessions feature.

## 🚀 Guide to Implementing Recurring Group Sessions
This guide outlines the Firestore database structure and the application logic required to build the feature. The system is designed to be scalable, efficient, and robust.

### 1. Final Firestore Structure

Implement the following collections and subcollections. This structure separates templates from live, joinable instances and uses subcollections for participant lists to ensure scalability.

#### 🌲 Structure Tree

/users/{userId}
/groups/{groupId}
/sessionTemplates/{templateId}
/liveSessions/{sessionId}
  ├ /players/{userId}
  └ /waitingList/{userId}
#### Collection Details

/users

displayName: String

email: String

photoURL: String

groups: Array<String> (List of groupIds)

/groups

groupName: String

adminId: String (userId of creator)

members: Array<String> (List of userIds)

memberCount: Number

/sessionTemplates (Master copies created by admins)

groupId: String

creatorId: String

title: String

joinDate: Timestamp (Date users can start joining)

cutOffDate: Timestamp (Date joining closes)

eventDate: Timestamp (Start date & time of the first session)

eventEndDate: Timestamp (End date & time of the first session)

durationInMinutes: Number (Calculated: eventEndDate - eventDate)

maxPlayers: Number

maxWaitingList: Number

totalCost: Number

costPerPlayer: Number (Calculated: totalCost / maxPlayers)

isRecurring: Boolean

rrule: String (e.g., FREQ=WEEKLY;BYDAY=SU)

/liveSessions (Joinable instances created by the backend)

templateId: String (Reference to the parent template)

groupId: String

title: String

eventDate: Timestamp (Start date & time for this specific instance)

eventEndDate: Timestamp (End date & time for this specific instance)

cutOffDate: Timestamp

status: String ("OPEN", "FULL", "CLOSED")

playerCount: Number

waitingListCount: Number

... (Other relevant fields like maxPlayers, costPerPlayer are copied from the template)

/liveSessions/{sessionId}/players/{userId} (Subcollection)

joinTime: Timestamp

paymentStatus: String ("UNPAID", "PAID")

/liveSessions/{sessionId}/waitingList/{userId} (Subcollection)

addedTime: Timestamp

### 2. Step-by-Step Implementation Flows

Follow this logic for the three core processes.

#### Flow 1: Creating a Session Template (Flutter App)

UI: Present a form in the app for a group admin to input all the fields required for the sessionTemplates collection.

Calculate Fields: Before writing to Firestore, the app must calculate the derived fields:

durationInMinutes: Compute the difference between eventEndDate and eventDate.

costPerPlayer: Compute totalCost / maxPlayers.

Write to Firestore: Create a new document in the /sessionTemplates collection with the complete data.

#### Flow 2: Automated Creation of Live Sessions (Backend)

This logic must be deployed as a Firebase Cloud Function triggered by Cloud Scheduler.

Schedule: Configure a Cloud Scheduler job to run once daily (e.g., at 01:00 Lima time).

Query: The Cloud Function will query the /sessionTemplates collection for all documents that are active.

Iterate and Calculate: For each template, the function will:
a. Parse the rrule string and the eventDate.
b. Use a library (like rrule.js for Node.js) to determine if an occurrence is scheduled for the current day.

Check for Duplicates: If an occurrence is found for today, generate a predictable unique ID for it (e.g., ${templateId}_${YYYY-MM-DD}). Check if a document with this ID already exists in the /liveSessions collection to prevent creating it twice.

Create Live Session: If no duplicate exists:
a. Read the durationInMinutes from the template.
b. Calculate the eventDate (start time) and eventEndDate for today's instance.
c. Create a new document in /liveSessions with the generated ID. Copy all relevant data from the template and set the correct dates for this specific instance. Initialize playerCount and waitingListCount to 0 and status to "OPEN".

#### Flow 3: A User Joining a Session (Flutter App)

This process must use a Firestore Transaction to prevent race conditions (e.g., two users joining the last spot at the same time).

UI: The app displays a list of liveSessions for a group. A user taps a "Join" button.

Initiate Transaction: The app will call FirebaseFirestore.instance.runTransaction().

Inside the Transaction:
a. Read Data: Read the liveSession document and check its status, playerCount, and maxPlayers. Also, check if a document for the current userId already exists in the players or waitingList subcollections to prevent double-joining.
b. Check Player Slots: If playerCount < maxPlayers, there is room.
i. Create Player Doc: Create a new document in the /liveSessions/{sessionId}/players/{userId} subcollection.
ii. Update Count: Update the playerCount on the main /liveSessions/{sessionId} document, incrementing it by 1.
c. Check Waiting List Slots: If the session is full, check waitingListCount against maxWaitingList.
i. Create Waiting List Doc: If there is space, create a document in the /liveSessions/{sessionId}/waitingList/{userId} subcollection.
ii. Update Count: Update the waitingListCount, incrementing it by 1.
d. Handle Full Session: If both lists are full, the transaction should fail, and the app should show a "Session and waiting list are full" message.

### 3. Firestore Security Rules (High-Level Logic)

Implement security rules to protect your data.

JavaScript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read their own document.
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }

    // Groups can be read by anyone, but only written to by members.
    match /groups/{groupId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
    }

    // Session templates can only be read or created by group members.
    match /sessionTemplates/{templateId} {
      allow read, create: if request.auth.uid in get(/databases/$(database)/documents/groups/$(request.resource.data.groupId)).data.members;
      // Only the creator can update/delete.
      allow update, delete: if request.auth.uid == resource.data.creatorId;
    }

    // Live sessions can be read by group members.
    match /liveSessions/{sessionId} {
      allow read: if request.auth.uid in get(/databases/$(database)/documents/groups/$(resource.data.groupId)).data.members;
      // Writes are handled by transactions, but updates to counts should be protected.
      allow update: if request.resource.data.playerCount == resource.data.playerCount + 1; // Simplified example
    }

    // Users can only add themselves to the players/waiting list.
    match /liveSessions/{sessionId}/players/{userId} {
      allow create: if request.auth.uid == userId;
    }
    match /liveSessions/{sessionId}/waitingList/{userId} {
      allow create: if request.auth.uid == userId;
    }
  }
}