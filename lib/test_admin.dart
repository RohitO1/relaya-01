// ignore_for_file: avoid_print, unused_local_variable
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Pass an empty string for now, we just want to see if `listUsers` compiles.
  final client = SupabaseClient('https://tkcdzuthjrxpfczqathy.supabase.co', '');
  try {
    final users = await client.auth.admin.listUsers();
    print('Users API found!');
  } catch (e) {
    print('Error or no users: $e');
  }
}
