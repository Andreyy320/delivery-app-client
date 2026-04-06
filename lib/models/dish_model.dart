class Dish {
  final String name;
  final String description;
  final double price;
  final String imagePath;
  final String category;

  Dish({
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'imagePath': imagePath,
    'category': category,
  };

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    name: json['name'],
    description: json['description'],
    price: (json['price'] as num).toDouble(),
    imagePath: json['imagePath'],
    category: json['category'],
  );
}

