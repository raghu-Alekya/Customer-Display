import 'package:equatable/equatable.dart';

class Inventory_Tag_Entity extends Equatable {
  final int id;
  final String name;
  final String slug;
  final String description;
  final int count;

  const Inventory_Tag_Entity({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.count,
  });

  @override
  List<Object?> get props => [id, name, slug, description, count];
}
