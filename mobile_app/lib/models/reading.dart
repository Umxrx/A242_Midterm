class Reading {
  final int id;
  final String deviceId;
  final double temperature;
  final double humidity;
  final int alert;
  final DateTime timestamp;

  Reading({
    required this.id,
    required this.deviceId,
    required this.temperature,
    required this.humidity,
    required this.alert,
    required this.timestamp,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: int.parse(json['id'].toString()),
      deviceId: json['device_id'] ?? '',
      temperature: double.parse(json['temperature'].toString()),
      humidity: double.parse(json['humidity'].toString()),
      alert: int.parse(json['alert'].toString()),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'temperature': temperature,
      'humidity': humidity,
      'alert': alert,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
