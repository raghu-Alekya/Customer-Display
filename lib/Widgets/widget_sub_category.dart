import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../Constants/text.dart';
import '../Helper/Extentions/theme_notifier.dart';
import '../Utilities/shimmer_effect.dart';

class SubCategoryGridWidget extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> subCategories;
  final int? selectedSubCategoryIndex;
  final Function(int) onSubCategoryTapped;

  const SubCategoryGridWidget({
    super.key,
    required this.isLoading,
    required this.subCategories,
    required this.onSubCategoryTapped,
    this.selectedSubCategoryIndex,
  });

  Widget _buildImage(String imagePath) {
    if (imagePath.startsWith('assets/') && imagePath.endsWith('.svg')) {
      return SizedBox(
        height: 40,
        width: 40,
        child: SvgPicture.asset(
          imagePath,
          height: 40,
          width: 40,
          placeholderBuilder: (context) => const Icon(Icons.image, size: 40),
        ),
      );
    } else if (imagePath.startsWith('assets/')) {
      return SizedBox(
        height: 40,
        width: 40,
        child: Image.asset(
          imagePath,
          height: 40,
          width: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 40),
        ),
      );
    } else {
      return SizedBox(
        height: 40,
        width: 40,
        child: Image.network(
          imagePath,
          height: 40,
          width: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 40),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeHelper = Provider.of<ThemeNotifier>(context);
    return Expanded(
      child: isLoading
          ? ShimmerEffect.rectangular(height: 200)
          : subCategories.isEmpty
          ? const Center(
        child: Text(TextConstants.noSubcategoriesAvailable,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 20,
          crossAxisSpacing: 10,
          childAspectRatio: 40 / 40,
        ),
        itemCount: subCategories.length,
        itemBuilder: (context, index) {
          final subCategory = subCategories[index];
          final isSelected = selectedSubCategoryIndex == index;
          return GestureDetector(
            onTap: () => onSubCategoryTapped(index),
            child: Card(
              color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.secondaryBackground : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder( // Build #1.0.27
                borderRadius: BorderRadius.circular(8),
                side: isSelected
                    ? BorderSide(color: Colors.red, width: 2)
                    : BorderSide(
                    color: themeHelper.themeMode == ThemeMode.dark
                        ? ThemeNotifier.borderColor
                        : Colors.black12,
                    width: 1
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildImage(subCategory['image']),
                    const SizedBox(height: 8),
                    Text(
                      subCategory['name'],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.black,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      subCategory['count'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: themeHelper.themeMode == ThemeMode.dark ? ThemeNotifier.textDark : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}