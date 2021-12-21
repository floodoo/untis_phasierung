import 'timetable.hour.dart';
import 'utils.dart' as utils;

class TimeTableDay {
  DateTime date;
  var hours = <TimeTableHour>[];
  String dayName = "";

  int daysSinceEpoch = 0;
  int dayIndex = 0;
  bool outOfScope = false;

  TimeTableDay(this.date) {
    switch (date.weekday) {
      case 1:
        dayName = "Montag";
        break;
      case 2:
        dayName = "Dienstag";
        break;
      case 3:
        dayName = "Mittwoch";
        break;
      case 4:
        dayName = "Donnerstag";
        break;
      case 5:
        dayName = "Freitag";
        break;
      case 6:
        dayName = "Samstag";
        break;
      case 7:
        dayName = "Sonntag";
        break;
      default:
        "";
    }

    daysSinceEpoch = utils.daysSinceEpoch(date.millisecondsSinceEpoch);
  }

  void addHour(dynamic data) {
    hours.add(new TimeTableHour(data));

    hours.sort((a, b) => a.end.hour.compareTo(b.end.hour));
  }
}
