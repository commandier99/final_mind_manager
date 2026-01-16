# How to Test Notifications in Mind Manager

## Overview
The notification system has been fully implemented with the following features:
- Push notification toggle in settings
- Permission request handling
- Test notification functionality
- In-app notification storage and display

## Testing Notifications

### 1. Access Settings
1. Open the app
2. Tap the menu icon (≡) in the top-left
3. Select **Settings** from the side menu

### 2. Enable Push Notifications
1. In Settings, find the "Notifications" section
2. Toggle **Push Notifications** to ON
3. When prompted, tap **Allow** to grant notification permissions
   - On Android: A system dialog will appear
   - On iOS: A system permission dialog will appear
   - If denied, you'll need to enable it in device settings

### 3. Send a Test Notification
1. Once push notifications are enabled, you'll see a new option:
   - **Test Notification** - Send a test notification
2. Tap on "Test Notification"
3. You'll see a confirmation message
4. Go to the Notifications page (bell icon) to see the test notification

### 4. Check Your Notifications
1. Tap the bell icon (🔔) in the top-right of the app
2. You should see your test notification:
   - Title: "Test Notification"
   - Message: "This is a test notification from Mind Manager!"
   - Type: General
3. Tap on the notification to mark it as read
4. Swipe left to delete it

## Testing Programmatically

You can create notifications programmatically from anywhere in the app:

```dart
import 'package:provider/provider.dart';

// In your widget
final userId = context.read<UserProvider>().userId;
await context.read<NotificationProvider>().createNotification(
  userId: userId!,
  title: 'Your Title',
  message: 'Your message here',
  type: 'general', // or 'due_today', 'overdue', 'assigned', 'task_request'
  taskId: 'optional_task_id',
  boardTitle: 'Optional Board Name',
);
```

## Notification Types

The system supports these notification types:
- **general** - Gray icon, general notifications
- **due_today** - Orange icon, tasks due today
- **overdue** - Red icon, overdue tasks
- **assigned** - Blue icon, task assignments
- **task_request** - Blue icon, task requests

Each type has its own color coding and icon in the notifications list.

## Settings Options

### Push Notifications
- Enables/disables in-app notifications
- Requires device permission
- Shows/hides test notification option

### Email Notifications (Coming Soon)
- Placeholder for email notification preferences
- Currently only stores the preference

## Troubleshooting

### Permission Denied
If you denied notification permission:
1. Go to Settings
2. Try to enable Push Notifications again
3. A dialog will prompt you to open device settings
4. Tap "Open Settings" and enable notifications manually

### Notifications Not Showing
1. Check if Push Notifications is enabled in Settings
2. Verify device has notification permission
3. Try creating a test notification
4. Check the Notifications page (bell icon)

### Clear All Notifications
1. Go to Notifications page
2. Tap the three-dot menu (⋮) in the top-right
3. Select "Clear all"
4. Confirm the action

## Features

- ✅ Toggle push notifications on/off
- ✅ Permission request handling
- ✅ Test notification creation
- ✅ In-app notification display
- ✅ Mark as read/unread
- ✅ Swipe to delete
- ✅ Mark all as read
- ✅ Clear all notifications
- ✅ Unread count badge
- ✅ Time ago display
- ✅ Color-coded by type
- ✅ Pull to refresh

## Next Steps

To integrate notifications with your existing features:

1. **Task Assignment**: Call `NotificationProvider.createNotification()` when a task is assigned
2. **Deadline Reminders**: Create a background service to check for upcoming deadlines
3. **Board Invites**: Notify users when invited to boards
4. **Task Completion**: Notify task owners when tasks are completed
5. **Comments/Updates**: Notify when there are updates to tasks/boards

## API Reference

### NotificationProvider Methods

- `loadNotifications(String userId)` - Load all notifications for a user
- `createNotification(...)` - Create and save a new notification
- `markAsRead(String notifId, String userId)` - Mark a notification as read
- `markAllAsRead(String userId)` - Mark all notifications as read
- `deleteNotification(String notifId, String userId)` - Delete a notification
- `clearUserNotifications(String userId)` - Clear all user notifications
- `refreshUnreadCount(String userId)` - Refresh unread count

### Getters

- `notifications` - List of all notifications
- `unreadCount` - Number of unread notifications
- `isLoading` - Loading state
- `unreadNotifications` - List of unread notifications only
- `readNotifications` - List of read notifications only
