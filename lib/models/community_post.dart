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
    this.isOwner = false,
    this.status = 'approved',
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
  final bool isOwner;
  final String status;

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
      isOwner: json['is_owner'] == true || json['is_owner'] == 1 || json['is_owner'] == '1',
      status: json['status']?.toString() ?? 'approved',
    );
  }
}

class Comment {
  Comment({required this.author, required this.text, this.id = 0, this.isOwner = false, this.authorPhoto});
  final int id;
  final bool isOwner;
  final String author;
  final String text;
  final String? authorPhoto;
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: int.tryParse(json['id'].toString()) ?? 0,
    isOwner: json['is_owner'] == true || json['is_owner'] == 1 || json['is_owner'] == '1',
    author: json['author']?.toString() ?? 'সদস্য',
    text: json['text']?.toString() ?? '',
    authorPhoto: json['author_photo']?.toString(),
  );
}
