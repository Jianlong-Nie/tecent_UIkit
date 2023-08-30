// ignore_for_file: prefer_typing_uninitialized_variables,  unused_import

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/video_screen.dart';
import 'package:tencent_open_file/tencent_open_file.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/tim_uikit_message_reaction_wrapper.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_screen.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_swiper_plus/flutter_swiper_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

class TIMUIKitMediaPreview extends StatefulWidget {
  final V2TimMessage message;
  final String conId;

  const TIMUIKitMediaPreview({
    required this.message,
    required this.conId,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TIMUIKitMediaPreviewState();
}

class _TIMUIKitMediaPreviewState extends TIMUIKitState<TIMUIKitMediaPreview> {
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  double? networkImagePositionRadio; // 加这个字段用于异步获取被安全打击后的兜底图的比例
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  String getBigPicUrl(V2TimMessage message) {
    // 实际拿的是原图
    V2TimImage? img = MessageUtils.getImageFromImgList(
        message.imageElem!.imageList, HistoryMessageDartConstant.oriImgPrior);
    return img == null ? message.imageElem!.path! : img.url!;
  }

  Widget getImage(image, {imageElem}) {
    Widget res = ClipRRect(
      clipper: ImageClipper(),
      child: image,
    );

    return res;
  }

  //保存网络图片到本地
  Future<void> _saveImageToLocal(context, V2TimMessage message, String imageUrl,
      {bool isAsset = true, TUITheme? theme, bool needShare = false}) async {
    if (PlatformUtils().isWeb) {
      download(imageUrl) async {
        final http.Response r = await http.get(Uri.parse(imageUrl));
        final data = r.bodyBytes;
        final base64data = base64Encode(data);
        final a =
            html.AnchorElement(href: 'data:image/jpeg;base64,$base64data');
        a.download = md5.convert(utf8.encode(imageUrl)).toString();
        a.click();
        a.remove();
      }

      download(imageUrl);
      return;
    }

    if (PlatformUtils().isIOS) {
      if (!await Permissions.checkPermission(
          context, Permission.photosAddOnly.value, theme!, false)) {
        return;
      }
    } else {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (PlatformUtils().isMobile) {
        if ((androidInfo.version.sdkInt) >= 33) {
          final photos = await Permissions.checkPermission(
            context,
            Permission.photos.value,
            theme,
          );
          if (!photos) {
            return;
          }
        } else {
          final storage = await Permissions.checkPermission(
            context,
            Permission.storage.value,
          );
          if (!storage) {
            return;
          }
        }
      }
    }

    // 本地资源的情况下
    if (!isAsset) {
      if (message.msgID == null || message.msgID!.isEmpty) {
        return;
      }

      if (model.getMessageProgress(message.msgID) == 100) {
        String savePath;
        if (message.imageElem!.path != null && message.imageElem!.path != '') {
          savePath = message.imageElem!.path!;
        } else {
          savePath = model.getFileMessageLocation(message.msgID);
        }
        File f = File(savePath);
        if (f.existsSync()) {
          var result = await ImageGallerySaver.saveFile(savePath);

          if (PlatformUtils().isIOS) {
            if (result['isSuccess']) {
              print("怎么回事呢232423");
              if (needShare) {
                Share.shareXFiles([XFile(savePath)], text: '');
                return;
              }
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("图片保存成功"),
                  infoCode: 6660406));
            } else {
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("图片保存失败"),
                  infoCode: 6660407));
            }
          } else {
            if (result != null) {
              print("怎么回事呢ewewewew");
              if (needShare) {
                Share.shareXFiles([XFile(savePath)], text: '');
                return;
              }
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("图片保存成功"),
                  infoCode: 6660406));
            } else {
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("图片保存失败"),
                  infoCode: 6660407));
            }
          }
          return;
        }
      } else {
        print("到此一游22222");
        String savePath;
        try {
          if (message.imageElem!.path != null &&
              message.imageElem!.path != '') {
            savePath = message.imageElem!.path!;
          } else {
            savePath = model.getFileMessageLocation(message.msgID);
          }
          Share.shareXFiles([XFile(savePath)], text: '');
        } catch (e) {}
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("the message is downloading"),
            infoCode: -1));
      }
      return;
    }
    var result = await ImageGallerySaver.saveFile(imageUrl);

    if (PlatformUtils().isIOS) {
      if (result['isSuccess']) {
        if (needShare) {
          Share.shareXFiles([XFile(imageUrl)], text: '');
          return;
        }
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("图片保存成功"),
            infoCode: 6660406));
      } else {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("图片保存失败"),
            infoCode: 6660407));
      }
    } else {
      if (result != null) {
        print("怎么回事呢111");
        if (needShare) {
          Share.shareXFiles([XFile(imageUrl)], text: '');
          return;
        }
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("图片保存成功"),
            infoCode: 6660406));
      } else {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("图片保存失败"),
            infoCode: 6660407));
      }
    }
    return;
  }

  Future<void> _saveImg(
      {required TUITheme theme,
      required V2TimMessage message,
      bool needShare = false}) async {
    String? path = message.imageElem!.path;
    if (path != null && PlatformUtils().isWeb
        ? true
        : File(path!).existsSync()) {
      return await _saveImageToLocal(context, message, path,
          isAsset: true, theme: theme, needShare: needShare);
    } else {
      String imgUrl = getBigPicUrl(message);
      if (message.imageElem!.imageList![0]!.localUrl != '' &&
          message.imageElem!.imageList![0]!.localUrl != null) {
        File f = File(message.imageElem!.imageList![0]!.localUrl!);
        if (f.existsSync()) {
          return await _saveImageToLocal(
              context, message, message.imageElem!.imageList![0]!.localUrl!,
              isAsset: true, theme: theme, needShare: needShare);
        }
      }
      if (message.imageElem!.path != '' && message.imageElem!.path != null) {
        File f = File(message.imageElem!.path!);
        if (f.existsSync()) {
          return await _saveImageToLocal(
              context, message, message.imageElem!.path!,
              isAsset: true, theme: theme, needShare: needShare);
        }
      }
      return await _saveImageToLocal(context, message, imgUrl,
          isAsset: false, theme: theme, needShare: needShare);
    }
  }

  V2TimImage? getImageFromList(
      V2TimImageTypesEnum imgType, V2TimMessage message) {
    V2TimImage? img = MessageUtils.getImageFromImgList(
        message.imageElem!.imageList,
        HistoryMessageDartConstant.imgPriorMap[imgType] ??
            HistoryMessageDartConstant.oriImgPrior);

    return img;
  }

  List<V2TimMessage> filterMessages(List<V2TimMessage>? messageList) {
    List<V2TimMessage> filteredMessages = [];
    if (messageList == null) {
      return filteredMessages;
    }
    for (V2TimMessage message in messageList) {
      if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
          message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
        filteredMessages.add(message);
      }
    }
    return filteredMessages.reversed.toList();
  }

  int findMessageIndexById(List<V2TimMessage> messageList, String targetId) {
    for (int i = 0; i < messageList.length; i++) {
      V2TimMessage message = messageList[i];
      if (message.msgID == targetId) {
        return i;
      }
    }
    return -1; // 返回-1表示未找到指定id的message
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final theme = value.theme;
    var messageList = globalModel.messageListMap[widget.conId] ?? [];
    List<V2TimMessage> filteredMessages = filterMessages(messageList);
    var currentIndex = filteredMessages
        .indexWhere((message) => message.msgID == widget.message.msgID);
    if (currentIndex == -1) {
      messageList.add(widget.message);
      currentIndex = 0;
    }
    print("输出当前的index：+");
    print(currentIndex);
    print(widget.message.msgID);
    print("输出当前message 长度：+");
    print(filteredMessages.length);
    return GestureDetector(
      onTap: () {},
      child: Swiper(
        loop: false,
        itemBuilder: (BuildContext context, int index) {
          final message = filteredMessages[index];
          final heroTag =
              "${message.msgID ?? message.id ?? message.timestamp ?? DateTime.now().millisecondsSinceEpoch}";
          if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
            V2TimImage? originalImg =
                getImageFromList(V2TimImageTypesEnum.original, message);
            V2TimImage? smallImg =
                getImageFromList(V2TimImageTypesEnum.small, message);
            String? showImage = originalImg?.localUrl != null &&
                    File(originalImg?.localUrl ?? "").existsSync()
                ? originalImg?.localUrl
                : smallImg?.localUrl;
            final url = showImage ?? message.imageElem!.path!;
            print("输出当前的url是空的哈" + url);
            if (url == null || url == "") {
              print("输出当前的url是空的哈");
              String bigImgUrl = originalImg?.url ?? getBigPicUrl(message);
              if (bigImgUrl.isEmpty && smallImg?.url != null) {
                bigImgUrl = smallImg?.url ?? "";
              }
              return ImageScreen(
                  imageProvider: CachedNetworkImageProvider(
                    bigImgUrl,
                    cacheKey: message.msgID,
                  ),
                  heroTag: heroTag,
                  messageID: message.msgID,
                  shareFn: () async {
                    print("这到底是什么情况1iii");
                    return await _saveImg(
                        theme: theme!, message: message, needShare: true);
                  },
                  downloadFn: () async {
                    return await _saveImg(theme: theme!, message: message);
                  });
            }
            return ImageScreen(
                imageProvider:
                    FileImage(File(showImage ?? message.imageElem!.path!)),
                heroTag: heroTag,
                messageID: message.msgID,
                shareFn: () async {
                  print("这到底是什么情况1");
                  return await _saveImg(
                      theme: theme!, message: message, needShare: true);
                },
                downloadFn: () async {
                  return await _saveImg(theme: theme!, message: message);
                });
          }

          return VideoScreen(
              message: message,
              heroTag: heroTag,
              videoElement: message.videoElem!
              // videoElement: message.videoElem!,
              );
        },
        index: currentIndex,
        itemCount: filteredMessages.length,
        pagination: SwiperPagination(
            margin: new EdgeInsets.all(0.0),
            builder: new SwiperCustomPagination(
                builder: (BuildContext context, SwiperPluginConfig config) {
              return SizedBox();
            })),
        control: SwiperControl(size: 0),
      ),
    );
  }
}

class ImageClipper extends CustomClipper<RRect> {
  @override
  RRect getClip(Size size) {
    return RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, min(size.height, 256)),
        const Radius.circular(5));
  }

  @override
  bool shouldReclip(CustomClipper<RRect> oldClipper) {
    return oldClipper != this;
  }
}
