import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/job_provider.dart';
import '../../models/scheduler_job.dart';

class AutoTradeScreen extends StatefulWidget {
  const AutoTradeScreen({super.key});

  @override
  State<AutoTradeScreen> createState() => _AutoTradeScreenState();
}

class _AutoTradeScreenState extends State<AutoTradeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Consumer<JobProvider>(
          builder: (context, provider, _) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text('자동매매',
                          style: TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (!provider.loading) _buildStatusBar(provider),
                      const SizedBox(height: 16),
                      _buildAddButton(context),
                      const SizedBox(height: 24),
                      const Text('실행 중인 전략',
                          style: TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),
                if (provider.loading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                  )
                else if (provider.jobs.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _JobCard(job: provider.jobs[i]),
                        ),
                        childCount: provider.jobs.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusBar(JobProvider provider) {
    final running = provider.jobs.where((j) => !j.isPaused).length;
    final paused  = provider.jobs.where((j) => j.isPaused).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _StatusStat(label: '실행 중', value: '$running개', color: AppColors.green),
          _StatusStat(label: '일시정지', value: '$paused개', color: AppColors.gray),
          _StatusStat(label: '총 전략', value: '${provider.jobs.length}개', color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => const _AddJobDialog()),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
        child: const Center(
          child: Text('+ 새 전략 추가',
              style: TextStyle(
                  color: AppColors.bg, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatusStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
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
    final statusColor = job.isPaused ? AppColors.gray : AppColors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.strategyName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${job.ticker} · ${job.scheduleLabel}',
                        style: const TextStyle(color: AppColors.gray, fontSize: 11)),
                  ],
                ),
              ),
              _StatusBadge(isPaused: job.isPaused),
            ],
          ),
          if (job.nextRunTime != null) ...[
            const SizedBox(height: 8),
            Text('다음 실행: ${job.nextRunTime}',
                style: const TextStyle(color: AppColors.gray, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _SmallButton(
                icon: job.isPaused ? Icons.play_arrow : Icons.pause,
                label: job.isPaused ? '재개' : '일시정지',
                color: statusColor,
                onTap: () => job.isPaused
                    ? provider.resumeJob(job.jobId)
                    : provider.pauseJob(job.jobId),
              ),
              const SizedBox(width: 8),
              _SmallButton(
                icon: Icons.flash_on,
                label: '즉시 실행',
                color: AppColors.yellow,
                onTap: () => provider.runJobNow(job.jobId),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context, provider, job),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, JobProvider provider, SchedulerJob job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('전략 삭제', style: TextStyle(color: Colors.white)),
        content: Text('${job.ticker} · ${job.strategyName} 전략을 삭제할까요?',
            style: const TextStyle(color: AppColors.gray)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: AppColors.gray))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteJob(job.jobId);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isPaused;
  const _StatusBadge({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final color = isPaused ? AppColors.gray : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isPaused ? '일시정지' : '실행 중',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_mode, size: 36, color: AppColors.green),
          ),
          const SizedBox(height: 16),
          const Text('등록된 전략이 없습니다',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('+ 새 전략 추가 버튼으로 시작하세요',
              style: TextStyle(color: AppColors.gray, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Add Job Dialog ───────────────────────────────────────────────────────────

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
  static const _strategyLabels = {'rsi': 'RSI', 'moving_average': 'MA 골든크로스', 'scalping': '볼린저 밴드'};

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
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text('새 전략 추가', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _tickerCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '종목 코드',
              labelStyle: TextStyle(color: AppColors.gray),
              hintText: '예: 005930',
              hintStyle: TextStyle(color: AppColors.gray),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _strategy,
            dropdownColor: AppColors.card,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '전략',
              labelStyle: TextStyle(color: AppColors.gray),
            ),
            items: _strategies
                .map((s) => DropdownMenuItem(
                    value: s, child: Text(_strategyLabels[s] ?? s)))
                .toList(),
            onChanged: (v) => setState(() => _strategy = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _intervalCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '실행 간격 (초)',
              labelStyle: TextStyle(color: AppColors.gray),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.gray))),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: AppColors.bg),
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('추가'),
        ),
      ],
    );
  }
}
