class AddressModel {
  final String id;
  final String title; // Например: "Дом", "Работа" или просто "Ул. Пушкина 10"
  final double latitude;
  final double longitude;
  final String fullAddress;

  AddressModel({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.fullAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'lat': latitude,
      'lng': longitude,
      'address': fullAddress,
    };
  }

  factory AddressModel.fromMap(String id, Map<String, dynamic> map) {
    return AddressModel(
      id: id,
      title: map['title'] ?? '',
      latitude: map['lat'] ?? 0.0,
      longitude: map['lng'] ?? 0.0,
      fullAddress: map['address'] ?? '',
    );
  }
}