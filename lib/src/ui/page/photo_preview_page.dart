import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo/src/entity/options.dart';
import 'package:photo/src/provider/config_provider.dart';
import 'package:photo/src/provider/selected_provider.dart';
import 'package:photo/src/ui/page/photo_main_page.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoPreviewPage extends StatefulWidget {
  final SelectedProvider selectedProvider;

  final List<ImageEntity> list;

  final int initIndex;

  /// 这个参数是控制在内部点击check后是否实时修改provider状态
  final bool changeProviderOnCheckChange;

  /// 这里封装了结果
  final PhotoPreviewResult result;

  const PhotoPreviewPage({
    Key key,
    @required this.selectedProvider,
    @required this.list,
    @required this.changeProviderOnCheckChange,
    @required this.result,
    this.initIndex = 0,
  }) : super(key: key);

  @override
  _PhotoPreviewPageState createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  ConfigProvider get config => ConfigProvider.of(context);

  Options get options => config.options;

  Color get themeColor => options.themeColor;

  Color get textColor => options.textColor;

  SelectedProvider get selectedProvider => widget.selectedProvider;

  List<ImageEntity> get list => widget.list;

  StreamController<int> pageChangeController = StreamController.broadcast();

  Stream<int> get pageStream => pageChangeController.stream;

  bool get changeProviderOnCheckChange => widget.changeProviderOnCheckChange;

  PhotoPreviewResult get result => widget.result;

  /// 缩略图用的数据
  ///
  /// 用于与provider数据联动
  List<ImageEntity> get previewList {
    return selectedProvider.selectedList;
  }

  /// 选中的数据
  List<ImageEntity> _selectedList = [];

  List<ImageEntity> get selectedList {
    if (changeProviderOnCheckChange) {
      return previewList;
    }
    return _selectedList;
  }

  PageController pageController;

  @override
  void initState() {
    super.initState();
    pageChangeController.add(0);
    pageController = PageController(
      initialPage: widget.initIndex,
    );

    _selectedList.clear();
    _selectedList.addAll(selectedProvider.selectedList);

    result.previewSelectedList = _selectedList;
  }

  @override
  void dispose() {
    pageChangeController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      color: options.textColor,
      fontSize: 14.0,
    );
    return Theme(
      data: Theme.of(context).copyWith(primaryColor: options.themeColor),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: config.options.themeColor,
          title: StreamBuilder(
            stream: pageStream,
            initialData: widget.initIndex,
            builder: (ctx, snap) => Text(
                  "${snap.data + 1}/${widget.list.length}",
                ),
          ),
          actions: <Widget>[
            StreamBuilder(
              stream: pageStream,
              builder: (ctx, s) => FlatButton(
                splashColor: Colors.transparent,
                onPressed: selectedList.length == 0 ? null : sure,
                child: Text(
                      config.provider.getSureText(options, selectedList.length),
                      style: selectedList.length == 0
                          ? textStyle.copyWith(color: options.disableColor)
                          : textStyle,
                    ),
              ),
            ),
          ],
        ),
        body: PageView.builder(
          controller: pageController,
          itemBuilder: _buildItem,
          itemCount: list.length,
          onPageChanged: _onPageChanged,
        ),
        bottomNavigationBar: _buildBottom(),
        bottomSheet: _buildThumb(),
      ),
    );
  }

  Widget _buildBottom() {
    return Container(
      color: themeColor,
      child: SafeArea(
        child: Container(
          height: 52.0,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(),
              ),
              _buildCheckbox(),
            ],
          ),
        ),
      ),
    );
  }

  Container _buildCheckbox() {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 150.0,
      ),
      child: StreamBuilder<int>(
        builder: (ctx, snapshot) {
          var index = snapshot.data;
          var data = list[index];
          return CheckboxListTile(
            value: selectedList.contains(data),
            onChanged: (bool check) {
              if (changeProviderOnCheckChange) {
                _onChangeProvider(check, index);
              } else {
                _onCheckInOnlyPreview(check, index);
              }
            },
            activeColor: Color.lerp(textColor, themeColor, 0.6),
            title: Text(
              config.provider.getSelectedOptionsText(options),
              textAlign: TextAlign.end,
              style: TextStyle(color: options.textColor),
            ),
          );
        },
        initialData: widget.initIndex,
        stream: pageStream,
      ),
    );
  }

  /// 仅仅修改预览时的状态,在退出时,再更新provider的顺序,这里无论添加与否不修改顺序
  void _onCheckInOnlyPreview(bool check, int index) {
    var item = list[index];
    if (check) {
      selectedList.add(item);
    } else {
      selectedList.remove(item);
    }
    pageChangeController.add(index);
  }

  /// 直接修改预览状态,会直接移除item
  void _onChangeProvider(bool check, int index) {
    var item = list[index];
    if (check) {
      selectedProvider.addSelectEntity(item);
    } else {
      selectedProvider.removeSelectEntity(item);
    }
    pageChangeController.add(index);
  }

  Widget _buildItem(BuildContext context, int index) {
    var data = list[index];
    return BigPhotoImage(
      imageEntity: data,
    );
  }

  void _onPageChanged(int value) {
    pageChangeController.add(value);
  }

  Widget _buildThumb() {
    return StreamBuilder(
      builder: (ctx, snapshot) => Container(
            height: 80.0,
            child: ListView.builder(
              itemBuilder: _buildThumbItem,
              itemCount: previewList.length,
              scrollDirection: Axis.horizontal,
            ),
          ),
      stream: pageStream,
    );
  }

  Widget _buildThumbItem(BuildContext context, int index) {
    var item = previewList[index];
    return GestureDetector(
      onTap: () => changeSelected(item, index),
      child: Container(
        width: 80.0,
        child: Stack(
          children: <Widget>[
            ImageItem(
              themeColor: themeColor,
              entity: item,
            ),
            IgnorePointer(
              child: StreamBuilder(
                stream: pageStream,
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (selectedList.contains(item)) {
                    return Container();
                  }
                  return Container(
                    color: Colors.white.withOpacity(0.5),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void changeSelected(ImageEntity entity, int index) {
    var itemIndex = list.indexOf(entity);
    if (itemIndex != -1) pageController.jumpToPage(itemIndex);
  }

  void sure() {
    Navigator.pop(context, selectedList);
  }
}

class BigPhotoImage extends StatefulWidget {
  final ImageEntity imageEntity;

  const BigPhotoImage({Key key, this.imageEntity}) : super(key: key);

  @override
  _BigPhotoImageState createState() => _BigPhotoImageState();
}

class _BigPhotoImageState extends State<BigPhotoImage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return FutureBuilder(
      future:
          widget.imageEntity.thumbDataWithSize(width.floor(), height.floor()),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        var file = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done && file != null) {
          print(file.length);
          return Image.memory(
            file,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return Container();
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class PhotoPreviewResult {
  List<ImageEntity> previewSelectedList = [];
}