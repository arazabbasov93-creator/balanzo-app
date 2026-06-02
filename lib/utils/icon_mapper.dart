import 'package:flutter/material.dart';

const _map = <String, IconData>{
  'local_grocery_store': Icons.local_grocery_store,
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'local_pharmacy': Icons.local_pharmacy,
  'checkroom': Icons.checkroom,
  'bolt': Icons.bolt,
  'school': Icons.school,
  'category': Icons.category,
  'home': Icons.home,
  'sports': Icons.sports,
  'local_cafe': Icons.local_cafe,
  'devices': Icons.devices,
  'child_friendly': Icons.child_friendly,
  'pets': Icons.pets,
  'flight': Icons.flight,
  'fitness_center': Icons.fitness_center,
};

IconData iconForName(String name) => _map[name] ?? Icons.category;
