import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';
import 'package:super_locker/services/clipboard_manager.dart';
import 'package:super_locker/services/auto_lock_service.dart';
import 'package:super_locker/widgets/password_strength_indicator.dart';
import 'package:super_locker/models/password_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ClipboardManager _clipboardManager = ClipboardManager();
  late AutoLockService _autoLockService;
  List<PasswordEntry> _filteredPasswords = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _autoLockService = AutoLockService();
    _searchController.addListener(_onSearchChanged);
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPasswords();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void onUserInteraction() {
    _autoLockService.onUserActivity();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    final passwordService = Provider.of<PasswordService>(context, listen: false);
    
    if (query.isEmpty) {
      setState(() {
        _filteredPasswords = passwordService.passwords;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
        _filteredPasswords = passwordService.passwords.where((password) {
          return password.website.toLowerCase().contains(query) ||
                 password.domain.toLowerCase().contains(query) ||
                 password.username.toLowerCase().contains(query) ||
                 password.title.toLowerCase().contains(query) ||
                 password.category.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadPasswords() async {
    final passwordService =
        Provider.of<PasswordService>(context, listen: false);
    await passwordService.loadPasswords();
    // Initialize filtered passwords
    setState(() {
      _filteredPasswords = passwordService.passwords;
    });
  }

  void _lockApp() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.lock();
    Navigator.of(context).pushReplacementNamed('/device-auth');
  }

  void _showSettingsMenu() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userInfo = authService.getUserInfo();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Info Section
            if (userInfo != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${userInfo['email'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          userInfo['emailVerified'] == true
                              ? Icons.verified
                              : Icons.warning,
                          size: 16,
                          color: userInfo['emailVerified'] == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userInfo['emailVerified'] == true
                              ? 'Email Verified'
                              : 'Email Not Verified',
                          style: TextStyle(
                            fontSize: 12,
                            color: userInfo['emailVerified'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Menu Options
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Lock App'),
              onTap: () {
                Navigator.pop(context);
                _lockApp();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            if (userInfo != null && userInfo['emailVerified'] == false) ...[
              ListTile(
                leading: const Icon(Icons.mark_email_unread),
                title: const Text('Verify Email'),
                onTap: () {
                  Navigator.pop(context);
                  _sendVerificationEmail();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _showSignOutDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_account),
              title: const Text('Switch Account'),
              onTap: () {
                Navigator.pop(context);
                _showSwitchAccountDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            const Text('Quick Logout'),
          ],
        ),
        content: const Text(
            'Are you sure you want to logout? You will need to authenticate again to access your passwords.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first

              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final passwordService =
                  Provider.of<PasswordService>(context, listen: false);

              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Logging out...'),
                      ],
                    ),
                  ),
                );

                await authService.signOut();
                passwordService.clearLocalData();

                if (mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out? This will clear all locally stored data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final passwordService =
                  Provider.of<PasswordService>(context, listen: false);

              await authService.signOut();
              passwordService.clearLocalData();

              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showSwitchAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Account'),
        content: const Text(
            'This will sign you out and allow you to sign in with a different account. Your current data will be cleared from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final passwordService =
                  Provider.of<PasswordService>(context, listen: false);

              await authService.signOut();
              passwordService.clearLocalData();

              if (mounted) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pushReplacementNamed('/email-auth');
              }
            },
            child: const Text('Switch Account'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: !isCurrentPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isCurrentPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          isCurrentPasswordVisible = !isCurrentPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: !isNewPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(isNewPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          isNewPasswordVisible = !isNewPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('New passwords do not match')),
                        );
                        return;
                      }

                      if (newPasswordController.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Password must be at least 8 characters long')),
                        );
                        return;
                      }

                      setState(() {
                        isLoading = true;
                      });

                      try {
                        final authService =
                            Provider.of<AuthService>(context, listen: false);
                        await authService.changePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password changed successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendVerificationEmail() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Verification email sent! Please check your inbox.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Locker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _showQuickLogoutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Settings',
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<PasswordService>(
                      builder: (context, passwordService, child) {
                        final count = passwordService.passwords.length;
                        return Text(
                          'You have $count password${count == 1 ? '' : 's'} stored securely',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_rounded,
                      title: 'Add Password',
                      subtitle: 'Store a new password',
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).pushNamed('/add-password');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.security,
                      title: 'Security Center',
                      subtitle: 'Check password strength',
                      color: Colors.blue,
                      onTap: () {
                        _showSecurityCenter();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Second Row of Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.auto_awesome,
                      title: 'Password Generator',
                      subtitle: 'Create secure passwords',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.of(context).pushNamed('/password-generator');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(), // Empty space for symmetry
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Recent Passwords with Search
              Row(
                children: [
                  const Text(
                    'Your Passwords',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filteredPasswords.length} found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search passwords...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                onChanged: (value) {
                  // Trigger rebuild to show/hide clear button
                  setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // Password List (Fixed Height)
              SizedBox(
                height: 400, // Fixed height to avoid layout issues
                child: Consumer<PasswordService>(
                  builder: (context, passwordService, child) {
                    if (passwordService.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (passwordService.error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading passwords',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              passwordService.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPasswords,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_filteredPasswords.isEmpty && passwordService.passwords.isNotEmpty) {
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
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (_filteredPasswords.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No passwords stored yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Add Password" to get started',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _filteredPasswords.length,
                      itemBuilder: (context, index) {
                        final password = _filteredPasswords[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              child: Text(
                                password.domain.isNotEmpty
                                    ? password.domain[0].toUpperCase()
                                    : (password.website.isNotEmpty ? password.website[0].toUpperCase() : 'P'),
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              password.title.isNotEmpty ? password.title : password.website,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              password.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () => _copyPassword(password),
                                  tooltip: 'Copy Password',
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                            onTap: () => _viewPassword(password),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecurityCenter() {
    // Show a simple security overview dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Security Center'),
          ],
        ),
        content: Consumer<PasswordService>(
          builder: (context, passwordService, child) {
            final passwords = passwordService.passwords;
            final weakPasswords = passwords.where((p) => p.encryptedPassword.length < 50).length; // Rough estimate
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecurityItem(
                  'Total Passwords', 
                  '${passwords.length}', 
                  Icons.lock_outline,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildSecurityItem(
                  'Potentially Weak', 
                  '$weakPasswords', 
                  Icons.warning,
                  weakPasswords > 0 ? Colors.orange : Colors.green,
                ),
                const SizedBox(height: 12),
                _buildSecurityItem(
                  'Security Score', 
                  '${((passwords.length - weakPasswords) / (passwords.length > 0 ? passwords.length : 1) * 100).round()}%', 
                  Icons.shield,
                  Colors.green,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _viewPassword(PasswordEntry entry) async {
    onUserInteraction();

    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    
    // Require biometric authentication
    final authService = Provider.of<AuthService>(context, listen: false);
    final authenticated = await authService.authenticateUser(
      reason: 'Authenticate to view password for $displayName',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Get master password and decrypt
    final masterPassword = authService.masterPassword;

    if (masterPassword == null) {
      _showMessage('Master password not available', isError: true);
      return;
    }

    try {
      final passwordService = Provider.of<PasswordService>(context, listen: false);
      final decryptedPassword = await passwordService.decryptPassword(entry, masterPassword);

      if (decryptedPassword.isNotEmpty) {
        _showPasswordDialog(entry, decryptedPassword);
      } else {
        _showMessage('Failed to decrypt password', isError: true);
      }
    } catch (e) {
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
                // Service Details
                if (entry.website.isNotEmpty || entry.url.isNotEmpty || entry.category.isNotEmpty) ...[
                  Text(
                    'Service Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (entry.website.isNotEmpty)
                    _buildDetailRow('Website', entry.website, Icons.language),
                  if (entry.url.isNotEmpty && entry.url != entry.website)
                    _buildDetailRow('URL', entry.url, Icons.link),
                  if (entry.category.isNotEmpty)
                    _buildDetailRow('Category', entry.category, Icons.category),
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
                const SizedBox(height: 8),
                if (entry.username.isNotEmpty)
                  _buildDetailRow('Username', entry.username, Icons.person, copyable: true),
                
                const SizedBox(height: 16),
                
                // Password Section
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
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
                
                const SizedBox(height: 16),
                
                // Notes Section
                if (entry.notes.isNotEmpty) ...[
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: SelectableText(entry.notes),
                  ),
                  const SizedBox(height: 16),
                ],
                
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

  void _copyPassword(PasswordEntry entry) async {
    onUserInteraction();

    // Require biometric authentication
    final displayName = entry.title.isNotEmpty ? entry.title : entry.website;
    final authService = Provider.of<AuthService>(context, listen: false);
    final authenticated = await authService.authenticateUser(
      reason: 'Authenticate to copy password for $displayName',
    );

    if (!authenticated) {
      _showMessage('Authentication failed', isError: true);
      return;
    }

    // Decrypt and copy password
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
