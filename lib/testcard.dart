import 'package:flutter/material.dart';
import 'package:mock_company/database.dart';
import 'dart:async';
import 'package:mock_company/login.dart';
import 'package:mock_company/attend.dart';
import 'package:mock_company/ticket.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class TestCard extends StatefulWidget {
  @override
  TestCardState createState() => TestCardState();
  final Map<String, dynamic> apiData;

  const TestCard(this.apiData, {super.key});
}

class TestCardState extends State<TestCard>
    with SingleTickerProviderStateMixin {
  Map<String, String> attendanceStatus = {};
  List<Map<String, String>> entries = [];
  List<Ticket> assignedTickets = [];
  String fileContent = '';
  String dayName = '';
  String checkInTime = '';
  String checkOutTime = '';
  String date = '';
  double pageWidth = 0;
  double pageHeight = 0;
  late TabController _tabController;
  bool isLoggedIn = true; // Initially assume the user is logged in
  late Timer _timer;
  static const int _logoutTimeout = 10; // 5 minutes in seconds
  String todayDateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
  int presentCount = 0;
  int lateCount = 0;
  int absentCount = 0;
  String selectedMonthYear = DateFormat('yyyy-MM').format(DateTime.now());
  DateTime currentDate = DateTime.now();
  DateTime entryDate = DateTime.now();
  bool isHovered1 = false;
  bool isHovered2 = false;
  bool isHovered3 = false;
  bool isHovered4 = false;
  bool isDone = false;

  @override
  void initState() {
    super.initState();
    requestLocationPermission();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      // This function will be called when the user switches tabs
      setState(() {});
    });
    _startTimer();
    _readFileContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    pageWidth = MediaQuery.of(context).size.width;
    pageHeight = MediaQuery.of(context).size.height;
  }

  String getGreeting() {
    final currentTime = DateTime.now();
    final hour = currentTime.hour;

    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  void requestLocationPermission() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      // Permission granted, you can now use location services.
    } else if (status.isDenied) {
      // Permission denied, show a message to the user or open app settings.
    } else if (status.isPermanentlyDenied) {
      // Permission permanently denied, open app settings.
      openAppSettings();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: _logoutTimeout), (timer) {
      // Automatically log out the user when the timer triggers.
      setState(() {
        isLoggedIn = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MyLogin(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session Ended, Please Log In.'),
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  void _resetTimer() {
    _timer.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _readFileContent() async {
    try {
      final database = await DatabaseHelper.instance.database;

      final results = await database.query('CheckInOut',
          where: 'employeeID = ?',
          whereArgs: [widget.apiData['data']['id']],
          orderBy: 'checkDate DESC');

      if (results.isNotEmpty) {
        // Parse the data from the database results
        final content = results.map((row) {
          final date = row['checkDate'];
          final checkInTime = row['checkTime'] ?? '';
          final checkOutTime = row['checkTime'] ?? '';

          return '$date Check In $checkInTime Check Out $checkOutTime';
        }).join('\n');

        setState(() {
          fileContent = content;
          _parseDatabaseContent(currentDate);
          _fetchAssignedTickets();
        });
      }
    } catch (e) {
      print('Error reading database content: $e');
    }
  }

  void _parseDatabaseContent(DateTime selectedMonth) async {
    try {
      final database = await DatabaseHelper.instance.database;
      selectedMonthYear.split('-').map(int.parse).toList();

      final results = await database.rawQuery(
        '''
      SELECT checkDate, checkType, checkTime
      FROM CheckInOut
      WHERE employeeID = ?
      ORDER BY checkDate DESC
      ''',
        ['${widget.apiData['data']['id']}'],
      );

      Map<String, Map<String, String>> dailyEntries = {};

      for (final row in results) {
        final date = row['checkDate'] as String? ?? '';
        final checkType = row['checkType'];
        final checkTime = row['checkTime'] as String? ?? '';

        if (checkType == "Check In") {
          final entry = dailyEntries[date] ??
              {
                'date': date,
                'checkInTime': '',
                'checkOutTime': '',
                'userId': '${widget.apiData['data']['id']}',
              };
          entry['checkInTime'] = checkTime;
          dailyEntries[date] = entry;
        } else if (checkType == "Check Out") {
          final entry = dailyEntries[date] ??
              {
                'date': date,
                'checkInTime': '',
                'checkOutTime': '',
                'userId': '${widget.apiData['data']['id']}',
              };
          entry['checkOutTime'] = checkTime;
          dailyEntries[date] = entry;
        }
      }

      setState(() {
        entries = dailyEntries.values.toList();
      });
    } catch (e) {
      print('Error parsing database content: $e');
    }
  }

  Future<void> _fetchAssignedTickets() async {
    try {
      final database = await DatabaseHelper.instance.database;

      final results = await database.query('Ticket',
          where: 'referredToEmployeeID = ?',
          whereArgs: [widget.apiData['data']['id']],
          orderBy: 'createdDate DESC');

      if (results.isNotEmpty) {
        // Parse the data from the database results
        final tickets = results.map((row) {
          final ticketID = row['ticketID'] as int; // Cast to int
          final title = row['title'] as String; // Cast to String
          final category = row['category'] as String; // Cast to String
          final description =
              row['description'] as String? ?? ''; // Cast to String
          final createdDate = row['createdDate'] as String; // Cast to String
          final employeeID = row['employeeID'] as String; // Cast to String
          final employeeName = row['employeeName'] as String; // Cast to String
          final referredToEmployeeID =
              row['referredToEmployeeID'] as String; // Cast to String
          final isPrivate = row['isPrivate'] == 1; // Check if it's non-zero

          return Ticket(
            ticketID: ticketID,
            title: title,
            category: category,
            description: description,
            createdDate: createdDate,
            employeeID: employeeID,
            employeeName: employeeName,
            referredToEmployeeID: referredToEmployeeID,
            isPrivate: isPrivate,
          );
        }).toList();

        setState(() {
          assignedTickets = tickets;
        });
      }
    } catch (e) {
      print('Error fetching assigned tickets: $e');
    }
  }

  String _getDayName(String date) {
    final parsedDate = DateTime.parse(date);
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dayNames[parsedDate.weekday - 1];
  }

  Map<String, dynamic> calculateAttendanceForUser(
    List<Map<String, String>> entries,
    String userId,
  ) {
    selectedMonthYear.split('-').map(int.parse).toList();
    // Create a map to store attendance status for each date
    Map<String, String> attendanceStatus = {};

    // Create a map to store the latest check-in time for each date
    Map<String, String> latestCheckInTime = {};

    // Initialize counters
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;

    // Get the first day of the current month
    DateTime firstDayOfMonth = DateTime(currentDate.year, currentDate.month, 1);

    // Iterate through the dates from the first day of the month until the current date
    for (int i = 0; i <= currentDate.day - firstDayOfMonth.day; i++) {
      DateTime currentDateToCheck = firstDayOfMonth.add(Duration(days: i));
      String formattedDate =
          DateFormat('yyyy-MM-dd').format(currentDateToCheck);

      // Check if the entry belongs to the logged-in user
      bool userEntryExists = false;
      String? checkInTime;

      for (final entry in entries) {
        final date = entry['date'];
        final entryUserId = entry['userId'];

        if (date == formattedDate && entryUserId == userId) {
          userEntryExists = true;
          checkInTime = entry['checkInTime'];
          break;
        }
      }

      if (!userEntryExists || checkInTime == null || checkInTime.isEmpty) {
        // If there's no entry for the user or no check-in time, consider it absent
        attendanceStatus[formattedDate] = 'Absent';

        if ((currentDateToCheck.weekday >= DateTime.monday &&
                    currentDateToCheck.weekday <= DateTime.thursday ||
                currentDateToCheck.weekday ==
                    DateTime.sunday) && // Weekdays (Monday to Friday)
            currentDateToCheck.isBefore(DateTime.now())) {
          absentCount++;
        }
      } else {
        // Extract time components
        final timeParts = checkInTime.split(' ');
        if (timeParts.length == 2) {
          final time = timeParts[0];
          final period = timeParts[1];

          // Parse time components
          final timeComponents = time.split(':');
          int hour = int.parse(timeComponents[0]);
          final minute = int.parse(timeComponents[1]);

          // Convert to 24-hour format if necessary
          if (period == 'PM' && hour < 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }

          // Check if the check-in time is after 10 AM (10:00)
          if (hour >= 10 || (hour == 10 && minute >= 0)) {
            attendanceStatus[formattedDate] = 'Late'; // Late if after 10:00
            lateCount++;
          } else {
            attendanceStatus[formattedDate] = 'Present';
            presentCount++;
          }

          // Update the latest check-in time for the date
          final modifiedHour = (hour < 10) ? '0$hour' : '$hour';
          final modifiedTime = '$modifiedHour:${timeComponents[1]}';
          if (!latestCheckInTime.containsKey(formattedDate) ||
              (checkInTime.compareTo(latestCheckInTime[formattedDate] ?? '') >
                  0)) {
            latestCheckInTime[formattedDate] =
                modifiedTime; // Store the modified time
          }
        }
      }
    }

    int totalDaysAttended = presentCount + lateCount;

    int percentageDaysAttended = 0;
    if (totalDaysAttended + absentCount > 0) {
      percentageDaysAttended =
          (totalDaysAttended / (totalDaysAttended + absentCount) * 100).toInt();
    }

    // Return the results including the percentage
    return {
      'attendanceStatus': attendanceStatus,
      'presentCount': presentCount,
      'lateCount': lateCount,
      'absentCount': absentCount,
      'totalDaysAttended': totalDaysAttended,
      'percentageDaysAttended': percentageDaysAttended,
    };
  }

  void markTicketAsDone(Ticket ticket) {
    // Assuming you have a list of tickets and you want to update the status of the given ticket
    final int index = assignedTickets.indexOf(ticket);
    if (index != -1) {
      // Update the ticket's status as done
      assignedTickets[index].isDone = true;
    }
    // You may also want to update the UI or perform any other necessary actions.
  }

  void undoMarkTicketAsDone(Ticket ticket) {
    // Assuming you have a list of tickets and you want to update the status of the given ticket
    final int index = assignedTickets.indexOf(ticket);
    if (index != -1) {
      // Update the ticket's status as done
      assignedTickets[index].isDone = false;
    }
    // You may also want to update the UI or perform any other necessary actions.
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.apiData['data']['id'].toString();
    final attendanceData = calculateAttendanceForUser(entries, userId);
    final presentCount = attendanceData['presentCount'];
    final lateCount = attendanceData['lateCount'];
    final absentCount = attendanceData['absentCount'];
    final daysAttended = attendanceData['percentageDaysAttended'];
    final filteredEntries = entries.where((entry) {
      final DateTime entryDate = DateTime.parse(entry['date'] ?? '');
      return entryDate.month == currentDate.month;
    }).toList();
    final filteredAssignedTickets = assignedTickets.where((ticket) {
      final DateFormat dateFormat = DateFormat('yyyy-MM-dd hh:mm a');
      final DateTime entryDate = dateFormat.parse(ticket.createdDate);
      return entryDate.month == currentDate.month;
    }).toList();

    return Listener(
      onPointerDown: (_) {
        // User interaction detected, reset the timer
        _resetTimer();
      },
      child: Scaffold(
        resizeToAvoidBottomInset:
            true, // This is important to handle keyboard overlay
        backgroundColor: Colors.indigo[50],
        appBar: AppBar(
          toolbarHeight: (pageHeight + pageWidth) * 0.15,
          backgroundColor: Colors.indigo[800],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(150)),
          ),
          elevation: 0,
          flexibleSpace: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage('${widget.apiData['data']['avatar']}'),
                  radius: (pageHeight + pageWidth) * 0.04,
                ),
                Text(
                  "\t${getGreeting()},\n${widget.apiData['data']['first_name']}!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (pageHeight + pageWidth) * 0.022,
                  ),
                ),
              ],
            ),
          ),
        ),

        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                Stack(
                  children: [
                    Visibility(
                      visible: filteredEntries.isNotEmpty,
                      child: Center(
                        child: ListView.builder(
                          itemCount: filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = filteredEntries[index];
                            final DateTime entryDate =
                                DateTime.parse(entry['date'] ?? '');
                            final bool isAttendedThisMonth =
                                entryDate.month == currentDate.month;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == filteredEntries.length - 1
                                    ? pageHeight * 0.15
                                    : 0,
                                top: index ==
                                        filteredEntries.length -
                                            filteredEntries.length
                                    ? pageHeight * 0.05
                                    : 0,
                              ),
                              child: Card(
                                color: Colors.white,
                                shadowColor: Colors.indigo[100],
                                margin: EdgeInsetsDirectional.symmetric(
                                  horizontal: pageWidth * 0.08,
                                  vertical: pageHeight * 0.02,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                elevation: entry['date'] == todayDateString &&
                                        isAttendedThisMonth
                                    ? 10
                                    : 0,
                                child: Column(
                                  children: [
                                    SizedBox(height: pageHeight * 0.02),
                                    Text(
                                      _getDayName(entry['date'] ?? ''),
                                      style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.02,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Check In
                                        Column(
                                          children: [
                                            Text(
                                              'Check In',
                                              style: TextStyle(
                                                  fontSize:
                                                      (pageHeight + pageWidth) *
                                                          0.015,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.indigo),
                                            ),
                                            Text(
                                              entry['checkInTime'] ?? '',
                                              style: TextStyle(
                                                fontSize:
                                                    (pageHeight + pageWidth) *
                                                        0.012,
                                                color: entry['checkInTime'] !=
                                                            '' &&
                                                        entry['checkOutTime'] !=
                                                            ''
                                                    ? Colors.green[600]
                                                    : (entry['checkOutTime'] ==
                                                                '' &&
                                                            entry['date'] !=
                                                                todayDateString
                                                        ? Colors.orange[600]
                                                        : (entry['checkInTime'] !=
                                                                    '' &&
                                                                entry['date'] ==
                                                                    todayDateString
                                                            ? Colors.blue[600]
                                                            : Colors
                                                                .green[600])),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(width: pageWidth * 0.2),
                                        // Check Out
                                        Column(
                                          children: [
                                            Text(
                                              'Check Out',
                                              style: TextStyle(
                                                  fontSize:
                                                      (pageHeight + pageWidth) *
                                                          0.015,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.indigo),
                                            ),
                                            Text(
                                              entry['checkOutTime'] ?? '',
                                              style: TextStyle(
                                                fontSize:
                                                    (pageHeight + pageWidth) *
                                                        0.012,
                                                color: entry['checkInTime'] !=
                                                            '' &&
                                                        entry['checkOutTime'] !=
                                                            ''
                                                    ? Colors.green[600]
                                                    : (entry['checkOutTime'] ==
                                                                '' &&
                                                            entry['date'] !=
                                                                todayDateString
                                                        ? Colors.orange[600]
                                                        : Colors.green[600]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    // Date
                                    Text(
                                      entry['date']!,
                                      style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.018,
                                          color: Colors.black),
                                    ),
                                    SizedBox(height: pageHeight * 0.02),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: pageHeight * 0.02,
                  width: pageWidth * 0.03,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                            padding: EdgeInsetsDirectional.symmetric(
                                horizontal: 0, vertical: pageHeight * 0.02)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '\t\t\t${DateFormat('MMMM').format(currentDate)}\t',
                              style: TextStyle(
                                fontSize: (pageHeight + pageWidth) *
                                    0.025, // Adjust the font size as needed
                                color: Colors.teal,
                              ),
                            ),
                            Text(
                              '${currentDate.year}\n',
                              style: TextStyle(
                                fontSize: (pageHeight + pageWidth) *
                                    0.012, // Adjust the font size as needed
                                fontWeight: FontWeight
                                    .bold, // Adjust the font weight as needed
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsetsDirectional.symmetric(
                                horizontal: 0, vertical: pageHeight * 0.02)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MouseRegion(
                              onEnter: (_) {
                                setState(() {
                                  isHovered1 = true;
                                });
                              },
                              onExit: (_) {
                                setState(() {
                                  isHovered1 = false;
                                });
                              },
                              child: Tooltip(
                                message: 'Previous Month', // Tooltip text
                                child: SizedBox(
                                  height: (pageHeight + pageWidth) * 0.05,
                                  width: (pageHeight + pageWidth) * 0.09,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.indigo,
                                      elevation:
                                          0, // Adjust the elevation as needed
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        currentDate = currentDate.subtract(
                                            Duration(days: currentDate.day));
                                        if (currentDate.month ==
                                                DateTime.now().month &&
                                            currentDate.year ==
                                                DateTime.now().year) {
                                          currentDate = DateTime.now();
                                        }
                                        selectedMonthYear =
                                            DateFormat('yyyy-MM')
                                                .format(currentDate);
                                      });
                                    },
                                    child: Icon(
                                      isHovered1
                                          ? Icons.arrow_circle_left
                                          : Icons.arrow_circle_left_outlined,
                                      size: (pageHeight + pageWidth) * 0.05,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: pageWidth * 0.02),
                            MouseRegion(
                              onEnter: (_) {
                                setState(() {
                                  isHovered2 = true;
                                });
                              },
                              onExit: (_) {
                                setState(() {
                                  isHovered2 = false;
                                });
                              },
                              child: Tooltip(
                                message: 'Current Month', // Tooltip text
                                child: SizedBox(
                                  height: (pageHeight + pageWidth) * 0.05,
                                  width: (pageHeight + pageWidth) * 0.09,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.indigo,
                                      elevation:
                                          0, // Adjust the elevation as needed
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        // Calculate the current month
                                        currentDate = DateTime.now();
                                        selectedMonthYear =
                                            DateFormat('yyyy-MM')
                                                .format(currentDate);
                                      });
                                    },
                                    child: Icon(
                                      isHovered2
                                          ? Icons.arrow_drop_down_circle
                                          : Icons.arrow_circle_down_outlined,
                                      size: (pageHeight + pageWidth) * 0.05,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: pageWidth * 0.02),
                            MouseRegion(
                              onEnter: (_) {
                                setState(() {
                                  isHovered3 = true;
                                });
                              },
                              onExit: (_) {
                                setState(() {
                                  isHovered3 = false;
                                });
                              },
                              child: Tooltip(
                                message: 'Next Month', // Tooltip text
                                child: SizedBox(
                                  height: (pageHeight + pageWidth) * 0.05,
                                  width: (pageHeight + pageWidth) * 0.09,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.indigo,
                                      elevation:
                                          0, // Adjust the elevation as needed
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        // Calculate the next month
                                        int nextMonth = currentDate.month + 1;
                                        int nextYear = currentDate.year;

                                        if (nextMonth == 13) {
                                          nextMonth = 1;
                                          nextYear++;
                                        }

                                        // Calculate the last day of the next month
                                        int lastDayOfMonth =
                                            DateTime(nextYear, nextMonth + 1, 0)
                                                .day;

                                        // Ensure currentDate is within a valid range
                                        if (lastDayOfMonth < currentDate.day) {
                                          // If the last day of the next month is earlier than the current day,
                                          // set currentDate to the last day of the next month
                                          currentDate = DateTime(nextYear,
                                              nextMonth, lastDayOfMonth);
                                        } else {
                                          // Otherwise, set currentDate to the first day of the next month
                                          currentDate =
                                              DateTime(nextYear, nextMonth, 1);
                                        }

                                        selectedMonthYear =
                                            DateFormat('yyyy-MM')
                                                .format(currentDate);
                                      });
                                    },
                                    child: Icon(
                                      isHovered3
                                          ? Icons.arrow_circle_right
                                          : Icons.arrow_circle_right_outlined,
                                      size: (pageHeight + pageWidth) * 0.05,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                            padding: EdgeInsetsDirectional.symmetric(
                                horizontal: 0, vertical: pageHeight * 0.02)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: (pageHeight + pageWidth) * 0.08,
                              width: (pageHeight + pageWidth) * 0.07,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15.0),
                                color: Colors
                                    .white, // You can set the background color for days attended here
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                        height:
                                            10), // Add some spacing between the icon and the count
                                    Container(
                                      height: (pageHeight + pageWidth) * 0.05,
                                      width: (pageHeight + pageWidth) * 0.05,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(500.0),
                                        color: Colors.blue[
                                            50], // You can set the background color for days attended here
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$daysAttended%', // Display the days attended count here
                                          style: TextStyle(
                                              color: Colors.blue,
                                              fontSize:
                                                  (pageHeight + pageWidth) *
                                                      0.02,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Attendance',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.01,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: pageWidth * 0.01),
                            Container(
                              height: (pageHeight + pageWidth) * 0.08,
                              width: (pageHeight + pageWidth) * 0.07,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15.0),
                                color: Colors
                                    .white, // You can set the background color for present days here
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                        height:
                                            10), // Add some spacing between the icon and the count
                                    Container(
                                      height: (pageHeight + pageWidth) * 0.05,
                                      width: (pageHeight + pageWidth) * 0.05,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(500.0),
                                        color: Colors.green[
                                            50], // You can set the background color for days attended here
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$presentCount', // Display the days attended count here
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontSize:
                                                  (pageHeight + pageWidth) *
                                                      0.03,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Present',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.01,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: pageWidth * 0.01),
                            Container(
                              height: (pageHeight + pageWidth) * 0.08,
                              width: (pageHeight + pageWidth) * 0.07,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15.0),
                                color: Colors
                                    .white, // You can set the background color for late days here
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                        height:
                                            10), // Add some spacing between the icon and the count
                                    Container(
                                      height: (pageHeight + pageWidth) * 0.05,
                                      width: (pageHeight + pageWidth) * 0.05,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(500.0),
                                        color: Colors.orange[
                                            50], // You can set the background color for days attended here
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$lateCount', // Display the days attended count here
                                          style: TextStyle(
                                              color: Colors.orange,
                                              fontSize:
                                                  (pageHeight + pageWidth) *
                                                      0.03,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Late',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.01,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: pageWidth * 0.01),
                            Container(
                              height: (pageHeight + pageWidth) * 0.08,
                              width: (pageHeight + pageWidth) * 0.07,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15.0),
                                color: Colors
                                    .white, // You can set the background color for absent days here
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                      height:
                                          10), // Add some spacing between the icon and the count
                                  Container(
                                    height: (pageHeight + pageWidth) * 0.05,
                                    width: (pageHeight + pageWidth) * 0.05,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(500.0),
                                      color: Colors.red[
                                          50], // You can set the background color for days attended here
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$absentCount', // Display the days attended count here
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize:
                                                (pageHeight + pageWidth) * 0.03,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Absent',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize:
                                            (pageHeight + pageWidth) * 0.01,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: pageHeight * 0.01),
                        Visibility(
                          visible: filteredAssignedTickets.isNotEmpty,
                          child: Column(
                            children: filteredAssignedTickets.map((ticket) {
                              return Card(
                                elevation: 0,
                                color:
                                    ticket.isDone ? Colors.green : Colors.white,
                                shadowColor: Colors.indigo[100],
                                margin: EdgeInsets.symmetric(
                                  horizontal: pageWidth * 0.08,
                                  vertical: pageHeight * 0.02,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${ticket.ticketID}) ${ticket.title}',
                                        style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.02,
                                          fontWeight: FontWeight.bold,
                                          color: ticket.isDone
                                              ? Colors.white
                                              : Colors.teal,
                                        ),
                                      ),
                                      SizedBox(height: pageHeight * 0.01),
                                      Text(
                                        'Category: ${ticket.category}',
                                        style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.015,
                                          color: ticket.isDone
                                              ? Colors.white
                                              : Colors.indigo,
                                        ),
                                      ),
                                      Text(
                                        'Description: ${ticket.description}',
                                        style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.015,
                                          color: ticket.isDone
                                              ? Colors.white
                                              : Colors.indigo,
                                        ),
                                      ),
                                      SizedBox(height: pageHeight * 0.01),
                                      Text(
                                        'Created Date: ${ticket.createdDate}',
                                        style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.015,
                                          color: ticket.isDone
                                              ? Colors.white
                                              : Colors.indigo,
                                        ),
                                      ),
                                      Text(
                                        'From: ${ticket.employeeID}-${ticket.employeeName}',
                                        style: TextStyle(
                                          fontSize:
                                              (pageHeight + pageWidth) * 0.015,
                                          color: ticket.isDone
                                              ? Colors.white
                                              : Colors.indigo,
                                        ),
                                      ),
                                      SizedBox(height: pageHeight * 0.02),
                                      Visibility(
                                        visible: !ticket.isDone,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo,
                                            foregroundColor: Colors.white,
                                            elevation:
                                                0, // Adjust the elevation as needed
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                          ),
                                          onPressed: () {
                                            markTicketAsDone(ticket);
                                            setState(() {});
                                          },
                                          child: const Text('Mark as Done'),
                                        ),
                                      ),
                                      Visibility(
                                        visible: ticket
                                            .isDone, // Show the button if the ticket is not marked as done
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            elevation:
                                                0, // Adjust the elevation as needed
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                          ),
                                          onPressed: () {
                                            undoMarkTicketAsDone(ticket);
                                            setState(() {});
                                          },
                                          child: const Text('Undo'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                            padding: EdgeInsetsDirectional.only(
                                bottom: pageHeight * 0.15)),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                              horizontal: 0, vertical: pageHeight * 0.03)),
                      Column(
                        children: [
                          Container(
                            width: pageWidth * 0.8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  50.0), // Radius for the rounded corners
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: pageHeight * 0.1),
                                Text(
                                  "ID: ",
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                                Text(
                                  "${widget.apiData['data']['id']}",
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: pageHeight * 0.05),
                          Container(
                            width: pageWidth * 0.8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  50.0), // Radius for the rounded corners
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: pageHeight * 0.1),
                                Text(
                                  "Full Name: ",
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                                Text(
                                  "${widget.apiData['data']['first_name']} ${widget.apiData['data']['last_name']}",
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: pageHeight * 0.05),
                          Container(
                            width: pageWidth * 0.8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  50.0), // Radius for the rounded corners
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(height: pageHeight * 0.1),
                                Text(
                                  "Email: ",
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                                Text(
                                  "${widget.apiData['data']['email']}",
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (pageHeight + pageWidth) * 0.014,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                          padding: EdgeInsetsDirectional.only(
                              bottom: pageHeight * 0.15)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 200.0),
            Positioned(
              bottom: pageHeight * 0.01, // Adjust the vertical position
              left: 0,
              right: 0,
              child: BottomAppBar(
                elevation: 100,
                color: Colors.transparent,
                height: pageHeight * 0.1,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Row(
                      children: [
                        const SizedBox(width: 15),
                        ElevatedButton(
                          onPressed: () {
                            _tabController.animateTo(0);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigoAccent,
                            shadowColor: Colors.indigoAccent[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: _tabController.index == 0 ? 20 : 0,
                          ),
                          child: SizedBox(
                            height: 65,
                            child: Icon(
                              size: 50,
                              _tabController.index == 0
                                  ? Icons.fact_check
                                  : Icons.fact_check_outlined,
                              color: _tabController.index == 0
                                  ? Colors.indigo[800]
                                  : Colors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          onPressed: () {
                            _tabController.animateTo(1);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigoAccent,
                            shadowColor: Colors.indigoAccent[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(500.0),
                            ),
                            elevation: _tabController.index == 1
                                ? 20
                                : 0, // Adjust the elevation to match your shadow
                          ),
                          child: SizedBox(
                            width: 70,
                            height: 90,
                            child: Icon(
                              size: 50,
                              _tabController.index == 1
                                  ? Icons.home
                                  : Icons.home_outlined,
                              color: _tabController.index == 1
                                  ? Colors.indigo[800]
                                  : Colors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        ElevatedButton(
                          onPressed: () {
                            _tabController.animateTo(2);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.indigoAccent,
                            shadowColor: Colors.indigoAccent[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: _tabController.index == 2
                                ? 20
                                : 0, // Adjust the elevation to match your shadow
                          ),
                          child: SizedBox(
                            height: 65,
                            child: Icon(
                              size: 50,
                              _tabController.index == 2
                                  ? Icons.person
                                  : Icons.person_outlined,
                              color: _tabController.index == 2
                                  ? Colors.indigo[800]
                                  : Colors.teal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
        drawer: Drawer(
          width: (pageHeight + pageWidth) * 0.25,
          backgroundColor: Colors.indigo[800],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topRight: Radius.circular(30.0),
                bottomRight: Radius.circular(30.0)),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(vertical: pageHeight * 0.02),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigoAccent,
                          shadowColor: Colors.indigoAccent[100],
                          elevation: 0, // Adjust the elevation as needed
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.indigo[800],
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: (pageHeight + pageWidth) *
                          0.05, // Adjust the radius as needed
                      backgroundImage: const AssetImage('Assets/Mock.png'),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white,
                height: (pageHeight + pageWidth) * 0.01,
              ),
              ListTile(
                title: Text(
                  "Today is..",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (pageHeight + pageWidth) * 0.03,
                  ),
                ),
                subtitle: Text(
                  DateFormat('d MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: (pageHeight + pageWidth) * 0.02,
                  ),
                ),
              ),
              SizedBox(height: pageHeight * 0.05),
              ElevatedButton(
                onPressed: () {
                  _tabController.animateTo(1);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigoAccent,
                  shadowColor: Colors.indigoAccent[100],
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20.0),
                        topLeft: Radius.circular(20.0)),
                  ),
                  elevation: 0,
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.home_outlined,
                    color: Colors.indigo[800],
                    size: (pageHeight + pageWidth) * 0.02,
                  ),
                  title: Text(
                    "Home",
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: (pageHeight + pageWidth) * 0.02,
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckInOut(widget.apiData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigoAccent,
                  shadowColor: Colors.indigoAccent[100],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        0.0), // Radius for the rounded corners
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.indigo[800],
                    size: (pageHeight + pageWidth) * 0.02,
                  ),
                  title: Text(
                    "Check-in & out",
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: (pageHeight + pageWidth) * 0.02,
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployeeTicket(widget.apiData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigoAccent,
                  shadowColor: Colors.indigoAccent[100],
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.only(bottomRight: Radius.circular(20.0)),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.sticky_note_2_outlined,
                    color: Colors.indigo[800],
                    size: (pageHeight + pageWidth) * 0.02,
                  ),
                  title: Text(
                    "Create Tickets",
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: (pageHeight + pageWidth) * 0.02,
                    ),
                  ),
                ),
              ),
              SizedBox(height: pageHeight * 0.1),
              Divider(
                color: Colors.indigo[400],
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoggedIn = false;
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyLogin(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[800],
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(
                            20)), // Adjust the border radius as needed
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.logout_outlined,
                    color: Colors.white,
                    size: (pageHeight + pageWidth) * 0.02,
                  ),
                  title: Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (pageHeight + pageWidth) * 0.02,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
