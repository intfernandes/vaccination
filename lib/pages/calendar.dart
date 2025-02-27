import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database.dart';

import 'notification_page.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  final DatabaseMethods _databaseMethods = DatabaseMethods();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _databaseMethods.getAllEvents();
      final newEvents = <DateTime, List<dynamic>>{};
      for (var doc in events.docs) {
        final event = doc.data() as Map<String, dynamic>;
        event['id'] = doc.id;
        final date = event['date'];
        if (date is Timestamp) {
          final dateTime = date.toDate();
          final dateKey = DateTime(dateTime.year, dateTime.month, dateTime.day);
          if (newEvents[dateKey] == null) newEvents[dateKey] = [];
          newEvents[dateKey]!.add(event);
        }
      }
      setState(() {
        _events = newEvents;
      });
    } catch (e) {
      print('Error loading events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events. Please try again later.')),
      );
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  void _showAddEventDialog({Map<String, dynamic>? existingEvent}) {
    final _formKey = GlobalKey<FormState>();
    String title = existingEvent?['title'] ?? '';
    String description = existingEvent?['description'] ?? '';
    String place = existingEvent?['place'] ?? '';
    String startTime = existingEvent?['startTime'] ?? '';
    String endTime = existingEvent?['endTime'] ?? '';
    DateTime selectedDate = existingEvent != null
        ? (existingEvent['date'] as Timestamp).toDate()
        : _selectedDay;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existingEvent == null ? 'Add Event' : 'Edit Event'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: title,
                    decoration: InputDecoration(labelText: 'Title'),
                    validator: (value) => value!.isEmpty ? 'Title cannot be empty' : null,
                    onSaved: (value) => title = value!,
                  ),
                  TextFormField(
                    initialValue: description,
                    decoration: InputDecoration(labelText: 'Description'),
                    onSaved: (value) => description = value!,
                  ),
                  TextFormField(
                    initialValue: place,
                    decoration: InputDecoration(labelText: 'Place'),
                    onSaved: (value) => place = value!,
                  ),
                  TextFormField(
                    initialValue: startTime,
                    decoration: InputDecoration(labelText: 'Start Time (HH:MM)'),
                    validator: (value) => value!.isEmpty ? 'Start time cannot be empty' : null,
                    onSaved: (value) => startTime = value!,
                  ),
                  TextFormField(
                    initialValue: endTime,
                    decoration: InputDecoration(labelText: 'End Time (HH:MM)'),
                    validator: (value) => value!.isEmpty ? 'End time cannot be empty' : null,
                    onSaved: (value) => endTime = value!,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null && pickedDate != selectedDate) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Text('Pick Event Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  if (existingEvent == null) {
                    await _databaseMethods.addEvent(
                      "userId", // Replace with actual user ID
                      title,
                      description,
                      place,
                      selectedDate,
                      startTime,
                      endTime,
                    );
                  } else {
                    await _databaseMethods.updateEvent(
                      existingEvent['id'],
                      "userId", // Replace with actual user ID
                      title,
                      description,
                      place,
                      selectedDate,
                      startTime,
                      endTime,
                    );
                  }
                  Navigator.pop(context);
                  _loadEvents();
                  setState(() {});
                }
              },
              child: Text(existingEvent == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCalendar(),
            SizedBox(height: 20),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        child: Icon(Icons.add),
        backgroundColor: Colors.pink,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDay),
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
          Row(
            children: [
              PopupMenuButton<CalendarFormat>(
                onSelected: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: CalendarFormat.month,
                    child: Text('Month View'),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.twoWeeks,
                    child: Text('2 Weeks View'),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.week,
                    child: Text('Week View'),
                  ),
                ],
                child: Row(
                  children: [
                    Text(
                      _calendarFormat == CalendarFormat.month
                          ? 'Month'
                          : _calendarFormat == CalendarFormat.twoWeeks
                          ? '2 Weeks'
                          : 'Week',
                      style: TextStyle(fontSize: 18, color: Colors.pink),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.pink),
                  ],
                ),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.pink),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: TableCalendar(
        firstDay: DateTime.utc(2010, 10, 16),
        lastDay: DateTime.utc(2030, 3, 14),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red),
          holidayTextStyle: TextStyle(color: Colors.red),
          todayDecoration: BoxDecoration(
            color: Colors.pink.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.pink,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.pink),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.pink),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
          weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        onDaySelected: _onDaySelected,
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _buildEventList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _databaseMethods.getEventsForDay(_selectedDay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.pink));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No events for ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final event = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final eventId = snapshot.data!.docs[index].id;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: EdgeInsets.only(bottom: 15),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          event['title'] ?? 'Untitled Event',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEventDialog(existingEvent: {...event, 'id': eventId}),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmationDialog(eventId),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    _buildEventProperty(Icons.access_time, '${event['startTime'] ?? 'N/A'} - ${event['endTime'] ?? 'N/A'}'),
                    _buildEventProperty(Icons.location_on, event['place'] ?? 'No location'),
                    _buildEventProperty(Icons.description, event['description'] ?? 'No description'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventProperty(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event'),
        content: Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _databaseMethods.deleteEvent(eventId);
              Navigator.pop(context);
              _loadEvents();
              setState(() {});
            },
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}