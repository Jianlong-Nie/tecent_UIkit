import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_im_base/tencent_im_base.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:universal_html/html.dart' as html;
import 'package:chewie_for_us/chewie_for_us.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/video_custom_control.dart';
import 'package:video_player/video_player.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:share_plus/share_plus.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen(
      {required this.message,
      required this.heroTag,
      // required this.videoElement,
      Key? key})
      : super(key: key);

  final V2TimMessage message;

  final dynamic heroTag;
  // final V2TimVideoElem videoElement;

  @override
  State<StatefulWidget> createState() => _VideoScreenState();
}

class _VideoScreenState extends TIMUIKitState<VideoScreen> {
  final MessageService _messageService = serviceLocator<MessageService>();
  late V2TimVideoElem stateElement = widget.message.videoElem!;
  late VideoPlayerController videoPlayerController;
  late ChewieController chewieController;
  GlobalKey<ExtendedImageSlidePageState> slidePagekey =
      GlobalKey<ExtendedImageSlidePageState>();
  final TUIChatGlobalModel model = serviceLocator<TUIChatGlobalModel>();
  bool isInit = false;
  // bool isDisappeared = false;
  @override
  initState() {
    super.initState();
    if (TencentUtils.checkString(widget.message.videoElem!.videoUrl) == null) {
      downloadMessageDetailAndSave();
    } else {
      setVideoMessage();
    }
    // 允许横屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  downloadMessageDetailAndSave() async {
    if (TencentUtils.checkString(widget.message.msgID) != null) {
      if (TencentUtils.checkString(widget.message.videoElem!.videoUrl) ==
          null) {
        final response = await _messageService.getMessageOnlineUrl(
            msgID: widget.message.msgID!);
        if (response.data != null) {
          widget.message.videoElem = response.data!.videoElem;
          setState(() => stateElement = response.data!.videoElem!);
          Future.delayed(const Duration(microseconds: 10), () {
            setVideoMessage();
          });
        }
      }
      if (!PlatformUtils().isWeb) {
        if (TencentUtils.checkString(widget.message.videoElem!.localVideoUrl) ==
                null ||
            !File(widget.message.videoElem!.localVideoUrl!).existsSync()) {
          _messageService.downloadMessage(
              msgID: widget.message.msgID!,
              messageType: 5,
              imageType: 0,
              isSnapshot: false);
        }
        if (TencentUtils.checkString(
                    widget.message.videoElem!.localSnapshotUrl) ==
                null ||
            !File(widget.message.videoElem!.localSnapshotUrl!).existsSync()) {
          _messageService.downloadMessage(
              msgID: widget.message.msgID!,
              messageType: 5,
              imageType: 0,
              isSnapshot: true);
        }
      }
    }
  }

