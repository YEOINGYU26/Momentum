import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/scheduler_job.dart';

class JobProvider extends ChangeNotifier {
  List<SchedulerJob> _jobs = [];
  bool _loading = false;
  String? _error;

  List<SchedulerJob> get jobs => _jobs;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchJobs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/api/v1/scheduler/jobs');
      final list = data as List;
      _jobs = list.map((e) => SchedulerJob.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addJob({
    required String ticker,
    required String strategyName,
    int? intervalSeconds,
    String? cronExpression,
  }) async {
    final body = <String, dynamic>{
      'ticker': ticker,
      'strategy_name': strategyName,
      'interval_seconds': intervalSeconds,
      'cron_expression': cronExpression,
    }..removeWhere((_, v) => v == null);
    await ApiClient.instance.post('/api/v1/scheduler/jobs', body);
    await fetchJobs();
  }

  Future<void> deleteJob(String jobId) async {
    await ApiClient.instance.delete('/api/v1/scheduler/jobs/$jobId');
    _jobs.removeWhere((j) => j.jobId == jobId);
    notifyListeners();
  }

  Future<void> pauseJob(String jobId) async {
    await ApiClient.instance.postEmpty('/api/v1/scheduler/jobs/$jobId/pause');
    await fetchJobs();
  }

  Future<void> resumeJob(String jobId) async {
    await ApiClient.instance.postEmpty('/api/v1/scheduler/jobs/$jobId/resume');
    await fetchJobs();
  }

  Future<void> runJobNow(String jobId) async {
    await ApiClient.instance.postEmpty('/api/v1/scheduler/jobs/$jobId/run');
  }
}
