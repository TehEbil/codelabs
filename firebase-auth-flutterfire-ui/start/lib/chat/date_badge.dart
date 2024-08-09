import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DateBadge extends StatelessWidget {
  final Timestamp? timestamp;

  const DateBadge({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) return const SizedBox.shrink();

    DateTime date = timestamp!.toDate();
    String formattedDate;
    final now = DateTime.now();
    if (_isSameDay(timestamp, Timestamp.fromDate(now))) {
      formattedDate = "Heute";
    } else if (_isSameDay(timestamp, Timestamp.fromDate(now.subtract(const Duration(days: 1))))) {
      formattedDate = "Gestern";
    } else {
      formattedDate =
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(formattedDate),
      ),
    );
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    final d1 = t1.toDate();
    final d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
