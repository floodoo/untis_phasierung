import 'rpcresponse.dart';
import 'timetable.day.dart';
import 'utils.dart' as utils;

/**Diese Klasse wandelt die Antwort in ein TimeTable Objekt um*/
class TimeTableRange {
  RPCResponse response;
  DateTime _startDate;
  DateTime _endDate;

  /**Alle vollen Tage die vom Start bis zum Enddatum angefragt wurden.<br>
   * Wenn Tage außerhalb des scopes liegen (Wochenende oder Ferien) werden diese auch der Liste hinzugefügt, 
   * besitzen jedoch keine Stunden*/
  var days = <TimeTableDay>[];

  TimeTableRange(this._startDate, this._endDate, this.response) {
    this.response = response;

    if (response.payload.runtimeType != List)
      throw Exception("Falsches Datenformat");

    //Konstruiere die Tage
    main:
    for (dynamic entry in response.payload) {
      DateTime current = utils.convertToDateTime(entry['date'].toString());
      //Checke ob der Tag schon erstellt wurde
      for (TimeTableDay day in days) {
        if (day.date.day == current.day) {
          //Wenn ja, füge die Stunde in den Tag
          day.addHour(entry);
          continue main;
        }
      }
      //Ansonsten erstelle einen neuen Tag mit der Stunde!
      TimeTableDay day = new TimeTableDay(current);
      day.addHour(entry);
      days.add(day);
    }

    var finalList = <TimeTableDay>[];
    int day1 = utils.daysSinceEpoch(
        new DateTime(_startDate.year, _startDate.month, _startDate.day)
            .millisecondsSinceEpoch);

    int diff = _endDate.difference(_startDate).inDays;
    if (diff < 0)
      throw Exception("Das Start Datum muss größer als das Enddatum sein!");

    main:
    for (int i = 0; i < diff; i++) {
      for (TimeTableDay d in days) {
        if (d.daysSinceEpoch - day1 == i) {
          finalList.add(d);
          days.remove(d);
          continue main;
        }
      }
      //Nicht gefunden.
      TimeTableDay outOfScope =
          new TimeTableDay(_startDate.add(Duration(days: i)));
      outOfScope.outOfScope = true;
      finalList.add(outOfScope);
    }

    days.clear();
    days.addAll(finalList);
  }
}
