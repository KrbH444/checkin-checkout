import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mock_company/login.dart';
import 'package:mock_company/testcard.dart';
import 'package:mock_company/database.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Ticket {
  final int ticketID;
  final String title;
  final String description;
  final String createdDate;
  final String employeeName;
  final String employeeID;
  final bool isPrivate;
  final String category;
  final String referredToEmployeeID;
  bool isDone;

  Ticket({
    required this.ticketID,
    required this.title,
    required this.description,
    required this.createdDate,
    required this.employeeName,
    required this.employeeID,
    required this.isPrivate,
    required this.category,
    required this.referredToEmployeeID,
    this.isDone = false,
  });
  // Constructor or factory method to create a Ticket from a map
  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      ticketID: map['ticketID'],
      employeeID: map['employeeID'],
      employeeName: map['employeeName'],
      title: map['title'],
      description: map['description'],
      isPrivate: map['isPrivate'] == 1, // Convert 1 to true, 0 to false
      createdDate: map['createdDate'],
      category: map['category'],
      referredToEmployeeID: map['referredToEmployeeID'],
    );
  }
}

class EmployeeTicket extends StatefulWidget {
  final Map<String, dynamic> apiData;

  const EmployeeTicket(this.apiData, {super.key});

  @override
  EmployeeTicketState createState() => EmployeeTicketState();
}

