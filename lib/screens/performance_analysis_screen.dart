import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:passquarium/services/password_service.dart';
import 'package:passquarium/services/encryption_service.dart';

class PerformanceAnalysisScreen extends StatelessWidget {
  const PerformanceAnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final passwordService = Provider.of<PasswordService>(context);
    final encryptionService = EncryptionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analysis'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Password Loading Performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildMetricCard(
              'Firestore Fetch Time',
              '${passwordService.performanceMetrics['firestore_fetch']} ms',
              Icons.cloud_download,
            ),
            _buildMetricCard(
              'Password Decryption Time',
              '${passwordService.performanceMetrics['password_decryption']} ms',
              Icons.lock_open,
            ),
            _buildMetricCard(
              'Total Load Time',
              '${passwordService.performanceMetrics['total_load_time']} ms',
              Icons.timer,
            ),
            const SizedBox(height: 24),
            const Text(
              'Encryption Service Performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildMetricCard(
              'Average Decryption Time',
              '${encryptionService.getAverageDecryptionTime().toStringAsFixed(2)} ms',
              Icons.lock_open,
            ),
            _buildMetricCard(
              'Average Key Derivation Time',
              '${encryptionService.getAverageKeyDerivationTime().toStringAsFixed(2)} ms',
              Icons.key,
            ),
            const SizedBox(height: 24),
            const Text(
              'Performance Tips',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTipCard(
              'Loading Time',
              'Passwords are loaded in batches of 20 for optimal performance.',
              Icons.info_outline,
            ),
            _buildTipCard(
              'Decryption',
              'Passwords are decrypted in parallel for better performance.',
              Icons.info_outline,
            ),
            _buildTipCard(
              'Cache',
              'Frequently accessed passwords are cached for faster access.',
              Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
} 