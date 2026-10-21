import 'package:flutter/material.dart';
import 'apps_products_management_screen.dart';

export 'apps_products_management_screen.dart';

class ProductsManagementScreen extends StatelessWidget {
  final String? initialAppId;

  const ProductsManagementScreen({super.key, this.initialAppId});

  @override
  Widget build(BuildContext context) {
    return AppsAndProductsManagementScreen(initialAppId: initialAppId);
  }
}
