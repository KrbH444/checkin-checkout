import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mock_company/login.dart';
import 'package:mock_company/testcard.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mock_company/database.dart';

class CheckInOut extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const CheckInOut(this.apiData, {super.key});

  @override
  CheckInOutState createState() => CheckInOutState();
}

class CheckInOutState extends State<CheckInOut> {
  final dbHelper = DatabaseHelper.instance;
  bool isLocationLoading = false;
  double pageWidth = 0;
  double pageHeight = 0;
  bool isLoggedIn = true; // Initially assume the user is logged in
  late Timer _timer;
  static const int _logoutTimeout = 10; // 5 minutes in seconds
  bool checkedIn = false; // Whether user has checked in
  bool checkedOut = false; // Whether user has checked out
  String checkInTime = 'Not yet checked in';
  String checkOutTime = 'Not yet checked out';
  bool isHovered = false;
  bool showWidget = false;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.initialize();
    _startTimer();
    _readData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pageHeight = MediaQuery.of(context).size.height;
    pageWidth = MediaQuery.of(context).size.width;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session Ended, Please Log In.'),
          duration: Duration(seconds: 4),
        ),
      );
    });
  }

  void _checkIn() async {
    final database = await dbHelper.database;
    setState(() {
      isLocationLoading = true;
    });

    final currentTime = DateTime.now();
    final isNear = await isNearLocation(24.686081, 46.689455);

    setState(() {
      isLocationLoading = false;
    });

    if (isNear) {
      if (currentTime.hour >= 8 && currentTime.hour < 16) {
        setState(() {
          checkedIn = true;
          checkInTime = DateFormat('hh:mm a').format(currentTime);
        });

        final data = {
          'employeeID': widget.apiData['data']['id'],
          'checkDate': DateFormat('yyyy-MM-dd').format(currentTime),
          'checkType': 'Check In',
          'checkTime': checkInTime,
        };

        await database.insert('CheckInOut', data);
      } else {
        // Display a message to the user that check-in is not allowed at the current time.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not correct time for check-in'),
            duration: Duration(seconds: 4), // Adjust duration as needed
          ),
        );
      }
    } else {
      // Display a message to the user that they are not near the allowed location for check-in.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not near the allowed location for check-in.'),
          duration: Duration(seconds: 4), // Adjust duration as needed
        ),
      );
    }
  }

  void _checkOut() async {
    final database = await dbHelper.database;
    setState(() {
      isLocationLoading = true;
    });

    final currentTime = DateTime.now();
    final isNear = await isNearLocation(24.686081, 46.689455);

    setState(() {
      isLocationLoading = false;
    });

    if (isNear) {
      // Combine current date with checkInTime for accurate comparison
      DateTime checkInDateTime;
      try {
        final currentDate = DateFormat('yyyy-MM-dd').format(currentTime);
        checkInDateTime =
            DateFormat('yyyy-MM-dd hh:mm a').parse('$currentDate $checkInTime');
      } catch (e) {
        // If parsing fails, set to a time far in the past to avoid blocking checkout
        checkInDateTime = DateTime(2000);
      }

      if (currentTime.isAfter(checkInDateTime) && currentTime.hour < 20) {
        setState(() {
          checkedOut = true;
          checkOutTime = DateFormat('hh:mm a').format(currentTime);
        });

        final data = {
          'employeeID': widget.apiData['data']['id'],
          'checkDate': DateFormat('yyyy-MM-dd').format(currentTime),
          'checkType': 'Check Out',
          'checkTime': checkOutTime,
        };

        await database.insert('CheckInOut', data);
      } else {
        // Display a message to the user that check-out is not allowed at the current time.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not correct time for check-out'),
            duration: Duration(seconds: 4), // Adjust duration as needed
          ),
        );
      }
    } else {
      // Display a message to the user that they are not near the allowed location for check-out.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not near the allowed location for check-out.'),
          duration: Duration(seconds: 4), // Adjust duration as needed
        ),
      );
    }
  }

  Future<bool> isNearLocation(
      double targetLatitude, double targetLongitude) async {
    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLatitude,
      targetLongitude,
    );

    return distance <= 500;
  }

  void _undoCheckOut() async {
    final dbHelper = DatabaseHelper.instance;
    setState(() {
      checkedOut = false;
      checkOutTime = 'Not yet checked out';
    });

    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final database = await dbHelper.database;
      await database.rawDelete('''
      DELETE FROM CheckInOut
      WHERE checkDate = ? AND checkType = ?
    ''', [currentDate, 'Check Out']);
    } catch (e) {
      print('Error undoing check-out: $e');
    }
  }

  void _readData() async {
    final dbHelper = DatabaseHelper.instance;
    String foundCheckInTime = 'Not yet checked in';
    String foundCheckOutTime = 'Not yet checked out';

    final currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final database = await dbHelper.database;
      final results = await database.rawQuery('''
      SELECT * FROM CheckInOut
      WHERE employeeID = ? AND checkDate = ?
    ''', [widget.apiData['data']['id'], currentDate]);

      for (final result in results) {
        final checkType =
            result['checkType'] as String?; // Use 'as' to cast nullable value
        final checkTime =
            result['checkTime'] as String?; // Use 'as' to cast nullable value

        if (checkType != null && checkTime != null) {
          // Check for null
          if (checkType == 'Check In') {
            foundCheckInTime = checkTime;
          } else if (checkType == 'Check Out') {
            foundCheckOutTime = checkTime;
          }
        }
      }
    } catch (e) {
      print('Error reading data: $e');
    }

    setState(() {
      checkedIn = foundCheckInTime != 'Not yet checked in';
      checkedOut = foundCheckOutTime != 'Not yet checked out';
      checkInTime = foundCheckInTime; // Use null-aware operator
      checkOutTime = foundCheckOutTime; // Use null-aware operator
    });
  }

  void _resetTimer() {
    _timer.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Container(
        width: 100, // Adjust the width as needed
        height: 100, // Adjust the height as needed
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(
              (0.8 * 255).toInt()), // Add a semi-transparent background color
          borderRadius: BorderRadius.circular(20), // Add rounded corners
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.teal), // Set the color of the progress indicator
            ),
            SizedBox(
                height:
                    10), // Add some spacing between the progress indicator and text
            Text(
              "Loading...",
              style: TextStyle(
                color: Colors.indigo,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLocationLoading) {
      showWidget = true;
    } else {
      // After 3 seconds, hide the widget
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          showWidget = false;
        });
      });
    }

    return Listener(
      onPointerDown: (_) {
        // User interaction detected, reset the timer
        _resetTimer();
      },
      child: Scaffold(
        backgroundColor: Colors.indigo[50],
        appBar: AppBar(
          toolbarHeight: (pageHeight + pageWidth) * 0.15,
          backgroundColor: Colors.indigo[800],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(150)),
          ),
          elevation: 0,
          title: Title(
            color: Colors.white,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          isHovered = true;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          isHovered = false;
                        });
                      },
                      child: Tooltip(
                        message: 'Go Back', // Tooltip text
                        child: IconButton(
                          icon: Icon(
                              isHovered
                                  ? Icons.arrow_circle_left
                                  : Icons.arrow_circle_left_outlined,
                              color: Colors.white),
                          iconSize: (pageHeight + pageWidth) *
                              0.05, // Adjust the size as needed
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TestCard(
                                  widget.apiData,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    CircleAvatar(
                      backgroundImage:
                          NetworkImage('${widget.apiData['data']['avatar']}'),
                      radius: (pageHeight + pageWidth) * 0.045,
                    ),
                    Tooltip(
                      message: 'Logout', // Tooltip text
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLoggedIn = false;
                          });
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const MyLogin(), // Pass the data to testcard
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigoAccent,
                          shadowColor: Colors.indigoAccent[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          elevation:
                              400, // Adjust the elevation to match your shadow
                        ),
                        child: SizedBox(
                          height: pageHeight * 0.1,
                          width: pageWidth * 0.1,
                          child: Icon(
                            size: (pageHeight + pageWidth) * 0.03,
                            Icons.logout_outlined,
                            color: Colors.indigo[800],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: pageHeight * 0.05),
                  child: Center(
                    child: Container(
                      height: pageHeight * 0.1,
                      width: pageWidth * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                            50.0), // Radius for the rounded corners
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('EEEE').add_jm().format(DateTime.now()),
                          style: TextStyle(
                              color: Colors.teal,
                              fontSize: (pageHeight + pageWidth) * 0.015,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                // Box for Check In and Check Out
                Container(
                  height: pageHeight * 0.2,
                  width: pageWidth * 0.8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                        50.0), // Radius for the rounded corners
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Check In',
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontWeight: FontWeight.bold,
                                fontSize: (pageHeight + pageWidth) * 0.02,
                              )),
                          Center(
                            child: Text(
                              checkedIn ? checkInTime : 'Not yet checked in',
                              style: TextStyle(
                                color: checkInTime == 'Not yet checked in'
                                    ? Colors.red
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: (pageHeight + pageWidth) * 0.012,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Check Out',
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontWeight: FontWeight.bold,
                                fontSize: (pageHeight + pageWidth) * 0.02,
                              )),
                          Center(
                            child: Text(
                              checkedOut ? checkOutTime : 'Not yet checked out',
                              style: TextStyle(
                                color: checkOutTime == 'Not yet checked out'
                                    ? Colors.red
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: (pageHeight + pageWidth) * 0.012,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(vertical: pageHeight * 0.05),
                  child: Stack(
                    children: [
                      Visibility(
                        visible: !checkedIn,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLocationLoading) {
                              // If location is still loading, do nothing or display a message
                              // You don't need to explicitly call _buildLoadingWidget() here.
                            } else {
                              // If location loading is complete, trigger the _checkOut function
                              _checkIn();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0),
                            ),
                            elevation: 0,
                          ),
                          child: SizedBox(
                            width: pageWidth * 0.2,
                            height: pageHeight * 0.1,
                            child: const Center(
                              child: Text('Check In'),
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !checkedOut && checkedIn,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLocationLoading) {
                              // If location is still loading, do nothing or display a message
                              // You don't need to explicitly call _buildLoadingWidget() here.
                            } else {
                              // If location loading is complete, trigger the _checkOut function
                              _checkOut();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0),
                            ),
                            elevation: 0,
                          ),
                          child: SizedBox(
                            width: pageWidth * 0.2,
                            height: pageHeight * 0.1,
                            child: const Center(
                              child: Text('Check Out'),
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: checkedOut && checkedIn,
                        child: ElevatedButton(
                          onPressed: _undoCheckOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .red, // Use a different color for the undo button
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 0,
                          ),
                          child: SizedBox(
                            width: pageWidth * 0.1,
                            height: pageHeight * 0.06,
                            child: Center(
                              child: Text(
                                'Undo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: (pageHeight + pageWidth) * 0.01,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: checkedOut && checkedIn,
                  child: AnimatedOpacity(
                    opacity: showWidget ? 1.0 : 0.0,
                    duration: const Duration(
                        milliseconds:
                            500), // Set the duration here (500 milliseconds in this example)
                    child: Stack(
                      alignment: AlignmentDirectional.center,
                      children: [
                        Container(
                          height: (pageHeight + pageWidth) * 0.08,
                          width: (pageHeight + pageWidth) * 0.08,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              500.0,
                            ), // Radius for the rounded corners
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: Colors.teal,
                          size: (pageHeight + pageWidth) * 0.05,
                        ),
                      ],
                    ),
                  ),
                ),
                isLocationLoading ? _buildLoadingWidget() : const SizedBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
