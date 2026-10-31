
import '../models/community_post.dart';

class AppData {
  static final List<CommunityPost> posts = [
    CommunityPost(
      author: 'Rafiq Rahman',
      time: '১৫ মিনিট আগে',
      category: 'ফায়ার',
      text: 'ফায়ার এক্সটিংগুইশার ব্যবহারের সময় PASS পদ্ধতির ধাপগুলো কী কী? নতুনদের জন্য সংক্ষেপে বুঝিয়ে বলুন।',
      comments: [
        Comment(
          author: 'Tanvir Hasan',
          text: 'Pull, Aim, Squeeze, Sweep — এই চারটি ধাপ।',
        ),
        Comment(
          author: 'Nusrat Jahan',
          text: 'ব্যবহারের আগে নিরাপদ বের হওয়ার পথ নিশ্চিত করতে হবে।',
        ),
      ],
      likes: 12,
    ),
    CommunityPost(
      author: 'Tania Akter',
      time: '১ ঘণ্টা আগে',
      category: 'সেইফটি',
      text: 'ফ্যাক্টরিতে ফায়ার ড্রিলের সময় কোন বিষয়গুলো বিশেষভাবে পর্যবেক্ষণ করা উচিত?',
      comments: [
        Comment(
          author: 'Shakil Ahmed',
          text: 'ইভাকুয়েশন টাইম, exit route, assembly point ও head count।',
        ),
      ],
      likes: 8,
    ),
    CommunityPost(
      author: 'Md. Hasan',
      time: '৩ ঘণ্টা আগে',
      category: 'কমপ্লায়েন্স',
      text: 'NFPA 72 অনুযায়ী ফায়ার অ্যালার্ম সিস্টেমের নিয়মিত inspection ও testing কেন গুরুত্বপূর্ণ?',
      comments: [],
      likes: 5,
    ),
  ];

  static final List<String> notes = [
    'Fire Triangle — Heat, Fuel ও Oxygen',
    'NFPA 10 — Portable Fire Extinguishers',
    'NFPA 14 — Standpipe and Hose Systems',
    'NFPA 20 — Stationary Fire Pumps',
    'NFPA 25 — Inspection, Testing and Maintenance',
    'NFPA 72 — Fire Alarm and Signaling Systems',
    'BNBC 2020 — Fire Protection',
  ];
}
