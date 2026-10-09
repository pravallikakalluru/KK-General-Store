import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

const List<String> _kUnits = ['pc', 'kg', 'g', 'litre', 'ml', 'pack', 'dozen', 'box', '100 g', '50 g', '1 piece'];

/// Default selling quantity/weight, automatically applied by category —
/// mirrors backend/seed.py's CATALOG comment. New products in one of these
/// categories get their Unit field pre-filled; the owner can still edit it.
const Map<String, String> _categoryDefaultUnit = {
  'Leafy Vegetables': '50 g',
  'Vegetables': '100 g',
  'Root Vegetables': '100 g',
  'Gourds': '100 g',
  'Mushrooms': '100 g',
  'Fruits': '100 g',
  'Coconut': '1 piece',
};

/// Create/edit form for a product, including gallery/camera image upload
/// via image_picker, sent as multipart/form-data per API_CONTRACT.md.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nameTeController;
  late final TextEditingController _searchAliasesController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitController;
  final _picker = ImagePicker();

  int? _categoryId;
  // Tracks whether the current Unit value was auto-filled by us (rather
  // than typed by the owner), so picking a category doesn't clobber a
  // manual edit — only ever overwrites its own previous suggestion.
  String? _autoFilledUnit;
  bool _isAvailable = true;
  XFile? _pickedImage;
  bool _isSubmitting = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _nameTeController = TextEditingController(text: product?.nameTe ?? '');
    _searchAliasesController =
        TextEditingController(text: product?.searchAliases ?? '');
    _priceController = TextEditingController(text: product != null ? '${product.price}' : '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _unitController = TextEditingController(text: product?.unit ?? 'pc');
    _categoryId = product?.categoryId;
    _isAvailable = product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameTeController.dispose();
    _searchAliasesController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  /// Applies the category->default-unit mapping, but only for a brand-new
  /// product whose Unit field is empty or still holds our own last
  /// suggestion — never overwrites something the owner typed themselves.
  void _applyCategoryDefaultUnit(int categoryId, List<Category> categories) {
    if (_isEditing) return;
    Category? category;
    for (final c in categories) {
      if (c.id == categoryId) {
        category = c;
        break;
      }
    }
    if (category == null) return;
    final suggested = _categoryDefaultUnit[category.name];
    if (suggested == null) return;
    if (_unitController.text.isEmpty || _unitController.text == _autoFilledUnit) {
      setState(() {
        _unitController.text = suggested;
        _autoFilledUnit = suggested;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() => _pickedImage = image);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ErrorHandler.showMessage(context, 'Please select a category');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final provider = context.read<ProductProvider>();
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

      if (_isEditing) {
        await provider.updateProduct(
          id: widget.product!.id,
          name: _nameController.text.trim(),
          nameTe: _nameTeController.text.trim(),
          searchAliases: _searchAliasesController.text.trim(),
          categoryId: _categoryId,
          price: price,
          unit: _unitController.text.trim(),
          description: _descriptionController.text.trim(),
          isAvailable: _isAvailable,
          image: _pickedImage,
        );
      } else {
        await provider.createProduct(
          name: _nameController.text.trim(),
          nameTe: _nameTeController.text.trim().isEmpty ? null : _nameTeController.text.trim(),
          searchAliases: _searchAliasesController.text.trim().isEmpty
              ? null
              : _searchAliasesController.text.trim(),
          categoryId: _categoryId!,
          price: price,
          unit: _unitController.text.trim(),
          description: _descriptionController.text.trim(),
          isAvailable: _isAvailable,
          image: _pickedImage,
        );
      }

      if (mounted) {
        ErrorHandler.showMessage(context, _isEditing ? 'Product updated' : 'Product created');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;
    final existingImageUrl = ApiConfig.resolveImageUrl(widget.product?.imageUrl);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceSheet,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.72,
                        heightFactor: 0.72,
                        child: _buildImagePreview(existingImageUrl),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _showImageSourceSheet,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(_pickedImage == null && existingImageUrl.isEmpty
                      ? 'Add photo'
                      : 'Change photo'),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Product name (English)',
                controller: _nameController,
                prefixIcon: Icons.shopping_basket_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Product name (Telugu, optional)',
                controller: _nameTeController,
                prefixIcon: Icons.translate_outlined,
                hintText: 'e.g. అరటిపండ్లు',
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Also search as (optional)',
                controller: _searchAliasesController,
                prefixIcon: Icons.search_outlined,
                hintText: 'e.g. ragulu, raagulu, finger millet',
                maxLines: 2,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Other spellings customers might type — Telugu words in '
                  'English letters, nicknames, common misspellings. '
                  'Separate with commas.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _categoryId = value);
                  if (value != null) _applyCategoryDefaultUnit(value, categories);
                },
                validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: 'Price (₹)',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.currency_rupee,
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: 'Unit',
                      controller: _unitController,
                      hintText: 'e.g. 100 g, kg',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: _kUnits
                    .map(
                      (u) => ActionChip(
                        label: Text(u, style: const TextStyle(fontSize: 11.5)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _unitController.text = u;
                            _autoFilledUnit = null;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Description (optional)',
                controller: _descriptionController,
                maxLines: 3,
                prefixIcon: Icons.notes_outlined,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for purchase'),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _isEditing ? 'Save Changes' : 'Create Product',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String existingImageUrl) {
    if (_pickedImage != null) {
      return Image.file(
        File(_pickedImage!.path),
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    }
    if (existingImageUrl.isNotEmpty) {
      return Image.network(
        existingImageUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.shopping_basket_outlined,
          size: 40,
          color: AppColors.textSecondary,
        ),
      );
    }
    return const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.textSecondary);
  }
}
