import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:filetagger/DataStructures/datas.dart';
import 'package:filetagger/DataStructures/db_manager.dart';
import 'package:filetagger/DataStructures/directory_reader.dart';
import 'package:filetagger/DataStructures/path_manager.dart';
import 'package:filetagger/Widgets/list_widget.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ko'),
        Locale('en'),
      ],
      locale: Locale('ko'),
      title: '',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyMainWidget(),
    );
  }
}

class MyMainWidget extends StatefulWidget {
  const MyMainWidget({
    super.key,
  });

  @override
  State<MyMainWidget> createState() => _MyMainWidgetState();
}

enum ViewType { list, icon }

class _MyMainWidgetState extends State<MyMainWidget> {
  String? appTitle;
  ViewType viewType = ViewType.list;
  Map<String, PathData> pathData = {};
  Map<int, TagInfoData> tagData = {};
  Set<String> trackingPath = {};
  bool isSingleSelect = true;
  Set<int> selectedIndices = {};

  /// 트래킹할 root path를 가져오는 메소드. 첫 디렉토리 로드에 사용
  void _loadItems(String rootPath) async {
    PathManager().setRootPath(rootPath);
    selectedIndices.clear();
    pathData.clear();
    tagData.clear();
    trackingPath.clear();
    DirectoryReader().close();
    await DBManager().closeDatabase();

    final paths = await DBManager().initializeDatabase(rootPath);
    setState(() {
      paths.forEach((key, value) {
        pathData[key] = PathData(
          path: key,
          pid: value,
        );
      });
    });
    tagData = await DBManager().getTagsInfo() ?? {};

    final fileList = await DirectoryReader().readDirectory(rootPath);

    for (var entity in fileList) {
      final path = PathManager().getPath(entity.path);
      if (path == DBManager.dbMgrFileName) {
        //관리용 파일은 추가하지 않음
        continue;
      }
      setState(() {
        trackingPath.add(path);
      });
      if (!pathData.containsKey(path)) {
        final pid = await DBManager().addFile(path);
        if (pid != null) {
          setState(() {
            pathData[path] = PathData(
              path: path,
              pid: pid,
            );
          });
        } //추가 실패하면 이미 존재한다는 의미.
      }
      final tags = await DBManager().getTagsFromFile(pid);
      for (var (id: tid, type: _, value: value) in tags) {
        setState(() {
          pathData[path]!.tags.add(TagData(
                pid: pid,
                tid: tid,
                value: value,
              )); //태그 추가
        });
      }
    }
  }

  void _selectItem(int index) {
    setState(() {
      if (isSingleSelect) {
        selectedIndices.clear();
        selectedIndices.add(index);
      } else {
        if (selectedIndices.contains(index)) {
          selectedIndices.remove(index);
        } else {
          selectedIndices.add(index);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appTitle ?? AppLocalizations.of(context)!.appTitle),
        centerTitle: true,
        leading: Tooltip(
          message: '',
          child: IconButton(
            onPressed: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path != null) {
                _loadItems(path);
                setState(() {
                  appTitle = path;
                });
              }
            },
            icon: Icon(Icons.file_copy),
          ),
        ),
      ),
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved1(
                color: Colors.indigo[100]!,
                highlightedColor: Colors.indigo[400]!)),
        child: MultiSplitView(
          initialAreas: [
            Area(builder: (context, area) => Draft.blue()),
            Area(
              builder: (context, area) {
                switch (viewType) {
                  case ViewType.list:
                    return ListWidget(
                      pathData: pathData,
                      tagData: tagData,
                      trackingPath: trackingPath,
                      selectedIndices: selectedIndices,
                      onTap: _selectItem,
                    );
                  case ViewType.icon:
                    return ListWidget(
                      pathData: pathData,
                      tagData: tagData,
                      trackingPath: trackingPath,
                      selectedIndices: selectedIndices,
                      onTap: _selectItem,
                    ); //TODO : GridWidget으로 바꾸기
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
