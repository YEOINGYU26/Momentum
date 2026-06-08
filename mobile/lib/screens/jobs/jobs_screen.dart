import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/job_provider.dart';
import '../../models/scheduler_job.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
    });
  }

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddJobDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전략 잡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<JobProvider>().fetchJobs(),
          ),
        ],
      ),
      body: Consumer<JobProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return _ErrorView(message: provider.error!, onRetry: provider.fetchJobs);
          }
          if (provider.jobs.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: provider.fetchJobs,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.jobs.length,
              itemBuilder: (_, i) => _JobCard(job: provider.jobs[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final SchedulerJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${job.ticker} · ${job.strategyName}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(job.scheduleLabel, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                _StatusChip(status: job.status),
              ],
            ),
            if (job.nextRunTime != null) ...[
              const SizedBox(height: 8),
              Text('다음 실행: ${job.nextRunTime}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(
                  icon: job.isPaused ? Icons.play_arrow : Icons.pause,
                  label: job.isPaused ? '재개' : '일시정지',
                  onTap: () => job.isPaused
                      ? provider.resumeJob(job.jobId)
                      : provider.pauseJob(job.jobId),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.flash_on,
                  label: '즉시 실행',
                  onTap: () => provider.runJobNow(job.jobId),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, provider, job),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, JobProvider provider, SchedulerJob job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('잡 삭제'),
        content: Text('${job.ticker} · ${job.strategyName} 잡을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteJob(job.jobId);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRunning = status == 'running';
    final color = isRunning ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(isRunning ? '실행 중' : '일시정지', style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class _AddJobDialog extends StatefulWidget {
  const _AddJobDialog();

  @override
  State<_AddJobDialog> createState() => _AddJobDialogState();
}

class _AddJobDialogState extends State<_AddJobDialog> {
  final _tickerCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: '60');
  String _strategy = 'rsi';
  bool _loading = false;

  static const _strategies = ['rsi', 'moving_average', 'scalping'];

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    if (ticker.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<JobProvider>().addJob(
        ticker: ticker,
        strategyName: _strategy,
        intervalSeconds: int.tryParse(_intervalCtrl.text) ?? 60,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('잡 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _tickerCtrl,
            decoration: const InputDecoration(labelText: '종목 코드', hintText: '예: 005930'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _strategy,
            decoration: const InputDecoration(labelText: '전략'),
            items: _strategies
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _strategy = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _intervalCtrl,
            decoration: const InputDecoration(labelText: '실행 간격 (초)', hintText: '60'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('추가'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_mode, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('등록된 전략 잡이 없습니다', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text('+ 버튼으로 자동 매매 잡을 추가하세요', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
