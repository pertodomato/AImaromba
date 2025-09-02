import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title; final String subtitle; final Widget? trailing; final IconData icon;
  const StatCard({super.key, required this.title, required this.subtitle, this.trailing, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
