class CommunityPost {
  CommunityPost({
    required this.author,
    required this.time,
    this.category = '',
    required this.text,
    required this.comments,
    this.id = 0,
    this.imageUrl,
    this.authorPhoto,
    this.commentCount = 0,
    this.likes = 0,
    this.liked = false,
  });

  final int id;
  final String author;
  final String time;
  final String category;
  final String text;
  final String? imageUrl;
  final String? authorPhoto;
  final List<Comment> comments;
  int commentCount;
  int likes;
  bool liked;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final now = DateTime.now();
    final elapsed = created == null ? null : now.difference(created);
    final time = elapsed == null || elapsed.isNegative
        ? 'সম্প্রতি'
        : elapsed.inMinutes < 1
            ? 'এখনই'
            : elapsed.inMinutes < 60
                ? '${elapsed.inMinutes} মিনিট আগে'
                : elapsed.inHours < 24
                    ? '${elapsed.inHours} ঘণ্টা আগে'
                    : '${elapsed.inDays} দিন আগে';
    return CommunityPost(
      id: int.tryParse(json['id'].toString()) ?? 0,
      author: json['author']?.toString() ?? 'সদস্য',
      authorPhoto: json['author_photo']?.toString(),
      time: time,
      text: json['body']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      comments: [],
      commentCount: int.tryParse(json['comments_count'].toString()) ?? 0,
      likes: int.tryParse(json['likes_count'].toString()) ?? 0,
      liked: json['liked'] == true,
    );
  }
}

class Comment {
  Comment({required this.author, required this.text});
  final String author;
  final String text;
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    author: json['author']?.toString() ?? 'সদস্য',
    text: json['text']?.toString() ?? '',
  );
}
