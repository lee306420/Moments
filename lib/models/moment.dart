class Moment {
  String id;
  String content;
  List<String> imagePaths;
  DateTime createTime;
  int likes;
  List<Comment> comments;
  String authorName;
  String? authorAvatar;

  Moment({
    required this.id,
    required this.content,
    required this.imagePaths,
    required this.createTime,
    this.likes = 0,
    List<Comment>? comments,
    required this.authorName,
    this.authorAvatar,
  }) : comments = comments ?? [];
}

class Comment {
  String id;
  String content;
  DateTime createTime;
  String authorName;
  String? authorAvatar;
  bool isCurrentUser;

  Comment({
    required this.id,
    required this.content,
    required this.createTime,
    required this.authorName,
    this.authorAvatar,
    this.isCurrentUser = false,
  });
}
