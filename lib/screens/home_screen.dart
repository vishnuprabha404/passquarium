import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_locker/services/auth_service.dart';
import 'package:super_locker/services/password_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPasswords();
    });
  }

  Future<void> _loadPasswords() async {
    final passwordService = Provider.of<PasswordService>(context, listen: false);
    await passwordService.loadPasswords();
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

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? This will clear all locally stored data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final passwordService = Provider.of<PasswordService>(context, listen: false);
              
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
        content: const Text('This will sign you out and allow you to sign in with a different account. Your current data will be cleared from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final passwordService = Provider.of<PasswordService>(context, listen: false);
              
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
                      icon: Icon(isCurrentPasswordVisible ? Icons.visibility_off : Icons.visibility),
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
                      icon: Icon(isNewPasswordVisible ? Icons.visibility_off : Icons.visibility),
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
                      icon: Icon(isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
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
              onPressed: isLoading ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match')),
                  );
                  return;
                }

                if (newPasswordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 8 characters long')),
                  );
                  return;
                }

                setState(() {
                  isLoading = true;
                });

                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully')),
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
          const SnackBar(content: Text('Verification email sent! Please check your inbox.')),
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
            icon: const Icon(Icons.more_vert),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
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
                      icon: Icons.search_rounded,
                      title: 'Search Passwords',
                      subtitle: 'Find your passwords',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).pushNamed('/search-password');
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Recent Passwords
              const Text(
                'Recent Passwords',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
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

                    final passwords = passwordService.passwords.take(5).toList();
                    
                    if (passwords.isEmpty) {
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
                      itemCount: passwords.length,
                      itemBuilder: (context, index) {
                        final password = passwords[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              child: Text(
                                password.domain.isNotEmpty 
                                    ? password.domain[0].toUpperCase()
                                    : 'P',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              password.website.isNotEmpty 
                                  ? password.website 
                                  : password.domain,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              password.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // TODO: Navigate to password detail/edit
                            },
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