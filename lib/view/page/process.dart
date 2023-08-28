import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils/misc.dart';

import '../../core/utils/ui.dart';
import '../../data/model/app/shell_func.dart';
import '../../data/model/server/proc.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/provider/server.dart';
import '../../data/res/ui.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/custom_appbar.dart';
import '../widget/round_rect_card.dart';
import '../widget/two_line_text.dart';

class ProcessPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const ProcessPage({super.key, required this.spi});

  @override
  _ProcessPageState createState() => _ProcessPageState();
}

class _ProcessPageState extends State<ProcessPage> {
  late S _s;
  late Timer _timer;
  late MediaQueryData _media;

  final _setting = locator<SettingStore>();

  SSHClient? _client;

  PsResult _result = PsResult(procs: []);
  int? _lastFocusId;

  // Issue #64
  // In cpu mode, the process list will change in a high frequency.
  // So user will easily know that the list is refreshed.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  List<ProcSortMode> _sortModes = List.from(ProcSortMode.values);

  final _serverProvider = locator<ServerProvider>();

  @override
  void initState() {
    super.initState();
    _client = _serverProvider.servers[widget.spi.id]?.client;
    final duration =
        Duration(seconds: _setting.serverStatusUpdateInterval.fetch());
    _timer = Timer.periodic(duration, (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
    _media = MediaQuery.of(context);
  }

  Future<void> _refresh() async {
    if (mounted) {
      final result = await _client?.run(AppShellFuncType.process.exec).string;
      if (result == null || result.isEmpty) {
        showSnackBar(context, Text(_s.noResult));
        return;
      }
      _result = PsResult.parse(result, sort: _procSortMode);

      // If there are any [Proc]'s data is not complete,
      // the option to sort by cpu/mem will not be available.
      final isAnyProcDataNotComplete =
          _result.procs.any((e) => e.cpu == null || e.mem == null);
      if (isAnyProcDataNotComplete) {
        _sortModes.removeWhere((e) => e == ProcSortMode.cpu);
        _sortModes.removeWhere((e) => e == ProcSortMode.mem);
      } else {
        _sortModes = ProcSortMode.values;
      }
      setState(() {});
    } else {
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      PopupMenuButton<ProcSortMode>(
        onSelected: (value) {
          setState(() {
            _procSortMode = value;
          });
        },
        icon: const Icon(Icons.sort),
        initialValue: _procSortMode,
        itemBuilder: (_) => _sortModes
            .map((e) => PopupMenuItem(value: e, child: Text(e.name)))
            .toList(),
      ),
    ];
    if (_result.error != null) {
      actions.add(IconButton(
        icon: const Icon(Icons.error),
        onPressed: () => showRoundDialog(
          context: context,
          title: Text(_s.error),
          child: SingleChildScrollView(child: Text(_result.error!)),
          actions: [
            TextButton(
              onPressed: () => copy2Clipboard(_result.error!),
              child: Text(_s.copy),
            ),
          ],
        ),
      ));
    }
    Widget child;
    if (_result.procs.isEmpty) {
      child = centerLoading;
    } else {
      child = ListView.builder(
        itemCount: _result.procs.length,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
        itemBuilder: (_, idx) => _buildListItem(_result.procs[idx]),
      );
    }
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: widget.spi.name, down: _s.process),
        actions: actions,
      ),
      body: child,
    );
  }

  Widget _buildListItem(Proc proc) {
    final leading = proc.user == null
        ? Text(proc.pid.toString())
        : TwoLineText(up: proc.pid.toString(), down: proc.user!);
    return RoundRectCard(
      ListTile(
        leading: SizedBox(
          width: _media.size.width / 6,
          child: leading,
        ),
        title: Text(proc.binary),
        subtitle: Text(
          proc.command,
          style: grey,
          maxLines: 3,
          overflow: TextOverflow.fade,
        ),
        trailing: _buildItemTrail(proc),
        onTap: () => _lastFocusId = proc.pid,
        onLongPress: () {
          showRoundDialog(
            context: context,
            title: Text(_s.attention),
            child: Text(_s.sureStop(proc.pid)),
            actions: [
              TextButton(
                onPressed: () async {
                  await _client?.run('kill ${proc.pid}');
                  await _refresh();
                  context.pop();
                },
                child: Text(_s.ok),
              ),
            ],
          );
        },
        selected: _lastFocusId == proc.pid,
        autofocus: _lastFocusId == proc.pid,
      ),
      key: ValueKey(proc.pid),
    );
  }

  Widget? _buildItemTrail(Proc proc) {
    if (proc.cpu == null && proc.mem == null) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (proc.cpu != null)
          TwoLineText(
            up: proc.cpu!.toStringAsFixed(1),
            down: 'cpu',
          ),
        width13,
        if (proc.mem != null)
          TwoLineText(
            up: proc.mem!.toStringAsFixed(1),
            down: 'mem',
          ),
      ],
    );
  }
}
