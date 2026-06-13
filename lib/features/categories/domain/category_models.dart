class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.color,
    required this.totalMinor,
    required this.itemCount,
  });

  final int categoryId;
  final String categoryName;
  final String? color;
  final int totalMinor;
  final int itemCount;
}
