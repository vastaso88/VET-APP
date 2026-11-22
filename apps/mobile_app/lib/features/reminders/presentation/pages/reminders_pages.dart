/// The reminder pages. Kept as the one import the routes and the other features
/// use; the pages themselves live in their own files (QK-22).
library;

export 'reminder_create_edit_pages.dart' show ReminderCreatePage, ReminderEditPage;
export 'reminder_detail_page.dart' show ReminderDetailPage;
export 'reminders_list_page.dart' show RemindersListPage;
export '../widgets/reminder_page_parts.dart' show saveReminderInBackground, showReminderFailure;
