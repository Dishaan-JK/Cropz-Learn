import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/lumi_api.dart';

String _size(Object? bytes) => bytes is num
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB'
    : 'Unavailable';

String _value(Object? value) =>
    value == null || value.toString().isEmpty ? 'Unavailable' : '$value';

class HardwareReport extends StatefulWidget {
  const HardwareReport({required this.api, super.key});
  final LumiApi api;

  @override
  State<HardwareReport> createState() => _HardwareReportState();
}

class _HardwareReportState extends State<HardwareReport> {
  Map<String, dynamic>? _report;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.api.localModels('hardware');
      if (mounted) setState(() => _report = value);
    } on Object {
      if (mounted) {
        setState(() => _error =
            'Could not read the backend computer. Check that Lumi’s backend is running.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null && _loading) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()));
    }
    if (report == null) {
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error ?? 'Hardware details are unavailable.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: _loading ? null : _refresh,
                        icon: const Icon(LucideIcons.refreshCw, size: 17),
                        label: const Text('Refresh report')),
                  ])));
    }

    final cpu = report['cpu'] as Map? ?? const {};
    final memory = report['memory'] as Map? ?? const {};
    final effectiveRam = (memory['containerLimitBytes'] as num?) ??
        (memory['totalBytes'] as num?) ??
        0;
    final ramAvailable = (memory['availableBytes'] as num?) ?? 0;
    final storage = report['storage'] as Map? ?? const {};
    final ollama = report['ollama'] as Map? ?? const {};
    final gpus = (report['gpus'] as List? ?? const []).whereType<Map>();
    final running =
        (ollama['runningModels'] as List? ?? const []).whereType<Map>();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Computer overview',
                              style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                          tooltip: 'Refresh report',
                          onPressed: _loading ? null : _refresh,
                          icon: const Icon(LucideIcons.refreshCw, size: 18)),
                    ]),
                    if (report['supported'] == false)
                      Text(_value(report['reason']))
                    else ...[
                      _DetailRows(rows: {
                        'Processor': _value(cpu['name']),
                        'CPU vendor': _value(cpu['vendor']),
                        'Logical threads': _value(cpu['threads']),
                        'Current CPU load': cpu['usagePercent'] == null
                            ? 'Unavailable'
                            : '${cpu['usagePercent']}%',
                        'Physical RAM': _size(memory['physicalTotalBytes']),
                        'RAM available to backend': _size(memory['totalBytes']),
                        'RAM available now': _size(memory['availableBytes']),
                        'Estimated RAM in use':
                            _size(effectiveRam - ramAvailable),
                        'Container memory limit':
                            memory['containerLimitBytes'] is num
                                ? _size(memory['containerLimitBytes'])
                                : 'No separate limit detected',
                      }),
                    ],
                  ]))),
      const SizedBox(height: 12),
      _ReportCard(
          title: 'Graphics devices',
          icon: LucideIcons.monitor,
          child: gpus.isEmpty
              ? const Text('No graphics devices were detected.')
              : Column(children: [
                  for (final (index, gpu) in gpus.indexed)
                    Padding(
                        padding: EdgeInsets.only(
                            bottom: index == gpus.length - 1 ? 0 : 18),
                        child: _DetailRows(rows: {
                          'Device': _value(gpu['name']),
                          'Vendor': _value(gpu['vendor']),
                          'PCI device ID': _value(gpu['id']),
                          'Driver': _value(
                              gpu['driver'] ?? gpu['driverVersion']),
                          'Memory type': _value(gpu['memoryType']),
                          'Total graphics memory': gpu['memoryType'] == 'shared'
                              ? 'Shared system RAM'
                              : _size(gpu['totalBytes']),
                          'Available graphics memory':
                              gpu['memoryType'] == 'shared'
                                  ? 'Shared with system RAM'
                                  : _size(gpu['availableBytes']),
                          'Current graphics load': gpu['usagePercent'] == null
                              ? 'Unavailable'
                              : '${gpu['usagePercent']}%',
                          'Ollama acceleration':
                              gpu['runtimeVerified'] == true
                                  ? 'Verified'
                                  : 'Not yet verified',
                          'Detection note': _value(gpu['note']),
                        })),
                ])),
      const SizedBox(height: 12),
      _ReportCard(
          title: 'Model storage',
          icon: LucideIcons.hardDrive,
          child: _DetailRows(rows: {
            'Free space': _size(storage['availableBytes']),
            'Status': _value(storage['note']),
          })),
      const SizedBox(height: 12),
      _ReportCard(
          title: 'Ollama runtime',
          icon: LucideIcons.server,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _DetailRows(rows: {
              'Status':
                  ollama['available'] == true ? 'Connected' : 'Not available',
              'Version': _value(ollama['version']),
            }),
            const SizedBox(height: 12),
            Text('Models currently in memory',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (running.isEmpty)
              const Text('No models are currently loaded.')
            else
              for (final model in running)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _DetailRows(rows: {
                      'Model': _value(model['name']),
                      'Total allocation': _size(model['allocatedBytes']),
                      'GPU allocation': _size(model['gpuAllocatedBytes']),
                      'Context length': _value(model['context']),
                    })),
          ])),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    ]);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 9),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 14),
            child,
          ])));
}

class _DetailRows extends StatelessWidget {
  const _DetailRows({required this.rows});
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      for (final (index, row) in rows.entries.indexed)
        Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                border: index == 0
                    ? null
                    : Border(top: BorderSide(color: theme.dividerColor))),
            child: LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 480;
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.key,
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 3),
                        SelectableText(row.value,
                            style: theme.textTheme.bodyMedium),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          SizedBox(
                              width: 230,
                              child: Text(row.key,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant))),
                          Expanded(
                              child: SelectableText(row.value,
                                  style: theme.textTheme.bodyMedium)),
                        ]);
            })),
    ]);
  }
}
