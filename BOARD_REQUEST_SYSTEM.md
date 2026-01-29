# Board Request System

## Overview
The board request system has been refactored to support two distinct types of board membership requests:

1. **Invitations** - Board managers invite users to join their board
2. **Join Requests** - Users request to join public boards

## Board Visibility

Boards now support public/private settings:
- `boardIsPublic` (boolean) - Whether the board is visible to all users
- `boardRequiresApproval` (boolean) - Whether join requests require manager approval

### Board Types:
- **Private Board** (`boardIsPublic: false`) - Only visible to members, users can only join via invitation
- **Public Board** (`boardIsPublic: true`) - Visible to all users, users can request to join

## Request Types

### 1. Invitation (`requestType: 'invitation'`)
**Who initiates:** Board manager  
**Target:** Specific user  
**Use case:** Manager wants to recruit a user to their board

**Flow:**
1. Manager searches for a user
2. Manager sends invitation
3. User receives invitation notification
4. User can accept or decline

**Implementation:**
```dart
await boardJoinRequestProvider.createInvitation(
  boardId: boardId,
  boardTitle: boardTitle,
  userId: targetUserId,
  message: 'Optional invitation message',
);
```

### 2. Join Request (`requestType: 'join_request'`)
**Who initiates:** Any user  
**Target:** Public board  
**Use case:** User wants to join a public board

**Flow:**
1. User discovers a public board
2. User requests to join
3. Board manager receives join request notification
4. Manager can approve or reject

**Implementation:**
```dart
await boardJoinRequestProvider.createJoinRequest(
  boardId: boardId,
  boardTitle: boardTitle,
  message: 'Optional request message',
);
```

## BoardJoinRequest Model

### Fields
```dart
class BoardJoinRequest {
  final String boardJoinRequestId;
  final String boardId;
  final String boardTitle;
  final String boardManagerId;
  final String boardManagerName;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String requestStatus;      // 'pending', 'approved', 'rejected'
  final String requestType;        // 'invitation' or 'join_request'
  final String? requestMessage;
  final DateTime requestCreatedAt;
  final DateTime? requestRespondedAt;
  final String? requestRespondedBy;
  final String? requestResponseMessage;
}
```

### Request Status
- `pending` - Awaiting response
- `approved` - Accepted/approved
- `rejected` - Declined/rejected

## Service Methods

### BoardJoinRequestService

#### Creating Requests
```dart
// Manager invites user
Future<void> createInvitation({
  required String boardId,
  required String boardTitle,
  required String userId,
  String? message,
})

// User requests to join public board
Future<void> createJoinRequest({
  required String boardId,
  required String boardTitle,
  String? message,
})
```

#### Streaming Requests

**For Board Managers:**
```dart
// All pending requests (both types)
Stream<List<BoardJoinRequest>> streamPendingRequestsForBoard(String boardId)

// Only invitations sent by manager
Stream<List<BoardJoinRequest>> streamPendingInvitationsForBoard(String boardId)

// Only join requests from users
Stream<List<BoardJoinRequest>> streamPendingJoinRequestsForBoard(String boardId)
```

**For Users:**
```dart
// All requests by user (both types)
Stream<List<BoardJoinRequest>> streamRequestsByUser(String userId)

// Only invitations received
Stream<List<BoardJoinRequest>> streamInvitationsByUser(String userId)

// Only join requests made
Stream<List<BoardJoinRequest>> streamJoinRequestsByUser(String userId)
```

#### Responding to Requests
```dart
// Approve any type of request
Future<void> approveRequest(
  BoardJoinRequest request,
  {String? responseMessage}
)

// Reject any type of request
Future<void> rejectRequest(
  BoardJoinRequest request,
  {String? responseMessage}
)

// User/manager cancels pending request
Future<void> cancelRequest(String requestId)
```

## Provider Methods

### BoardJoinRequestProvider

