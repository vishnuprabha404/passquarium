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
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);
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
      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      await passwordService.loadPasswords();

      _searchResults = passwordService.searchPasswords(query);

      // TODO: Add category filtering if needed
      if (_selectedCategory.isNotEmpty) {
        _searchResults = _searchResults
            .where((entry) => entry.category == _selectedCategory)
            .toList();
      }

      setState(() => _isSearching = false);
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

  void _viewAllPasswords() async {
    setState(() => _isSearching = true);

    try {
      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      await passwordService.loadPasswords();

      setState(() {
        _searchResults = passwordService.passwords;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget buildWithAutoLock(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Passwords'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _viewAllPasswords,
            tooltip: 'View all passwords',
          ),
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
              'Enter a search term or tap the list icon above to view all passwords',
              textAlign: TextAlign.center,
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            entry.domain.isNotEmpty
                ? entry.domain[0].toUpperCase()
                : (entry.website.isNotEmpty ? entry.website[0].toUpperCase() : 'P'),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          entry.title.isNotEmpty ? entry.title : entry.website,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyPassword(entry),
              tooltip: 'Copy Password',
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () => _viewPassword(entry),
      ),
    );
  }



  void _viewPassword(PasswordEntry entry) async {
    onUserInteraction();

    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    print('🔍 DEBUG: Starting password view for $displayName');

    // Require biometric authentication
    print('🔍 DEBUG: Requesting authentication...');
    final authenticated = await _authService.authenticateUser(
      reason: 'Authenticate to view password for $displayName',
    );

    print('🔍 DEBUG: Authentication result: $authenticated');

    if (!authenticated) {
      print('🔍 DEBUG: Authentication failed');
      _showMessage('Authentication failed', isError: true);
      return;
    }

    print('🔍 DEBUG: Authentication successful, proceeding with decryption...');

    // Get master password and decrypt
    final authService = Provider.of<AuthService>(context, listen: false);
    final masterPassword = authService.masterPassword;

    print('🔍 DEBUG: Master password available: ${masterPassword != null}');

    if (masterPassword == null) {
      print('🔍 DEBUG: Master password is null');
      _showMessage('Master password not available', isError: true);
      return;
    }

    print('🔍 DEBUG: Starting decryption...');

    try {
      final passwordService = Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword = await passwordService.decryptPassword(entry, masterPassword);

      print('🔍 DEBUG: Decryption result: ${decryptedPassword.isNotEmpty ? "SUCCESS" : "FAILED"}');

      if (decryptedPassword.isNotEmpty) {
        print('🔍 DEBUG: Showing password dialog...');
        _showPasswordDialog(entry, decryptedPassword);
      } else {
        print('🔍 DEBUG: Decrypted password is empty');
        _showMessage('Failed to decrypt password', isError: true);
      }
    } catch (e) {
      print('🔍 DEBUG: Exception during decryption: $e');
      _showMessage('Error decrypting password: $e', isError: true);
    }
  }

  void _showPasswordDialog(PasswordEntry entry, String password) {
    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_open, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(displayName)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Website/Service Details
                _buildDetailSection('Service Details', [
                  if (entry.website.isNotEmpty)
                    _buildDetailRow('Website', entry.website, Icons.language),
                  if (entry.url.isNotEmpty && entry.url != entry.website)
                    _buildDetailRow('URL', entry.url, Icons.link),
                  if (entry.domain.isNotEmpty && entry.domain != entry.website)
                    _buildDetailRow('Domain', entry.domain, Icons.dns),
                  if (entry.category.isNotEmpty)
                    _buildDetailRow('Category', entry.category, Icons.category),
                ]),
                
                const SizedBox(height: 16),
                
                // Account Details
                _buildDetailSection('Account Details', [
                  if (entry.username.isNotEmpty)
                    _buildDetailRow('Username', entry.username, Icons.person, copyable: true),
                ]),
                
                const SizedBox(height: 16),
                
                // Password Section
                _buildDetailSection('Password', [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            password,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _clipboardManager.copySecureData(
                              password,
                              context: context,
                              successMessage: 'Password copied securely',
                            );
                          },
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy Password',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  PasswordStrengthIndicator(password: password),
                ]),
                
                const SizedBox(height: 16),
                
                // Notes Section
                if (entry.notes.isNotEmpty)
                  _buildDetailSection('Notes', [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, size: 20, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              entry.notes,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                
                const SizedBox(height: 16),
                
                // Metadata Section
                _buildDetailSection('Information', [
                  _buildDetailRow(
                    'Created', 
                    _formatDate(entry.createdAt), 
                    Icons.calendar_today,
                  ),
                  _buildDetailRow(
                    'Last Updated', 
                    _formatDate(entry.updatedAt), 
                    Icons.update,
                  ),
                ]),
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _clipboardManager.copySecureData(
                            password,
                            context: context,
                            successMessage: 'Password copied securely',
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (entry.username.isNotEmpty) {
                            _clipboardManager.copyData(
                              entry.username,
                              context: context,
                              successMessage: 'Username copied',
                            );
                          }
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('Copy Username'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (copyable)
              IconButton(
                onPressed: () {
                  _clipboardManager.copyData(
                    value,
                    context: context,
                    successMessage: '$label copied',
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy $label',
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }



  void _copyPassword(PasswordEntry entry) async {
    onUserInteraction();

    // Require biometric authentication
    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    final authenticated = await _authService.authenticateUser(
      reason: 'Authenticate to copy password for $displayName',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Decrypt and copy password
    final authService = Provider.of<AuthService>(context, listen: false);
    final masterPassword = authService.masterPassword;

    if (masterPassword == null) {
      _showMessage('Master password not available', isError: true);
      return;
    }

    try {
      final passwordService = Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword = await passwordService.decryptPassword(entry, masterPassword);

      if (decryptedPassword.isNotEmpty) {
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
