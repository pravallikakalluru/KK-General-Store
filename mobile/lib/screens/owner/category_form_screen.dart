import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

/// Create/edit form for a category. Pass [category] to edit, omit to create.
class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.category});

  final Category? category;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sortOrderController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _sortOrderController = TextEditingController(
      text: widget.category != null ? '${widget.category!.sortOrder}' : '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
      final provider = context.read<CategoryProvider>();
      if (_isEditing) {
        await provider.updateCategory(
          id: widget.category!.id,
          name: _nameController.text.trim(),
          sortOrder: sortOrder,
        );
      } else {
        await provider.createCategory(
          name: _nameController.text.trim(),
          sortOrder: sortOrder,
        );
      }
      if (mounted) {
        ErrorHandler.showMessage(context, _isEditing ? 'Category updated' : 'Category created');
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Category' : 'New Category')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Category name',
                controller: _nameController,
                prefixIcon: Icons.category_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Sort order',
                controller: _sortOrderController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.sort,
                hintText: 'Lower numbers show first',
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: _isEditing ? 'Save Changes' : 'Create Category',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