```dart
// Creating requests
Future<void> createInvitation({...})
Future<void> createJoinRequest({...})

// Streaming for managers
void streamPendingRequestsForBoard(String boardId)
void streamPendingInvitationsForBoard(String boardId)
void streamPendingJoinRequestsForBoard(String boardId)

// Streaming for users
void streamRequestsByUser(String userId)
void streamInvitationsByUser(String userId)
void streamJoinRequestsByUser(String userId)

// Managing requests
Future<void> approveRequest(BoardJoinRequest request, {String? responseMessage})
Future<void> rejectRequest(BoardJoinRequest request, {String? responseMessage})
Future<void> cancelRequest(String requestId)
Future<bool> hasPendingRequest(String boardId, String userId)
```

## UI Implementation Examples

### For Board Managers

#### Viewing Join Requests
```dart
// In board details page, show join requests tab
Consumer<BoardJoinRequestProvider>(
  builder: (context, provider, _) {
    final joinRequests = provider.joinRequests;
    return ListView.builder(
      itemCount: joinRequests.length,
      itemBuilder: (context, index) {
        final request = joinRequests[index];
        return ListTile(
          title: Text(request.userName),
          subtitle: Text(request.requestMessage ?? 'Wants to join'),
          trailing: Row(
            children: [
              IconButton(
                icon: Icon(Icons.check),
                onPressed: () => provider.approveRequest(request),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => provider.rejectRequest(request),
              ),
            ],
          ),
        );
      },
    );
  },
)
```

### For Users

#### Requesting to Join Public Board
```dart
// In public board details page
ElevatedButton(
  onPressed: () async {
    await context.read<BoardJoinRequestProvider>().createJoinRequest(
      boardId: board.boardId,
      boardTitle: board.boardTitle,
      message: 'I would like to join this board',
    );
  },
  child: Text('Request to Join'),
)
```

#### Viewing Invitations
```dart
// In user's invitations page
Consumer<BoardJoinRequestProvider>(
  builder: (context, provider, _) {
    final invitations = provider.invitations;
    return ListView.builder(
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invitation = invitations[index];
        return ListTile(
          title: Text(invitation.boardTitle),
          subtitle: Text('Invited by ${invitation.boardManagerName}'),
          trailing: Row(
            children: [
              TextButton(
                onPressed: () => provider.approveRequest(invitation),
                child: Text('Accept'),
              ),
              TextButton(
                onPressed: () => provider.rejectRequest(invitation),
                child: Text('Decline'),
              ),
            ],
          ),
        );
      },
    );
  },
)
```

## Database Structure

### Collection: `board_join_requests`

```json
{
  "boardJoinRequestId": "unique_id",
  "boardId": "board_id",
  "boardTitle": "Board Name",
  "boardManagerId": "manager_user_id",
  "boardManagerName": "Manager Name",
  "userId": "user_id",
  "userName": "User Name",
  "userProfilePicture": "url",
  "requestStatus": "pending|approved|rejected",
  "requestType": "invitation|join_request",
  "requestMessage": "Optional message",
  "requestCreatedAt": "timestamp",
  "requestRespondedAt": "timestamp",
  "requestRespondedBy": "responder_user_id",
  "requestResponseMessage": "Optional response"
}
```

### Indexes Needed
- `boardId` + `requestStatus` + `requestCreatedAt`
- `boardId` + `requestStatus` + `requestType` + `requestCreatedAt`
- `userId` + `requestCreatedAt`
- `userId` + `requestType` + `requestCreatedAt`

## Migration Notes

### Backward Compatibility
- Existing requests without `requestType` will default to `'invitation'`
- Old code using `createJoinRequest` with `userId` parameter should be updated to use `createInvitation`
- A deprecated method `createJoinRequestLegacy` is provided for gradual migration

### Required Updates
1. Update UI to show separate sections for invitations vs join requests
2. Add "Request to Join" button for public boards
3. Update board search/discovery to show public boards
4. Add board visibility toggle in board creation/edit forms
5. Update firestore indexes as listed above