  //保存网络视频到本地
  Future<void> _saveNetworkVideo(context, String videoUrl,
      {bool isAsset = true, bool needShare = false}) async {
    if (PlatformUtils().isWeb) {
      RegExp exp = RegExp(r"((\.){1}[^?]{2,4})");
      String? suffix = exp.allMatches(videoUrl).last.group(0);
      var xhr = html.HttpRequest();
      xhr.open('get', videoUrl);
      xhr.responseType = 'arraybuffer';
      xhr.onLoad.listen((event) {
        final a = html.AnchorElement(
            href: html.Url.createObjectUrl(html.Blob([xhr.response])));
        a.download = '${md5.convert(utf8.encode(videoUrl)).toString()}$suffix';
        a.click();
        a.remove();
      });
      xhr.send();
      return;
    }
    if (PlatformUtils().isMobile) {
      if (PlatformUtils().isIOS) {
        if (!await Permissions.checkPermission(
          context,
          Permission.photosAddOnly.value,
        )) {
          return;
        }
      } else {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if ((androidInfo.version.sdkInt) >= 33) {
          final videos = await Permissions.checkPermission(
            context,
            Permission.videos.value,
          );

          if (!videos) {
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
    String savePath = videoUrl;
    if (!isAsset) {
      if (widget.message.msgID == null || widget.message.msgID!.isEmpty) {
        return;
      }
      if (model.getMessageProgress(widget.message.msgID) == 100) {
        String savePath;
        if (widget.message.videoElem!.localVideoUrl != null &&
            widget.message.videoElem!.localVideoUrl != '') {
          savePath = widget.message.videoElem!.localVideoUrl!;
        } else {
          savePath = model.getFileMessageLocation(widget.message.msgID);
        }
        File f = File(savePath);
        if (f.existsSync()) {
          var result = await ImageGallerySaver.saveFile(savePath);
          if (PlatformUtils().isIOS) {
            if (result['isSuccess']) {
              if (needShare) {
                Share.shareXFiles([XFile(savePath)], text: '');
                return;
              }
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("视频保存成功"),
                  infoCode: 6660402));
            } else {
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("视频保存失败"),
                  infoCode: 6660403));
            }
          } else {
            if (result != null) {
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("视频保存成功"),
                  infoCode: 6660402));
            } else {
              onTIMCallback(TIMCallback(
                  type: TIMCallbackType.INFO,
                  infoRecommendText: TIM_t("视频保存失败"),
                  infoCode: 6660403));
            }
          }
        }
      } else {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("the message is downloading"),
            infoCode: -1));
      }
      return;
    }
    var result = await ImageGallerySaver.saveFile(savePath);
    if (PlatformUtils().isIOS) {
      if (result['isSuccess']) {
        if (needShare) {
          Share.shareXFiles([XFile(savePath)], text: '');
          return;
        }
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("视频保存成功"),
            infoCode: 6660402));
      } else {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("视频保存失败"),
            infoCode: 6660403));
      }
    } else {
      if (result != null) {
        if (needShare) {
          Share.shareXFiles([XFile(savePath)], text: '');
          return;
        }
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("视频保存成功"),
            infoCode: 6660402));
      } else {
        onTIMCallback(TIMCallback(
            type: TIMCallbackType.INFO,
            infoRecommendText: TIM_t("视频保存失败"),
            infoCode: 6660403));
      }
    }
    return;
  }

  Future<void> _saveVideo({bool needShare = false}) async {
    if (PlatformUtils().isWeb) {
      return await _saveNetworkVideo(context, stateElement.videoPath!,
          isAsset: true, needShare: needShare);
    }
    if (stateElement.videoPath != '' && stateElement.videoPath != null) {
      File f = File(stateElement.videoPath!);
      if (f.existsSync()) {
        return await _saveNetworkVideo(context, stateElement.videoPath!,
            isAsset: true, needShare: needShare);
      }
    }
    if (stateElement.localVideoUrl != '' &&
        stateElement.localVideoUrl != null) {
      File f = File(stateElement.localVideoUrl!);
      if (f.existsSync()) {
        return await _saveNetworkVideo(context, stateElement.localVideoUrl!,
            isAsset: true, needShare: needShare);
      }
    }
    return await _saveNetworkVideo(context, stateElement.videoUrl!,
        isAsset: false, needShare: needShare);
  }

  double getVideoHeight() {
    double height = stateElement.snapshotHeight!.toDouble();
    double width = stateElement.snapshotWidth!.toDouble();
    // 横图
    if (width > height) {
      return height * 1.3;
    }
    return height;
  }

  double getVideoWidth() {
    double height = stateElement.snapshotHeight!.toDouble();
    double width = stateElement.snapshotWidth!.toDouble();
    // 横图
    if (width > height) {
      return width * 1.3;
    }
    return width;
  }

  setVideoMessage() async {
    // Using local path while sending
    // VideoPlayerController player = widget.message.videoElem!.videoUrl == null ||
    //         widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING
    //     ? VideoPlayerController.file(File(
    //         widget.message.videoElem!.videoPath!,
    //       ))
    //     : (widget.message.videoElem?.localVideoUrl == null ||
    //             widget.message.videoElem?.localVideoUrl == "")
    //         ? VideoPlayerController.network(
    //             widget.message.videoElem!.videoUrl!,
    //           )
    //         : VideoPlayerController.file(File(
    //             widget.message.videoElem!.localVideoUrl!,
    //           ));
    if (!PlatformUtils().isWeb) {
      if (widget.message.msgID != null || widget.message.msgID != '') {
        if (model.getMessageProgress(widget.message.msgID) == 100) {
          String savePath;
          if (widget.message.videoElem!.localVideoUrl != null &&
              widget.message.videoElem!.localVideoUrl != '') {
            savePath = widget.message.videoElem!.localVideoUrl!;
          } else {
            savePath = model.getFileMessageLocation(widget.message.msgID);
          }
          File f = File(savePath);
          if (f.existsSync()) {
            stateElement.localVideoUrl =
                model.getFileMessageLocation(widget.message.msgID);
          }
        }
      }
    }

    VideoPlayerController player = PlatformUtils().isWeb
        ? ((stateElement.videoPath != null &&
                    stateElement.videoPath!.isNotEmpty) ||
                widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING
            ? VideoPlayerController.network(
                stateElement.videoPath!,
              )
            : (stateElement.localVideoUrl == null ||
                    stateElement.localVideoUrl == "")
                ? VideoPlayerController.network(
                    stateElement.videoUrl!,
                  )
                : VideoPlayerController.network(
                    stateElement.localVideoUrl!,
                  ))
        : (stateElement.videoPath != null &&
                    stateElement.videoPath!.isNotEmpty) ||
                widget.message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING
            ? VideoPlayerController.file(File(stateElement.videoPath!))
            : (stateElement.localVideoUrl == null ||
                    stateElement.localVideoUrl == "")
                ? VideoPlayerController.network(
                    stateElement.videoUrl!,
                  )
                : VideoPlayerController.file(File(
                    stateElement.localVideoUrl!,
                  ));
    await player.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      double w = getVideoWidth();
      double h = getVideoHeight();
      ChewieController controller = ChewieController(
          videoPlayerController: player,
          autoPlay: true,
          looping: false,
          showControlsOnInitialize: false,
          allowPlaybackSpeedChanging: false,
          aspectRatio: w == 0 || h == 0 ? null : w / h,
          customControls: VideoCustomControls(
            downloadFn: () async {
              return await _saveVideo();
            },
            shareFn: () async {
              return await _saveVideo(needShare: true);
            },
          ));
      setState(() {
        videoPlayerController = player;
        chewieController = controller;
        isInit = true;
      });
    });
  }

  @override
  didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.videoElem!.videoUrl !=
            widget.message.videoElem!.videoUrl ||
        oldWidget.message.videoElem!.videoPath !=
            widget.message.videoElem!.videoPath) {
      setVideoMessage();
      print("输出视频的url" + (stateElement.videoUrl ?? ""));
      print(stateElement);
    }
    // print("isDisappeared");
    // print(isDisappeared);
    // if (isDisappeared) {
    //   setVideoMessage();
    //   isDisappeared = false;
    // }
    // // if (!isInit) {}
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // isDisappeared = true;
    if (isInit) {
      videoPlayerController.dispose();
      chewieController.dispose();
    }
    print("这是怎么回事");
    super.dispose();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    return OrientationBuilder(builder: ((context, orientation) {
      return Scaffold(
          body: Container(
        color: Colors.transparent,
        constraints: BoxConstraints.expand(
          height: MediaQuery.of(context).size.height,
        ),
        child: ExtendedImageSlidePage(
            key: slidePagekey,
            slidePageBackgroundHandler: (Offset offset, Size size) {
              if (orientation == Orientation.landscape) {
                return Colors.black;
              }
              double opacity = 0.0;
              opacity = offset.distance /
                  (Offset(size.width, size.height).distance / 2.0);
              return Colors.black
                  .withOpacity(min(1.0, max(1.0 - opacity, 0.0)));
            },
            slideType: SlideType.onlyImage,
            child: ExtendedImageSlidePageHandler(
              child: Container(
                  color: Colors.black,
                  child: isInit
                      ? Chewie(
                          controller: chewieController,
                        )
                      : const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white))),
              heroBuilderForSlidingPage: (Widget result) {
                return Hero(
                  tag: widget.heroTag,
                  child: result,
                  flightShuttleBuilder: (BuildContext flightContext,
                      Animation<double> animation,
                      HeroFlightDirection flightDirection,
                      BuildContext fromHeroContext,
                      BuildContext toHeroContext) {
                    final Hero hero =
                        (flightDirection == HeroFlightDirection.pop
                            ? fromHeroContext.widget
                            : toHeroContext.widget) as Hero;

                    return hero.child;
                  },
                );
              },
            )),
      ));
    }));
  }
}