class EmployeeTicketState extends State<EmployeeTicket>
    with SingleTickerProviderStateMixin {
  final Map<String, String> employeeNamesMap = {};
  double pageWidth = 0;
  double pageHeight = 0;
  bool isLoggedIn = true;
  late Timer _timer;
  static const int _logoutTimeout = 10;
  final List<Ticket> tickets = [];
  bool isHovered = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pageHeight = MediaQuery.of(context).size.height;
    pageWidth = MediaQuery.of(context).size.width;
  }

  Future<List<Ticket>> _readData() async {
    final dbHelper = DatabaseHelper.instance;
    final database = await dbHelper.database;

    final employeeTickets = await database.query(
      'Ticket',
      columns: [
        'ticketID',
        'employeeID',
        'employeeName',
        'title',
        'description',
        'isPrivate',
        'createdDate',
        'category',
        'referredToEmployeeID'
      ],
      where: 'employeeID = ?',
      whereArgs: [widget.apiData['data']['id']],
      orderBy: 'createdDate DESC',
    );

    final referredTickets = await database.query(
      'Ticket',
      columns: [
        'ticketID',
        'employeeID',
        'employeeName',
        'title',
        'description',
        'isPrivate',
        'createdDate',
        'category',
        'referredToEmployeeID'
      ],
      where: 'referredToEmployeeID = ?',
      whereArgs: [widget.apiData['data']['id']],
      orderBy: 'createdDate DESC',
    );

    final otherTickets = await database.query(
      'Ticket',
      columns: [
        'ticketID',
        'employeeID',
        'employeeName',
        'title',
        'description',
        'isPrivate',
        'createdDate',
        'category',
        'referredToEmployeeID'
      ],
      where: 'employeeID <> ? AND referredToEmployeeID <> ?',
      whereArgs: [widget.apiData['data']['id'], widget.apiData['data']['id']],
      orderBy: 'createdDate DESC',
    );

// Combine the results
    final results = [...employeeTickets, ...referredTickets, ...otherTickets];

    // Convert the retrieved data into a list of Ticket objects
    List<Ticket> tickets = results.map((map) => Ticket.fromMap(map)).toList();

    return tickets;
  }

  Future<Map<String, dynamic>> fetchDataFromApi() async {
    const int totalPages =
        5; // Define the total number of pages you want to fetch
    final List<Map<String, dynamic>> allUsers = [];
    final Map<String, String> employeeNamesMap = {}; // Create the map here

    for (int page = 1; page <= totalPages; page++) {
      final url = Uri.parse(
          'https://reqres.in/api/users?page=$page'); // Replace with your API URL
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> users = List.from(data['data']);

        for (var user in allUsers) {
          final String id = user['id'].toString();
          final String name = "${user['first_name']} ${user['last_name']}";
          employeeNamesMap[id] = name;
        }

        allUsers.addAll(users);
      } else {
        throw Exception('Failed to load data from page $page of the API');
      }
    }

    return {
      'allUsers': allUsers,
      'employeeNamesMap': employeeNamesMap,
    };
  }

  Future<void> fetchDataAndPopulateMap() async {
    try {
      final data =
          await fetchDataFromApi(); // Replace with your data-fetching function
      final Map<String, String> namesMap =
          data['employeeNamesMap'] as Map<String, String>;

      setState(() {
        employeeNamesMap.clear();
        employeeNamesMap.addAll(namesMap);
      });
    } catch (error) {
      // Handle any errors that occur during data fetching or population
    }
  }

  Widget _buildAssignedToWidget(Ticket ticket) {
    final referredToEmployeeIDString = ticket.referredToEmployeeID.toString();
    final assignedToName = employeeNamesMap[referredToEmployeeIDString];
    final displayAssignedToName = assignedToName ?? 'Not Specified';

    return Text(
      ticket.referredToEmployeeID == widget.apiData['data']['id'].toString()
          ? (ticket.isDone ? 'Assigned to: You and Done' : 'Assigned to: You')
          : 'Assigned to: $displayAssignedToName',
      style: TextStyle(
          color: ticket.referredToEmployeeID ==
                  widget.apiData['data']['id'].toString()
              ? Colors.red[400]
              : Colors.teal,
          fontWeight: FontWeight.bold),
    );
  }

  void _editTicket(BuildContext context, Ticket ticket) async {
    String updatedTitle = ticket.title;
    String updatedDescription = ticket.description;
    bool isPrivate = ticket.isPrivate;
    String selectedCategory = ticket.category;
    String selectedEmp = ticket.referredToEmployeeID;

    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        final dynamic data = widget.apiData['data'];

        if (data is List<Map<String, dynamic>>) {
          // Rest of your code
        } else {
          // Handle the case where 'data' is not the expected type.
        }
        return AlertDialog(
          title: const Text('Edit Ticket'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) {
                    updatedTitle = value;
                  },
                  controller: TextEditingController(text: ticket.title),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (value) {
                    updatedDescription = value;
                  },
                  controller: TextEditingController(text: ticket.description),
                ),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return DropdownButton<String>(
                      value: selectedCategory,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'Task',
                          child: Text('Task'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'issue',
                          child: Text('issue'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Other..',
                          child: Text('Other..'),
                        ),
                      ],
                    );
                  },
                ),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return FutureBuilder<Map<String, dynamic>>(
                      future:
                          fetchDataFromApi(), // Replace with your data-fetching function
                      builder: (BuildContext context,
                          AsyncSnapshot<Map<String, dynamic>> snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator(); // Add a loading indicator while data is being fetched
                        } else if (snapshot.hasError || snapshot.data == null) {
                          return Text(
                              'Error: ${snapshot.error ?? "No data available"}');
                        } else {
                          final allUsers = snapshot.data!['allUsers']
                              as List<Map<String, dynamic>>;
                          final employeeNamesMap = snapshot
                              .data!['employeeNamesMap'] as Map<String, String>;

                          final filteredUsers = allUsers
                              .where((user) =>
                                  user['id'].toString() !=
                                  widget.apiData['data']['id'].toString())
                              .toList();

                          return DropdownButton<String>(
                            value: selectedEmp,
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedEmp = newValue!;
                              });
                            },
                            items: [
                              // Add the "Not Specified" option as the initial item
                              const DropdownMenuItem<String>(
                                value: 'Not Specified',
                                child: Text('Not Specified'),
                              ),
                              ...filteredUsers.map(
                                (user) {
                                  final String id = user['id'].toString();
                                  final String name = employeeNamesMap[id] ??
                                      'Unknown'; // Use the employeeNamesMap to get the name

                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(name),
                                  );
                                },
                              ),
                            ],
                          );
                        }
                      },
                    );
                  },
                ),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return CheckboxListTile(
                      title: const Text('Private Ticket'),
                      value: isPrivate,
                      onChanged: (bool? value) {
                        setState(() {
                          isPrivate = value!;
                        });
                      },
                      activeColor: Colors.indigo,
                    );
                  },
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.indigo,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result) {
      final updatedTicket = Ticket(
        ticketID: ticket.ticketID,
        employeeID: ticket.employeeID,
        employeeName: ticket.employeeName,
        title: updatedTitle,
        description: updatedDescription,
        isPrivate: isPrivate,
        createdDate: ticket.createdDate,
        category: selectedCategory, // Update the category field
        referredToEmployeeID: selectedEmp,
      );

      setState(() {
        // Update the ticket in the list
        final index = tickets.indexOf(ticket);
        if (index != -1) {
          tickets[index] = updatedTicket;
        }
      });
      await updateTicket(updatedTicket);
    }
  }

  Future<void> updateTicket(Ticket ticket) async {
    final dbHelper = DatabaseHelper.instance;
    final database = await dbHelper.database;

    await database.update(
      'Ticket', // Replace with your table name
      {
        'title': ticket.title,
        'description': ticket.description,
        'isPrivate': ticket.isPrivate ? 1 : 0, // Convert boolean to integer
        'category': ticket.category,
        'referredToEmployeeID': ticket.referredToEmployeeID,
      },
      where: 'ticketID = ? AND employeeID = ?',
      whereArgs: [ticket.ticketID, ticket.employeeID],
    );
  }

  Future<void> deleteTicket(Ticket ticket) async {
    final dbHelper = DatabaseHelper.instance;
    final database = await dbHelper.database;

    await database.delete(
      'Ticket', // Replace with your table name
      where: 'ticketID = ? AND employeeID = ?',
      whereArgs: [ticket.ticketID, ticket.employeeID],
    );
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _readData();
    fetchDataAndPopulateMap();
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
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        body: FutureBuilder<List<Ticket>>(
          future: _readData(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Container(
                  width: 100, // Adjust the width as needed
                  height: 100, // Adjust the height as needed
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.8 * 255)
                        .toInt()), // Add a semi-transparent background color
                    borderRadius:
                        BorderRadius.circular(20), // Add rounded corners
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors
                            .teal), // Set the color of the progress indicator
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
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text(
                      'No tickets available.')); // Display a message if there are no tickets.
            } else {
              final tickets = snapshot.data!;
              final currentUserID = '${widget.apiData['data']['id']}';

              return ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (ctx, index) {
                  final ticket = tickets[index];

                  // Check if the ticket is private and created by the current user
                  final isTicketVisible = !ticket.isPrivate ||
                      ticket.employeeID == currentUserID ||
                      ticket.referredToEmployeeID == currentUserID;

                  if (isTicketVisible) {
                    return Container(
                      height: ticket.description == ''
                          ? pageHeight * 0.2
                          : (pageHeight * 0.2) +
                              (ticket.description.length * 0.5),
                      padding: EdgeInsetsDirectional.symmetric(
                        vertical: pageHeight * 0.007,
                        horizontal: pageWidth * 0.02,
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        tileColor: ticket.employeeID == currentUserID
                            ? Colors.indigo[100]
                            : (ticket.referredToEmployeeID == currentUserID)
                                ? Colors.teal[100]
                                : Colors.white,
                        // Set the background color
                        title: Text(
                          '${ticket.ticketID}. ${ticket.title}',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category: ${ticket.category}',
                              style: const TextStyle(
                                color: Colors.indigo,
                              ),
                            ), // Display the category
                            Text(
                              'Description: ${ticket.description}',
                              style: const TextStyle(
                                color: Colors.indigo,
                              ),
                            ),
                            _buildAssignedToWidget(
                                ticket), // Call a function to build the "Assigned to" widget
                          ],
                        ),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ticket.employeeID == currentUserID)
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.teal),
                                onPressed: () {
                                  _editTicket(context, ticket);
                                },
                              ),
                            if (ticket.employeeID == currentUserID)
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  deleteTicket(ticket);
                                  setState(() {});
                                },
                              ),
                            Text(
                              '${ticket.createdDate}\n(${ticket.employeeID}) ${ticket.employeeName}',
                              style: const TextStyle(
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              );
            }
          },
        ),
        floatingActionButton: ElevatedButton(
          onPressed: () {
            _createTicket(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.indigo,
            shadowColor: Colors.indigo[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            elevation: 400, // Adjust the elevation to match your shadow
          ),
          child: SizedBox(
            height: pageHeight * 0.1,
            width: pageWidth * 0.1,
            child: Icon(
              size: (pageHeight + pageWidth) * 0.03,
              Icons.add_outlined,
              color: Colors.teal,
            ),
          ),
        ),
      ),
    );
  }

  void _createTicket(BuildContext context) async {
    String newTicketTitle = '';
    String newTicketDescription = '';
    bool isPrivate = false; // Default to public
    String selectedCategory = 'Task';
    String selectedEmp = 'Not Specified';

    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Ticket'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) {
                    newTicketTitle = value;
                  },
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  onChanged: (value) {
                    newTicketDescription = value;
                  },
                ),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Ticket Category: '),
                        StatefulBuilder(
                          builder:
                              (BuildContext context, StateSetter setState) {
                            return DropdownButton<String>(
                              value: selectedCategory,
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedCategory = newValue!;
                                });
                              },
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: 'Task',
                                  child: Text('Task'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Issue',
                                  child: Text('Issue'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Other..',
                                  child: Text('Other..'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Assign to: '),
                        StatefulBuilder(
                          builder:
                              (BuildContext context, StateSetter setState) {
                            return FutureBuilder<Map<String, dynamic>>(
                              future:
                                  fetchDataFromApi(), // Replace with your data-fetching function
                              builder: (BuildContext context,
                                  AsyncSnapshot<Map<String, dynamic>>
                                      snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator(); // Add a loading indicator while data is being fetched
                                } else if (snapshot.hasError ||
                                    snapshot.data == null) {
                                  return Text(
                                      'Error: ${snapshot.error ?? "No data available"}');
                                } else {
                                  final allUsers = snapshot.data!['allUsers']
                                      as List<Map<String, dynamic>>;
                                  final employeeNamesMap =
                                      snapshot.data!['employeeNamesMap']
                                          as Map<String, String>;

                                  final filteredUsers = allUsers
                                      .where((user) =>
                                          user['id'].toString() !=
                                          widget.apiData['data']['id']
                                              .toString())
                                      .toList();

                                  return DropdownButton<String>(
                                    value: selectedEmp,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedEmp = newValue!;
                                      });
                                    },
                                    items: [
                                      // Add the "Not Specified" option as the initial item
                                      const DropdownMenuItem<String>(
                                        value: 'Not Specified',
                                        child: Text('Not Specified'),
                                      ),
                                      ...filteredUsers.map(
                                        (user) {
                                          final String id =
                                              user['id'].toString();
                                          final String name = employeeNamesMap[
                                                  id] ??
                                              'Unknown'; // Use the employeeNamesMap to get the name

                                          return DropdownMenuItem<String>(
                                            value: id,
                                            child: Text(name),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return CheckboxListTile(
                      title: const Text('Private Ticket'),
                      value: isPrivate,
                      onChanged: (bool? value) {
                        setState(() {
                          isPrivate = value!;
                        });
                      },
                      activeColor: Colors.teal,
                    );
                  },
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.indigo,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                setState(() {});
              },
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result) {
      final dbHelper = DatabaseHelper.instance;
      final database = await dbHelper.database;

      final formattedDate =
          DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());

      final newTicket = {
        'employeeID': '${widget.apiData['data']['id']}',
        'employeeName':
            '${widget.apiData['data']['first_name']} ${widget.apiData['data']['last_name']}',
        'title': newTicketTitle,
        'description': newTicketDescription,
        'isPrivate': isPrivate ? 1 : 0,
        'createdDate': formattedDate,
        'category': selectedCategory,
        'referredToEmployeeID': selectedEmp,
      };

      await database.insert('Ticket', newTicket);
    }
  }
}
