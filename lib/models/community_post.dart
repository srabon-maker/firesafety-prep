
class CommunityPost {
  CommunityPost({
    required this.author,
    required this.time,
    required this.category,
    required this.text,
    required this.comments,
    this.likes = 0,
  });

  final String author;
  final String time;
  final String category;
  final String text;
  final List<Comment> comments;

  int likes;
  bool liked = false;
}

class Comment {
  Comment({
    required this.author,
    required this.text,
  });

  final String author;
  final String text;
}
