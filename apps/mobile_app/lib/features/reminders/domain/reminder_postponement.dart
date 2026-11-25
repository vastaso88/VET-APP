import '../../notifications/domain/notification_plan.dart';

/// "Rimanda": the ready-made moments offered by "Quando vuoi che te lo
/// ricordi?". A day and time of the owner's own is picked apart (see
/// reminder_postpone_sheet.dart).
enum PostponeChoice { oneHour, evening, tomorrowMorning }

/// "Stasera".
const kPostponeEveningHour = 19;

/// How far ahead a day can be picked.
const kPostponeMaxDays = 365;

/// [at] without its seconds: notifications are scheduled to the minute, and the
/// question in the app must come back at that same minute.
DateTime toMinute(DateTime at) => DateTime(at.year, at.month, at.day, at.hour, at.minute);

/// When [choice] falls, seen from [now] (the phone's wall clock). Only
/// [PostponeChoice.evening] can be gone already: see [postponeChoices].
DateTime postponeMoment(PostponeChoice choice, DateTime now) => switch (choice) {
      PostponeChoice.oneHour => toMinute(now.add(const Duration(hours: 1))),
      PostponeChoice.evening => DateTime(now.year, now.month, now.day, kPostponeEveningHour),
      PostponeChoice.tomorrowMorning =>
        DateTime(now.year, now.month, now.day + 1, kDefaultNotificationHour),
    };

/// The choices still ahead of [now], in the order they are shown.
List<({PostponeChoice choice, DateTime at})> postponeChoices(DateTime now) => [
      for (final choice in PostponeChoice.values)
        if (postponeMoment(choice, now).isAfter(now))
          (choice: choice, at: postponeMoment(choice, now)),
    ];
