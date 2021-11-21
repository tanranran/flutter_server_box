import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/snippet/edit.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({Key? key}) : super(key: key);

  @override
  _SnippetListPageState createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  int _selectedIndex = 0;

  final _textStyle = TextStyle(color: primaryColor);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snippet List'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () =>
            AppRoute(const SnippetEditPage(), 'snippet edit page').go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<SnippetProvider>(
      builder: (_, key, __) {
        return key.snippets.isNotEmpty
            ? ListView.builder(
                padding: const EdgeInsets.all(13),
                itemCount: key.snippets.length,
                itemExtent: 57,
                itemBuilder: (context, idx) {
                  return RoundRectCard(Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key.snippets[idx].name,
                        textAlign: TextAlign.center,
                      ),
                      Row(children: [
                        TextButton(
                            onPressed: () => AppRoute(
                                    SnippetEditPage(snippet: key.snippets[idx]),
                                    'snippet edit page')
                                .go(context),
                            child: Text(
                              'Edit',
                              style: _textStyle,
                            )),
                        TextButton(
                            onPressed: () => _showRunDialog(key.snippets[idx]),
                            child: Text(
                              'Run',
                              style: _textStyle,
                            ))
                      ])
                    ],
                  ));
                })
            : const Center(child: Text('No saved snippets.'));
      },
    );
  }

  void _showRunDialog(Snippet snippet) {
    showRoundDialog(context, 'Choose destination',
        Consumer<ServerProvider>(builder: (_, provider, __) {
      if (provider.servers.isEmpty) {
        return const Text('No server available');
      }
      return SizedBox(
          height: 111,
          child: Stack(children: [
            Positioned(
              child: Container(
                height: 37,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  color: Colors.black12,
                ),
              ),
              top: 36,
              bottom: 36,
              left: 0,
              right: 0,
            ),
            ListWheelScrollView.useDelegate(
              itemExtent: 37,
              diameterRatio: 1.2,
              controller: FixedExtentScrollController(initialItem: 0),
              onSelectedItemChanged: (idx) => _selectedIndex = idx,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) => Center(
                        child: Text(
                          provider.servers[index].info.name,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  childCount: provider.servers.length),
            )
          ]));
    }), [
      TextButton(
          onPressed: () async {
            final result = await locator<ServerProvider>()
                .runSnippet(_selectedIndex, snippet);
            if (result != null) {
              showRoundDialog(context, 'Result', Text(result, style: const TextStyle(fontSize: 13)), [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'))
              ]);
            }
          },
          child: const Text('Run')),
      TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
    ]);
  }
}