class RowProperties {
  double tempoNumber;
  bool swing;
  String swingText;

  RowProperties(
      {this.tempoNumber = 0.0, this.swing = false, this.swingText = ''});

  Map<String, dynamic> toJson() {
    return {
      'tempoNumber': tempoNumber,
      'swing': swing,
      'swingText': swingText,
    };
  }

  factory RowProperties.fromJson(Map<String, dynamic> json) {
    return RowProperties(
      tempoNumber: json['tempoNumber'] ?? 0.0,
      swing: json['swing'] ?? false,
      swingText: json['swingText'] ?? '',
    );
  }
}
