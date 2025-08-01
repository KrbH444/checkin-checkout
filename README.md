# Employee Attendance Management System

A comprehensive Flutter-based employee attendance and task management application with location-based check-in/out functionality, ticket management, and user authentication.

## 📱 Overview

This application is designed to streamline employee attendance tracking and task management in organizations. It provides a modern, user-friendly interface for employees to check in/out, manage tasks, and track their attendance history with location verification.

## ✨ Features

### 🔐 Authentication & Security
- **Secure Login System**: Email and password-based authentication
- **Session Management**: Automatic logout after 10 minutes of inactivity
- **Remember Me**: Option to save login credentials
- **Secure Storage**: Encrypted storage for sensitive data

### 📍 Location-Based Attendance
- **GPS Verification**: Check-in/out only allowed within 500 meters of office location
- **Time Restrictions**: 
  - Check-in: 8:00 AM - 4:00 PM
  - Check-out: After check-in until 8:00 PM
- **Location Permissions**: Automatic permission requests for GPS access

### 📊 Attendance Tracking
- **Real-time Clock**: Live time display
- **Attendance History**: Monthly view of check-in/out times
- **Attendance Statistics**: 
  - Present days count
  - Late arrivals (after 10:00 AM)
  - Absent days
  - Attendance percentage
- **Undo Functionality**: Ability to undo check-out if needed

### 🎫 Ticket Management
- **Create Tickets**: Employees can create task tickets
- **Assign Tasks**: Assign tickets to other employees
- **Ticket Categories**: Task, Issue, or Other
- **Privacy Options**: Public or private tickets
- **Edit & Delete**: Full CRUD operations for own tickets
- **Status Tracking**: Mark tickets as done/undone

### 👤 User Profile
- **Employee Information**: Display ID, name, and email
- **Profile Picture**: Avatar display from API
- **Personal Dashboard**: Overview of attendance and assigned tasks

### 🎨 User Interface
- **Modern Design**: Clean, professional UI with indigo/teal color scheme
- **Responsive Layout**: Adapts to different screen sizes
- **Tab Navigation**: Easy switching between features
- **Loading Indicators**: Visual feedback for operations
- **Hover Effects**: Interactive elements with tooltips

## 🛠 Technical Architecture

### Frontend Framework
- **Flutter**: Cross-platform mobile development
- **Dart**: Programming language
- **Material Design**: UI components and styling

### Backend & Data
- **SQLite Database**: Local data storage using `sqflite_common_ffi`
- **HTTP API**: Integration with ReqRes API for user data
- **Local Storage**: Shared preferences for app settings

### Key Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  shared_preferences: ^2.2.0          # Local data storage
  geolocator: ^14.0.1                 # GPS location services
  permission_handler: ^12.0.0+1       # Permission management
  sqflite: ^2.3.0                     # SQLite database
  sqflite_common_ffi: ^2.3.0+2        # Cross-platform SQLite
  http: ^1.1.0                        # HTTP requests
  flutter_secure_storage: ^9.2.4      # Secure data storage
  intl: ^0.20.2                       # Internationalization
  path_provider: ^2.1.0               # File system access
```

### Database Schema

#### CheckInOut Table
```sql
CREATE TABLE CheckInOut (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employeeID TEXT,
  checkDate TEXT,
  checkType TEXT,
  checkTime TEXT
)
```

#### Ticket Table
```sql
CREATE TABLE Ticket (
  ticketID INTEGER PRIMARY KEY AUTOINCREMENT,
  employeeID TEXT NOT NULL,
  employeeName TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  isPrivate INTEGER NOT NULL,
  createdDate TEXT NOT NULL,
  category TEXT NOT NULL,
  referredToEmployeeID TEXT NOT NULL
)
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.6)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/emp_attend.git
   cd emp_attend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### Configuration

1. **Location Settings**: Update the office coordinates in `lib/attend.dart`
   ```dart
   // Current coordinates (Riyadh, Saudi Arabia)
   await isNearLocation(24.686081, 46.689455);
   ```

2. **API Configuration**: The app uses ReqRes API for demo purposes
   - Base URL: `https://reqres.in/api`
   - Test credentials available in the API documentation

## 📱 Usage Guide

### For Employees

#### Login
1. Enter your email and password
2. Optionally check "Remember Me"
3. Tap the arrow button to login

#### Check-in/Check-out
1. Navigate to "Check-in & out" from the drawer menu
2. Ensure you're within 500 meters of the office
3. Tap "Check In" during work hours (8 AM - 4 PM)
4. Tap "Check Out" after check-in (until 8 PM)

#### View Attendance
1. Go to the "Home" tab
2. View your monthly attendance statistics
3. Navigate through months using arrow buttons
4. See detailed check-in/out times for each day

#### Manage Tickets
1. Go to "Create Tickets" from the drawer
2. Create new tickets with title, description, and category
3. Assign tickets to other employees
4. Mark assigned tickets as done
5. Edit or delete your own tickets

### For Administrators

The system provides comprehensive attendance tracking and task management capabilities suitable for HR and management teams.

## 🔧 Development

### Project Structure
```
lib/
├── main.dart          # Application entry point
├── login.dart         # Authentication screen
├── testcard.dart      # Main dashboard
├── attend.dart        # Check-in/out functionality
├── ticket.dart        # Ticket management
└── database.dart      # Database operations
```

### Key Components

#### Authentication (`login.dart`)
- Handles user login with email/password
- Integrates with ReqRes API
- Manages session tokens and user data

#### Dashboard (`testcard.dart`)
- Main application interface
- Tab-based navigation
- Attendance statistics and history
- User profile information

#### Attendance (`attend.dart`)
- GPS-based location verification
- Time-based check-in/out restrictions
- Local database storage for attendance records

#### Ticket Management (`ticket.dart`)
- CRUD operations for tickets
- Employee assignment functionality
- Privacy controls and status tracking

### State Management
- Uses Flutter's built-in `StatefulWidget` for state management
- Local database for persistent data storage
- Shared preferences for user settings

## 🧪 Testing

### Manual Testing Checklist
- [ ] Login with valid credentials
- [ ] Login with invalid credentials
- [ ] Check-in within office location
- [ ] Check-in outside office location
- [ ] Check-out after check-in
- [ ] Session timeout (10 minutes)
- [ ] Create new ticket
- [ ] Edit existing ticket
- [ ] Delete ticket
- [ ] Mark ticket as done
- [ ] Navigate between tabs
- [ ] View attendance history

### API Testing
The application uses the ReqRes API for demonstration purposes. For production use, replace with your organization's authentication system.

## 🔒 Security Features

- **Secure Storage**: Sensitive data encrypted using `flutter_secure_storage`
- **Session Management**: Automatic logout for security
- **Location Verification**: Prevents remote check-in/out
- **Input Validation**: Form validation and error handling
- **Permission Management**: Proper handling of location permissions

## 📊 Performance

- **Local Database**: Fast data access with SQLite
- **Efficient UI**: Responsive design with proper state management
- **Memory Management**: Proper disposal of resources and timers
- **Network Optimization**: Minimal API calls with local caching

## 🚀 Deployment

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- Create an issue in the GitHub repository
- Contact the development team
- Check the documentation for common solutions

## 🔄 Version History

- **v1.0.0** - Initial release with core attendance and ticket management features

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- ReqRes API for providing test data
- Open source community for various packages used

---

**Note**: This application is designed for demonstration purposes. For production use, implement proper security measures, use a real authentication system, and configure appropriate location coordinates for your organization.
