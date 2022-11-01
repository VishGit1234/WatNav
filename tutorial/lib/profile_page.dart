import 'package:flutter/material.dart';

const int itemCount = 20;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (BuildContext context, int index) {
        return ListTile(
          title: Text('bruv ${(index + 1)}'),
          leading: const Icon(Icons.person),
          trailing: Icon(Icons.select_all),
          onTap: () {
            debugPrint('bruv ${(index + 1)}');
          },
        );
      },
    );
  }
}
