import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/providers/app_provider.dart';
import 'package:super_locker/screens/edit_password_screen.dart';
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
                : (entry.website.isNotEmpty
                    ? entry.website[0].toUpperCase()
                    : 'P'),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (entry.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 24),
          onSelected: (value) async {
            print('🔧 DEBUG: PopupMenu selected: $value');
            switch (value) {
              case 'view':
                _viewPassword(entry);
                break;
              case 'copy':
                _copyPassword(entry);
                break;
              case 'browser':
                _openInBrowser(entry);
                break;
            }
          },
          itemBuilder: (context) {
            print('🔧 DEBUG: Building popup menu items');
            return [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 20),
                    SizedBox(width: 8),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 8),
                    Text('Copy Password'),
                  ],
                ),
              ),
              if (entry.website.isNotEmpty || entry.url.isNotEmpty)
                const PopupMenuItem(
                  value: 'browser',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser, size: 20),
                      SizedBox(width: 8),
                      Text('Open in Browser'),
                    ],
                  ),
                ),
            ];
          },
        ),
        onTap: () => _viewPassword(entry),
        isThreeLine: entry.notes.isNotEmpty,
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
      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword =
          await passwordService.decryptPassword(entry, masterPassword);

      print(
          '🔍 DEBUG: Decryption result: ${decryptedPassword.isNotEmpty ? "SUCCESS" : "FAILED"}');

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
            IconButton(
              onPressed: () async {
                final edited = await _editPassword(entry);
                if (edited) {
                  Navigator.of(context)
                      .pop(); // Close dialog only after successful edit
                }
              },
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit Password',
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () async {
                final deleted = await _deletePassword(entry);
                if (deleted) {
                  Navigator.of(context)
                      .pop(); // Close dialog only after successful deletion
                }
              },
              icon: const Icon(Icons.delete, size: 20),
              tooltip: 'Delete Password',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Details
                if (entry.website.isNotEmpty ||
                    entry.url.isNotEmpty ||
                    entry.category.isNotEmpty) ...[
                  Text(
                    'Service Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (entry.website.isNotEmpty)
                            _buildEnhancedDetailRow(
                              'Website', 
                              entry.website, 
                              Icons.language,
                              Colors.blue,
                            ),
                          if (entry.url.isNotEmpty && entry.url != entry.website)
                            _buildEnhancedDetailRow(
                              'URL', 
                              entry.url, 
                              Icons.link,
                              Colors.teal,
                            ),
                          if (entry.category.isNotEmpty)
                            _buildEnhancedDetailRow(
                              'Category', 
                              entry.category, 
                              Icons.category,
                              Colors.orange,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Account Details
                Text(
                  'Account Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (entry.username.isNotEmpty)
                          _buildEnhancedDetailRow(
                            'Username', 
                            entry.username, 
                            Icons.person,
                            Colors.purple,
                            copyable: true,
                          ),
                      ],
                    ),
                  ),
                ),

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

                // Notes Section (Always visible)
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
                            entry.notes.isNotEmpty
                                ? entry.notes
                                : 'No notes added',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: entry.notes.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color:
                                  entry.notes.isEmpty ? Colors.grey[600] : null,
                            ),
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
                      child: Container(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _clipboardManager.copySecureData(
                              password,
                              context: context,
                              successMessage: 'Password copied securely',
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 48,
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
                          icon: const Icon(Icons.person, size: 18),
                          label: const Text('User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool copyable = false}) {
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
              Container(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: () {
                    _clipboardManager.copyData(
                      value,
                      context: context,
                      successMessage: '$label copied',
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  tooltip: 'Copy $label',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
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
      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword =
          await passwordService.decryptPassword(entry, masterPassword);

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

  void _openInBrowser(PasswordEntry entry) async {
    onUserInteraction();

    // First authenticate to copy password
    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    final authenticated = await _authService.authenticateUser(
      reason: 'Authenticate to copy password and open $displayName in browser',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Get and decrypt password
    final authService = Provider.of<AuthService>(context, listen: false);
    final masterPassword = authService.masterPassword;

    if (masterPassword == null) {
      _showMessage('Master password not available', isError: true);
      return;
    }

    try {
      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword =
          await passwordService.decryptPassword(entry, masterPassword);

      if (decryptedPassword.isEmpty) {
        _showMessage('Failed to decrypt password', isError: true);
        return;
      }

      // Copy password to clipboard
      await _clipboardManager.copySecureData(
        decryptedPassword,
        context: context,
        successMessage: 'Password copied! Opening browser...',
        clearAfterSeconds: 60, // Give more time for login
      );

      // Determine URL to open with improved logic
      String url = entry.url.isNotEmpty ? entry.url : entry.website;

      // Smart URL handling
      url = _buildSmartUrl(url);

      print('🌐 DEBUG: Opening URL: $url');

      // Open in browser
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
        _showMessage(
            'Browser opened! Password is in clipboard for 60 seconds.');
      } else {
        // Fallback: try with different launch modes
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          _showMessage(
              'Browser opened! Password is in clipboard for 60 seconds.');
        } catch (e) {
          _showMessage('Cannot open URL: $url\nError: $e', isError: true);
        }
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    }
  }

  String _buildSmartUrl(String input) {
    if (input.isEmpty) return 'https://google.com';

    String url = input.trim().toLowerCase();

    // If it already has a protocol, return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return input; // Return original case
    }

    // Remove www. if present for processing
    String processUrl = url.replaceFirst('www.', '');

    // If it looks like a domain (contains a dot), use it as is
    if (processUrl.contains('.')) {
      return 'https://$input';
    }

    // If it's just a name/brand, try to make it a .com domain
    // Common patterns: facebook -> facebook.com, google -> google.com
    return 'https://$input.com';
  }

  Future<bool> _editPassword(PasswordEntry entry) async {
    onUserInteraction();

    try {
      // First, decrypt the password to pass to edit screen
      final authService = Provider.of<AuthService>(context, listen: false);
      final masterPassword = authService.masterPassword;

      if (masterPassword == null) {
        _showMessage('Master password not available', isError: true);
        return false;
      }

      final passwordService =
          Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword =
          await passwordService.decryptPassword(entry, masterPassword);

      if (decryptedPassword.isEmpty) {
        _showMessage('Failed to decrypt password', isError: true);
        return false;
      }

      // Navigate to edit screen
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => EditPasswordScreen(
            passwordEntry: entry,
            decryptedPassword: decryptedPassword,
          ),
        ),
      );

      if (result == true) {
        // Refresh search results
        _performSearch();
        return true;
      }

      return false;
    } catch (e) {
      _showMessage('Error: $e', isError: true);
      return false;
    }
  }

  Future<bool> _deletePassword(PasswordEntry entry) async {
    onUserInteraction();

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Password'),
        content: Text(
            'Are you sure you want to delete the password for ${entry.title.isNotEmpty ? entry.title : entry.website}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      // Require authentication for deletion
      final authenticated = await _authService.authenticateUser(
        reason: 'Authenticate to delete password',
      );

      if (!authenticated) {
        _showMessage('Authentication failed', isError: true);
        return false;
      }

      try {
        final passwordService =
            Provider.of<PasswordService>(context, listen: false);
        final success = await passwordService.deletePassword(entry.id);

        if (success) {
          _showMessage('Password deleted successfully');
          // Refresh search results
          _performSearch();
          return true;
        } else {
          _showMessage('Failed to delete password', isError: true);
          return false;
        }
      } catch (e) {
        _showMessage('Error deleting password: $e', isError: true);
        return false;
      }
    }

    return false; // User cancelled
  }

  Widget _buildEnhancedDetailRow(
    String label, 
    String value, 
    IconData icon, 
    Color iconColor, {
    bool copyable = false
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              size: 20, 
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () {
                  _clipboardManager.copyData(
                    value,
                    context: context,
                    successMessage: '$label copied',
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy $label',
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
