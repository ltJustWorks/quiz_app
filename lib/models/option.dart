class QuizOption {
  final String label;
  final String text;

  QuizOption({required this.label, required this.text});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(label: json['label'], text: json['text']);
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'text': text};
  }
}
