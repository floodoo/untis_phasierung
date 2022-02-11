import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:sol_connect/core/api/models/utils.dart';
import 'package:sol_connect/core/api/usersession.dart';
import 'package:sol_connect/core/excel/models/phasestatus.dart';
import 'package:sol_connect/core/excel/solc_api_manager.dart';
import 'package:sol_connect/core/excel/solcresponse.dart';
import 'package:sol_connect/core/exceptions.dart';
import 'package:sol_connect/core/service/services.dart';
import 'package:sol_connect/ui/screens/settings/widgets/custom_settings_card.dart';
import 'package:sol_connect/ui/shared/created_by.text.dart';
import 'package:sol_connect/util/logger.util.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  static final routeName = (SettingsScreen).toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Logger log = getLogger();

    final TextEditingController serverAdressTextController = TextEditingController();
    FocusNode textFieldFocus = FocusNode();

    final theme = ref.watch(themeService).theme;

    final phaseLoaded = ref.watch(timeTableService).isPhaseVerified;
    final validator = ref.watch(timeTableService).validator;
    final showDeveloperOptions = ref.watch(settingsService).showDeveloperOptions;

    bool lightMode;
    bool working = false;

    SnackBar _createSnackbar(String message, Color backgroundColor, {Duration duration = const Duration(seconds: 4)}) {
      return SnackBar(
        duration: duration,
        elevation: 20,
        backgroundColor: backgroundColor,
        content: Text(message, style: TextStyle(fontSize: 17, color: theme.colors.text)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(15.0), topRight: Radius.circular(15.0)),
        ),
      );
    }

    // The saved appearance is loaded on App start. This is only for the switch.
    if (theme.mode == ThemeMode.light) {
      lightMode = true;
    } else {
      lightMode = false;
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Einstellungen', style: TextStyle(color: theme.colors.text)),
          backgroundColor: theme.colors.primary,
          leading: BackButton(color: theme.colors.icon),
        ),
        body: Container(
          color: theme.colors.background,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Visibility(
                      visible: ref.read(timeTableService).session.personType != PersonTypes.teacher,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 25.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Phasierung",
                                style: TextStyle(fontSize: 25),
                              ),
                              IconButton(
                                onPressed: () {
                                  AwesomeDialog(
                                    context: context,
                                    dialogType: DialogType.NO_HEADER,
                                    animType: AnimType.BOTTOMSLIDE,
                                    headerAnimationLoop: false,
                                    // title: "Was ist das?",
                                    body: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Column(
                                        children: const [
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 15),
                                            child: Text(
                                              "Die Phasierung",
                                              style: TextStyle(fontSize: 23),
                                            ),
                                          ),
                                          Text(
                                            "Die Phasierung ist eine einfache Excel Datei die deinem Stundenplan gleicht und zusätzlich die SOL Phasen des aktuellen Blocks enthält.",
                                            textAlign: TextAlign.left,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 15, top: 5),
                                            child: Text(
                                              "Welche Excel Datei?",
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                          Text(
                                            "Diese wird üblicherweise am anfang deines Schulblocks vorgestellt und von deinem Lehrer zur Verfügung gestellt."
                                            "\nDiesen Plan kannst du dann als Excel Datei hier laden und in deinen Stundenplan einfügen.",
                                            textAlign: TextAlign.left,
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 15, top: 5),
                                            child: Text(
                                              "Ist die immer gültig?",
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                          Text(
                                            "Wenn du eine Phasierung laden willst, wird sie immer für den nächsten aktuellen Block geladen. "
                                            "Der gültigkeits Zeitraum wird auch grün angezeigt."
                                            "\nDu wirst benachrichtigt, wenn du noch die Phasierung eines alten Blocks geladen hast.",
                                            textAlign: TextAlign.left,
                                          ),
                                        ],
                                      ),
                                    ),
                                    btnOkOnPress: () {},
                                  ).show();
                                },
                                icon: Icon(
                                  Icons.info_outline,
                                  color: theme.colors.textInverted,
                                ),
                                iconSize: 25,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Visibility(
                        visible: ref.read(timeTableService).session.personType != PersonTypes.teacher &&
                            !ref.read(timeTableService).isPhaseVerified,
                        child: CustomSettingsCard(
                          padBottom: 5,
                          leading: Icon(
                            Icons.file_download,
                            color: theme.colors.text,
                            size: 26,
                          ),
                          text: "Phasierung herunterladen",
                          onTap: () async {
                            if (working) {
                              return;
                            }

                            working = true;
                            final SOLCApiManager manager = ref.read(timeTableService).apiManager!;
                            final int schoolClassId = ref.read(timeTableService).session.schoolClassId;
                            ScaffoldMessenger.of(context).clearSnackBars();

                            //Schritt 1: Überprüfe ob die herunterzuladene Datei noch aktuell ist / existiert#
                            ScaffoldMessenger.of(context).showSnackBar(
                              _createSnackbar(
                                  "Überprüfe, ob eine Phasierung verfügbar ist ...", theme.colors.elementBackground,
                                  duration: const Duration(seconds: 10)),
                            );
                            log.d("Checking file status on server ...");
                            try {
                              PhaseStatus? status = await manager.getSchoolClassInfo(schoolClassId: schoolClassId);
                              if (!Utils.dateInbetweenDays(from: status!.blockStart, to: status.blockEnd)) {
                                log.e("Phasierung nicht mehr aktuell!");
                                working = false;
                                return;
                              }
                            } on SOLCServerError catch (e) {
                              log.e("Server Error: $e");
                              if (e.response.responseCode == SOLCResponse.CODE_FILE_MISSING ||
                                  e.response.responseCode == SOLCResponse.CODE_ENTRY_MISSING) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  _createSnackbar(
                                      "Keine Phasierung für deine Klasse gefunden.\nBitte frage einen deiner Lehrer ob er die Phasierung für deine Klasse bereitstellen kann.",
                                      theme.colors.elementBackground,
                                      duration: const Duration(seconds: 10)),
                                );
                              }
                              working = false;
                              return;
                            } on FailedToEstablishSOLCServerConnection {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Bitte überprüfe deine Internetverbindung", theme.colors.errorBackground),
                              );
                              working = false;
                              return;
                            } catch (e) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Ein unbekannter Fehler ist aufgetreten: $e", theme.colors.errorBackground,
                                    duration: const Duration(seconds: 10)),
                              );
                              working = false;
                              return;
                            }

                            //Schritt 2: Downloade die Phasierung
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _createSnackbar("Phasierung herunterladen ...", theme.colors.elementBackground),
                            );
                            log.d("Downloading sheet for class " + schoolClassId.toString() + " ...");
                            List<int> bytes;
                            try {
                              bytes = await manager.downloadVirtualSheet(schoolClassId: schoolClassId);
                            } catch (e) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Ein unerwarteter Serverfehler ist aufgetreten: ($e)", theme.colors.errorBackground,
                                    duration: const Duration(seconds: 8)),
                              );
                              working = false;
                              return;
                            }

                            //Schritt 3: Lade Phasierung
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _createSnackbar("Phasierung laden ...", theme.colors.elementBackground,
                                  duration: const Duration(seconds: 15)),
                            );
                            log.d("Versuche Phasierung zu laden ...");
                            // TODO(debug): Debug timetable inactive
                            //ref
                            //   .read(timeTableService)
                            //    .session
                            //    .setTimetableBehaviour(0, PersonTypes.student, debug: true);
                            try {
                              await ref.read(timeTableService).loadCheckedVirtualPhaseFileForNextBlock(bytes: bytes);

                              ScaffoldMessenger.maybeOf(context)!.clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar("Fertig!", theme.colors.successColor),
                              );
                            } on NextBlockStartNotInRangeException {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Phasierung konnte nicht geladen werden: Dein nächster Schulblock ist noch so lange hin, er kann noch nicht festgestellt werden. Bitte gedulde dich ein wenig.",
                                    theme.colors.errorBackground,
                                    duration: const Duration(seconds: 10)),
                              );
                            } on FailedToEstablishSOLCServerConnection {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Bitte überprüfe deine Internetverbindung", theme.colors.errorBackground),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                    "Fehler beim laden der Phasierung: $e. Bitte Frage deinen Lehrer nach einer gültigen Phasierung.",
                                    theme.colors.errorBackground,
                                    duration: const Duration(seconds: 10)),
                              );
                            }

                            Future.delayed(const Duration(seconds: 4)).then((value) {
                              working = false;
                            });
                          },
                        )),
                    Visibility(
                      visible: ref.read(timeTableService).session.personType != PersonTypes.teacher,
                      child: CustomSettingsCard(
                        padTop: 5,
                        padBottom: 0,
                        leading: Icon(
                          phaseLoaded ? Icons.delete_rounded : Icons.folder_open_sharp,
                          color: theme.colors.text,
                          size: 26,
                        ),
                        text: phaseLoaded ? "Phasierung entfernen" : "Eigene Phasierung laden",
                        onTap: () async {
                          if (working) {
                            return;
                          }

                          if (phaseLoaded) {
                            ref.read(timeTableService).deletePhase();

                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _createSnackbar("Phasierung entfernt", theme.colors.elementBackground),
                            );
                            working = false;
                            return;
                          }

                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ["xlsx"],
                              allowMultiple: false,
                              dialogTitle: "Phasierung laden");

                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              _createSnackbar(
                                "Datei Überprüfen ...",
                                theme.colors.elementBackground,
                                duration: const Duration(minutes: 1),
                              ),
                            );

                            String errorMessage = "";

                            try {
                              await ref.read(timeTableService).loadCheckedVirtualPhaseFileForNextBlock(
                                  bytes: File(result.files.first.path!).readAsBytesSync(), persistent: true);
                            } on ExcelMergeFileNotVerified {
                              errorMessage = "Kein passender Block- Stundenplan in Datei gefunden!";
                            } on ExcelConversionAlreadyActive {
                              errorMessage = "Unbekannter Fehler. Bitte starte die App neu!";
                            } on SOLCServerError {
                              errorMessage = "Ein SOLC-API Server Fehler ist aufgetreten";
                            } on FailedToEstablishSOLCServerConnection {
                              errorMessage = "Bitte überprüfe deine Internetverbindung";
                            } on ExcelMergeNonSchoolBlockException {
                              // Doesn't matter
                            } on SocketException {
                              errorMessage = "Bitte überprüfe deine Internetverbindung";
                            } catch (e) {
                              log.e(e.toString());
                              errorMessage = "Unbekannter Fehler: " + e.toString();
                            }

                            ScaffoldMessengerState? state = ScaffoldMessenger.maybeOf(context);
                            if (state != null) {
                              ScaffoldMessenger.maybeOf(context)!.clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                _createSnackbar(
                                  errorMessage == "" ? "Phasierung für aktuellen Block geladen!" : errorMessage,
                                  errorMessage == "" ? theme.colors.successColor : theme.colors.errorBackground,
                                ),
                              );
                            }

                            Future.delayed(const Duration(seconds: 4)).then((value) {
                              working = false;
                            });
                          }
                        },
                      ),
                    ),
                    phaseLoaded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(30, 6, 30, 0),
                            child: Container(
                              color: theme.colors.successColor,
                              child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 5, 10),
                                  child: Text(
                                      validator != null
                                          ? "Phasierung geladen für Block " +
                                              Utils.convertToDDMM(validator.getBlockStart()) +
                                              " bis " +
                                              Utils.convertToDDMM(validator.getBlockEnd())
                                          : "Phasierung geladen für Block ? - ?",
                                      style: const TextStyle(fontSize: 13))),
                            ))
                        : const Padding(padding: EdgeInsets.fromLTRB(0, 0, 0, 0)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 25.0),
                        child: Text(
                          "Erscheinungsbild",
                          style: TextStyle(fontSize: 25, color: theme.colors.textInverted),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25.0, 25.0, 25.0, 0.0),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        color: theme.colors.primary,
                        child: SwitchListTile(
                          value: lightMode,
                          onChanged: (bool value) {
                            ref.read(themeService).saveAppearence(value);
                          },
                          title: Text(
                            (theme.mode == ThemeMode.light) ? "Light Mode" : "Dark Mode",
                            maxLines: 1,
                            style: TextStyle(color: theme.colors.text),
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          inactiveThumbColor: theme.colors.text,
                          activeTrackColor: theme.colors.background,
                          activeColor: theme.colors.text,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 25.0),
                        child: Text(
                          "App Info",
                          style: TextStyle(fontSize: 25, color: theme.colors.textInverted),
                        ),
                      ),
                    ),
                    CustomSettingsCard(
                      leading: Icon(
                        FontAwesome.github_circled,
                        color: theme.colors.text,
                      ),
                      text: "Github Projekt",
                      onTap: () async {
                        String _url = "https://github.com/floodoo/untis_phasierung";
                        if (!await launch(_url)) {
                          throw "Could not launch $_url";
                        }
                      },
                    ),
                    CustomSettingsCard(
                      leading: Icon(
                        FontAwesome.bug,
                        color: theme.colors.text,
                      ),
                      padTop: 10,
                      text: "Fehler Melden",
                      onTap: () async {
                        String _url =
                            "https://github.com/floodoo/untis_phasierung/issues/new?assignees=&labels=bug&title=Untis%20Phasierung%20Fehlerbericht";
                        if (!await launch(_url)) {
                          throw "Could not launch $_url";
                        }
                      },
                    ),
                    CustomSettingsCard(
                      leading: Icon(
                        Icons.info,
                        color: theme.colors.text,
                      ),
                      padTop: 10,
                      padBottom: 15,
                      text: "Version Alpha 1.0.1",
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 25.0, bottom: (showDeveloperOptions) ? 5 : 30, right: 25.0),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () {
                                ref.read(settingsService).toggleDeveloperOptions();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(showDeveloperOptions ? Icons.arrow_drop_down : Icons.arrow_right_rounded,
                                      color: theme.colors.textInverted),
                                  Text("Entwickleroptionen", style: TextStyle(color: theme.colors.textInverted)),
                                ],
                              ),
                            ),
                          ),
                          showDeveloperOptions
                              ? Column(
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10, bottom: 10.0),
                                        child: Text(
                                          "SOLC-API Server",
                                          style: TextStyle(fontSize: 25, color: theme.colors.textInverted),
                                        ),
                                      ),
                                    ),
                                    Card(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      color: theme.colors.primary,
                                      child: ListTile(
                                        // Idk why but on emulator it doesn't work with PC keyboard
                                        title: TextField(
                                          focusNode: textFieldFocus,
                                          controller: serverAdressTextController,
                                          onEditingComplete: () {
                                            if (serverAdressTextController.text != "") {
                                              ref
                                                  .read(settingsService)
                                                  .saveServerAdress(serverAdressTextController.text);
                                              ref
                                                  .read(timeTableService)
                                                  .apiManager!
                                                  .setServerAddress(serverAdressTextController.text);
                                            }
                                            serverAdressTextController.clear();
                                            FocusManager.instance.primaryFocus?.unfocus();
                                            textFieldFocus.unfocus();
                                          },
                                          textAlignVertical: TextAlignVertical.center,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            hintText: ref.watch(settingsService).serverAddress,
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                ref.read(settingsService).saveServerAdress("flo-dev.me");
                                                FocusManager.instance.primaryFocus?.unfocus();
                                                textFieldFocus.unfocus();
                                              },
                                              icon: Icon(Icons.settings_backup_restore,
                                                  color: theme.colors.textBackground),
                                              tooltip: "Setzte Server URL zurück",
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: CreatedByText(),
              )
            ],
          ),
        ),
      ),
    );
  }
}
