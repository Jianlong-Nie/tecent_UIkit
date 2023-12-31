import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_operation_item.dart';
import 'package:tencent_im_base/tencent_im_base.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_ui_group_search_msg.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_add_opt.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_detail_card.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_manage.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_member_tile.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_message_disturb.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_name_card.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_notification.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_pin_conversation.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitGroupProfile/widgets/tim_uikit_group_type.dart';

class TIMUIKitGroupProfileWidget {
  static Widget detailCard(
      {required V2TimGroupInfo groupInfo,
      bool isHavePermission = false,

      /// You can deal with updating group name manually, or UIKIt do it automatically.
      Function(String updateGroupName)? updateGroupName}) {
    return GroupProfileDetailCard(
      groupInfo: groupInfo,
      isHavePermission: isHavePermission,
      updateGroupName: updateGroupName,
    );
  }

  static Widget memberTile() {
    return GroupMemberTile();
  }

  static Widget groupNotification({
    required Function(String) callback,
    required Function() onShareQRCode,
    required Function() onShareContact,
    required V2TimGroupInfo groupInfo,
    bool isHavePermission = false,
  }) {
    final String notification =
        (groupInfo.notification != null && groupInfo!.notification!.isNotEmpty)
            ? groupInfo!.notification!
            : TIM_t("暂无群公告");
    return Column(children: [
      Container(
        child: InkWell(
          onTap: () {
            onShareContact();
            // Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //         builder: (context) =>
            //             ShareContact(userProfile: userInfo.userProfile)));
          },
          child: TIMUIKitOperationItem(
            isEmpty: false,
            operationName: "Share contact",
            showAllowEditStatus: true,
            operationRightWidget: Text(
              "",
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
      InkWell(
        onTap: onShareQRCode,
        child: TIMUIKitOperationItem(
          isEmpty: false,
          operationName: "Group QR Code",
          operationRightWidget: Align(
              alignment: Alignment.centerRight,
              child: Image.asset(
                "assets/qrcodeicon.png",
                width: 20,
                height: 20,
              )),
        ),
      ),
      ProfileItem(
        title: TIM_t("群公告"),
        callback: callback,
        content: notification,
        isHavePermission: isHavePermission,
      )
    ]);
  }

  static Widget groupManage() {
    return const GroupProfileGroupManage();
  }

  static Widget searchMessage(Function(V2TimConversation?) onJumpToSearch) {
    return GroupProfileGroupSearch(onJumpToSearch: onJumpToSearch);
  }

  static Widget operationDivider(TUITheme theme) {
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;
    return Container(
      color: theme.weakDividerColor,
      height: isDesktopScreen ? 1 : 10,
    );
  }

  static Widget groupType() {
    return GroupProfileType();
  }

  static Widget groupAddOpt() {
    return GroupProfileAddOpt();
  }

  static Widget nameCard() {
    return const GroupProfileNameCard();
  }

  static Widget messageDisturb() {
    return GroupMessageDisturb();
  }

  static Widget pinedConversation() {
    return GroupPinConversation();
  }
}
