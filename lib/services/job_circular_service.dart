import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/job_circular.dart';

class JobCircularService {
  JobCircularService._();

  static final JobCircularService instance = JobCircularService._();

  static const endpoint =
      'https://fire.manobikishwarganj.com/api/jobs/list.php';
  static const timeout = Duration(seconds: 15);

  static List<JobCircular> parseResponse(Map<String, dynamic> response) {
    if (response['success'] != true) {
      throw FormatException(
        response['message']?.toString() ?? 'চাকরির বিজ্ঞপ্তি পাওয়া যায়নি।',
      );
    }
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('চাকরির তালিকার ফরম্যাট সঠিক নয়।');
    }
    return data.map((raw) {
      if (raw is! Map) {
        throw const FormatException('চাকরির বিজ্ঞপ্তির তথ্য সঠিক নয়।');
      }
      return JobCircular.fromJson(Map<String, dynamic>.from(raw));
    }).toList(growable: false);
  }

  Future<List<JobCircular>> fetchCirculars() async {
    final response = await http.get(
      Uri.parse(endpoint),
      headers: const {'Accept': 'application/json'},
    ).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('সার্ভার থেকে বিজ্ঞপ্তি লোড করা যায়নি (HTTP ${response.statusCode})।');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('সার্ভারের তথ্য সঠিক নয়।');
    }
    return parseResponse(decoded);
  }
}
