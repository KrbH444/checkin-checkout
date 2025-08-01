import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mock_company/testcard.dart';

class MyLogin extends StatefulWidget {
  const MyLogin({super.key});

  @override
  MyLoginState createState() => MyLoginState();
}

class MyLoginState extends State<MyLogin> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double pageWidth = 0;
  double pageHeight = 0;
  DateTime expires = DateTime.now();
  late SharedPreferences _prefs;
  bool _isLoading = false;

  void showLoadingScreen() {
    setState(() {
      _isLoading = true;
    });
  }

  void hideLoadingScreen() {
    setState(() {
      _isLoading = false;
    });
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

  void login(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://reqres.in/api/login'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': 'reqres-free-v1',
          },
          body: jsonEncode({'email': email, 'password': password}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token'].toString();

          // Fetch the user's ID based on the entered email
          final userId = await fetchUserIdByEmail(email, token);

          if (userId != null) {
            // Fetch the user's info based on the obtained ID
            final userInfo = await fetchUserInfo(userId, token);

            // Navigate to the user's info page
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TestCard(userInfo),
              ),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User not found.'),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration failed. Please try again.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide both email and password.'),
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle other exceptions (e.g., network errors)
      print('Error: $e');
    }
  }

  Future<String?> fetchUserIdByEmail(String email, String token) async {
    try {
      int page = 1; // Start with the first page

      while (true) {
        final apiResponse = await http.get(
          Uri.parse('https://reqres.in/api/users?page=$page'),
          headers: {
            'Authorization': 'Bearer $token',
            'x-api-key': 'reqres-free-v1',
          },
        );

        if (apiResponse.statusCode == 200) {
          final userData = jsonDecode(apiResponse.body);
          if (userData != null && userData.containsKey('data')) {
            final users = userData['data'];

            // Find the user with the matching email
            final user = users.firstWhere(
              (user) => user['email'] == email,
              orElse: () => null,
            );

            if (user != null) {
              return user['id'].toString();
            }
          }

          final totalPages = userData['total_pages'];
          if (page < totalPages) {
            page++;
          } else {
            // All pages have been searched, and the user was not found
            break;
          }
        } else {
          // API request failed
          return null;
        }
      }

      return null; // User not found on any page
    } catch (e) {
      print('Error in fetchUserIdByEmail: $e');
      return null; // Handle other exceptions
    }
  }

  Future<Map<String, dynamic>> fetchUserInfo(
      String userId, String token) async {
    final apiResponse = await http.get(
      Uri.parse('https://reqres.in/api/users/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'x-api-key': 'reqres-free-v1',
      },
    );

    if (apiResponse.statusCode == 200) {
      final userInfo = jsonDecode(apiResponse.body);
      return userInfo;
    } else {
      throw Exception('API request failed');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    pageWidth = MediaQuery.of(context).size.width;
    pageHeight = MediaQuery.of(context).size.height;
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool isChecked = false;
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  void _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    // Load saved values
    setState(() {
      isChecked = _prefs.getBool('remember') ?? false;
      if (isChecked) {
        email.text = _prefs.getString('lastEmail') ?? '';
        password.text = _prefs.getString('lastPassword') ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo[50],
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SizedBox(
              height: (pageHeight + pageWidth) * 0.3,
              child: AppBar(
                backgroundColor: Colors.indigo[800],
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.only(bottomRight: Radius.circular(150)),
                ),
                elevation: 0,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 130),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                  // Adjust the radius as needed
                  backgroundImage: const AssetImage('Assets/Mock.png'),
                  radius: (pageHeight + pageWidth) * 0.045,
                ),
                Text(
                  '\t\t\tWelcome\n\t\t\t\t\t\tBack!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: (pageHeight + pageWidth) * 0.03),
                ),
              ]),
            ),
            Stack(
              children: [
                SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: pageHeight * 0.5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 35, right: 35),
                          child: Column(
                            children: [
                              TextField(
                                controller: email,
                                style: const TextStyle(color: Colors.indigo),
                                decoration: InputDecoration(
                                    fillColor: Colors.white,
                                    filled: true,
                                    hintText: "Email",
                                    hintStyle: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.indigo.shade800,
                                      ),
                                    )),
                              ),
                              const SizedBox(
                                height: 30,
                              ),
                              TextField(
                                controller: password,
                                style: const TextStyle(color: Colors.indigo),
                                obscureText: true,
                                decoration: InputDecoration(
                                    fillColor: Colors.white,
                                    filled: true,
                                    hintText: "Password",
                                    hintStyle: const TextStyle(
                                      color: Colors.indigo,
                                      fontSize: 15,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.indigo.shade800,
                                      ),
                                    )),
                              ),
                              const SizedBox(
                                height: 40,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Remember Me",
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: Colors.indigo,
                                    onChanged: (value) {
                                      isChecked = value ?? false;
                                      _prefs.setBool('remember', isChecked);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Sign in',
                                    style: TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      login(email.text.toString(),
                                          password.text.toString());
                                      setState(() {
                                        _isLoading = true;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.teal, // Background color
                                      shape:
                                          const CircleBorder(), // Make it circular
                                      padding: const EdgeInsets.all(
                                          20), // Adjust padding as needed
                                      elevation:
                                          5, // Add elevation for a shadow effect
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  )
                                ],
                              ),
                              _isLoading
                                  ? _buildLoadingWidget()
                                  : const SizedBox(),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
