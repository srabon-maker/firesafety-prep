import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/community_post.dart';

void main() {
  test('community feed maps server counts and image', () {
    final post = CommunityPost.fromJson({
      'id': 18,
      'author': 'Test Author',
      'body': 'Photo post',
      'image_url': 'https://example.org/uploads/community/test.jpg',
      'author_photo': null,
      'likes_count': 7,
      'comments_count': 3,
      'liked': true,
      'created_at': '2026-11-18 12:00:00',
    });
    expect(post.id, 18);
    expect(post.text, 'Photo post');
    expect(post.imageUrl, contains('test.jpg'));
    expect(post.likes, 7);
    expect(post.commentCount, 3);
    expect(post.liked, true);
  });

  test('ownership and moderation status are parsed with safe defaults', () {
    final mine = CommunityPost.fromJson({'id': 7, 'is_owner': true, 'status': 'pending'});
    expect(mine.isOwner, isTrue);
    expect(mine.status, 'pending');
    final other = CommunityPost.fromJson({'id': 8});
    expect(other.isOwner, isFalse);
    expect(other.status, 'approved');
    final comment = Comment.fromJson({'id': '9', 'is_owner': 1, 'text': 'test'});
    expect(comment.id, 9);
    expect(comment.isOwner, isTrue);
    expect(Comment.fromJson({}).isOwner, isFalse);
  });

  test('photo-only post is valid with empty text', () {
    final post = CommunityPost.fromJson({
      'id': 2,
      'author': 'A',
      'body': '',
      'image_url': 'https://example.org/photo.png',
      'likes_count': 0,
      'comments_count': 0,
      'liked': false,
    });
    expect(post.text, isEmpty);
    expect(post.imageUrl, isNotNull);
  });
}
