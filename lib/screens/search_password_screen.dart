import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/providers/app_provider.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';
import 'package:super_locker/services/clipboard_manager.dart';
import 'package:super_locker/services/auto_lock_service.dart';
import 'package:super_locker/widgets/password_strength_indicator.dart';

class SearchPasswordScreen extends StatefulWidget {
  const SearchPasswordScreen({super.key});

  @override
  State<SearchPasswordScreen> createState() => _SearchPasswordScreenState();
}

class _SearchPasswordScreenState extends State<SearchPasswordScreen>
    with AutoLockMixin<SearchPasswordScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  final ClipboardManager _clipboardManager = ClipboardManager();
  
  List<PasswordEntry> _searchResults = [];
  bool _isSearching = false;
  String _selectedCategory = '';
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCategories() async {
    final passwordService = Provider.of<PasswordService>(context, listen: false);
    _categories = await passwordService.getCategories();
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    onUserInteraction(); // Track user activity for auto-lock
    _performSearch();
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _selectedCategory.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final passwordService = Provider.of<PasswordService>(context, listen: false);
      await passwordService.loadPasswords();
      
      _searchResults = passwordService.searchPasswords(query);
      
      // TODO: Add category filtering if needed
      if (_selectedCategory.isNotEmpty) {
        _searchResults = _searchResults.where((entry) => 
          entry.category == _selectedCategory).toList();
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category ?? '';
    });
    _performSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _selectedCategory = '';
      _searchResults = [];
    });
  }

  @override
  Widget buildWithAutoLock(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Passwords'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearSearch,
            tooltip: 'Clear search',
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () {
              Provider.of<AppProvider>(context, listen: false).lockApp();
              Navigator.of(context).pushReplacementNamed('/device-auth');
            },
            tooltip: 'Lock app',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by website, username, or notes...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onTap: onUserInteraction,
                ),
                const SizedBox(height: 12),
                // Category filter
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Filter by category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ..._categories.map((category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      )),
                    ],
                    onChanged: _onCategorySelected,
                  ),
              ],
            ),
          ),
          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching passwords...'),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty && _selectedCategory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Enter a search term or select a category',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No passwords found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final entry = _searchResults[index];
        return _buildPasswordCard(entry);
      },
    );
  }

  Widget _buildPasswordCard(PasswordEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and category
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (entry.category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Username and URL
            if (entry.username.isNotEmpty)
              _buildInfoRow(Icons.person, 'Username', entry.username),
            if (entry.url.isNotEmpty)
              _buildInfoRow(Icons.link, 'Website', entry.url),
            if (entry.notes.isNotEmpty)
              _buildInfoRow(Icons.note, 'Notes', entry.notes),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _viewPassword(entry),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyUsername(entry),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copyPassword(entry),
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Copy Pass'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _viewPassword(PasswordEntry entry) async {
    onUserInteraction();
    
    // Require biometric authentication
    final authenticated = await _authService.authenticateUser(
      reason: 'Authenticate to view password for ${entry.title}',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Get master password and decrypt
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final masterPassword = appProvider.masterPassword;
    
    if (masterPassword == null) {
      _showMessage('Master password not available', isError: true);
      return;
    }

    try {
      final decryptedPassword = await appProvider.encryptionService
          .decryptText(entry.encryptedPassword, masterPassword);
      
      if (decryptedPassword != null) {
        _showPasswordDialog(entry, decryptedPassword);
      } else {
        _showMessage('Failed to decrypt password', isError: true);
      }
    } catch (e) {
      _showMessage('Error decrypting password: $e', isError: true);
    }
  }

  void _showPasswordDialog(PasswordEntry entry, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Password for ${entry.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Password display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                password,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Password strength
            PasswordStrengthIndicator(password: password),
            const SizedBox(height: 16),
            // Copy button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _clipboardManager.copySecureData(
                    password,
                    context: context,
                    successMessage: 'Password copied securely',
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _copyUsername(PasswordEntry entry) async {
    if (entry.username.isNotEmpty) {
      await _clipboardManager.copyData(
        entry.username,
        context: context,
        successMessage: 'Username copied',
      );
    } else {
      _showMessage('No username to copy', isError: true);
    }
  }

  void _copyPassword(PasswordEntry entry) async {
    onUserInteraction();
    
    // Require biometric authentication
    final authenticated = await _authService.authenticateUser(
      reason: 'Authenticate to copy password for ${entry.title}',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Decrypt and copy password
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final masterPassword = appProvider.masterPassword;
    
    if (masterPassword == null) {
      _showMessage('Master password not available', isError: true);
      return;
    }

    try {
      final decryptedPassword = await appProvider.encryptionService
          .decryptText(entry.encryptedPassword, masterPassword);
      
      if (decryptedPassword != null) {
        await _clipboardManager.copySecureData(
          decryptedPassword,
          context: context,
          successMessage: 'Password copied securely',
        );
      } else {
        _showMessage('Failed to decrypt password', isError: true);
      }
    } catch (e) {
      _showMessage('Error copying password: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
} 