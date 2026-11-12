import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'editor/prototype_controls.dart';

class AmapKeyTutorial extends StatelessWidget {
  const AmapKeyTutorial({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A clickable address, drawn in the accent colour with an underline so it
    // reads as a link rather than as sample text.
    Widget link(String label, String url) => InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary.withValues(alpha: .5)))));
    // A short literal the user has to copy; monospace so it is unambiguous.
    Widget literal(String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(3)),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: const ['Courier New', 'monospace'],
                fontSize: 11.5,
                color: scheme.onSurface)));
    Widget step(String number, String title, List<Widget> body,
            {String? warning}) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(number,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary))),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    const SizedBox(height: 5),
                    ...body,
                    if (warning != null) ...[
                      const SizedBox(height: 6),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.priority_high_rounded,
                                size: 13, color: scheme.error),
                            const SizedBox(width: 5),
                            Expanded(
                                child: Text(warning,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.55,
                                        color: scheme.error)))
                          ])
                    ]
                  ]))
            ]));
    Widget line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(text,
            style: EditorTypography.hint(context)
                .copyWith(fontSize: 11.5, height: 1.65)));
    Widget flow(List<Widget> parts) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final part in parts)
            Padding(
                padding: const EdgeInsets.only(right: 2, bottom: 2),
                child: part)
        ]));

    return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(9)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('按下面六步申请，都是免费的。',
              style: EditorTypography.hint(context)
                  .copyWith(fontSize: 11.5, height: 1.6)),
          const SizedBox(height: 14),
          step('1', '注册并登录', [
            flow([
              const Text('打开 ', style: TextStyle(fontSize: 11.5, height: 1.65)),
              link('高德开放平台控制台', 'https://console.amap.com/dev/key/app'),
              const Text('，用手机号注册。',
                  style: TextStyle(fontSize: 11.5, height: 1.65))
            ]),
            line('注册后会自动进入控制台。'),
          ]),
          step(
              '2',
              '完成实名认证',
              [
                flow([
                  const Text('左侧菜单 → ',
                      style: TextStyle(fontSize: 11.5, height: 1.65)),
                  literal('账号管理'),
                  const Text(' → ',
                      style: TextStyle(fontSize: 11.5, height: 1.65)),
                  literal('实名认证'),
                ]),
                line('个人开发者填真实姓名和身份证号，用支付宝或微信扫码人脸识别，通常 1 分钟内通过。'),
                line('企业开发者需要上传营业执照。'),
              ],
              warning: '这一步不能跳过。没认证时「添加 Key」按钮是灰的，点不了。'),
          step('3', '创建应用', [
            flow([
              const Text('左侧菜单 → ',
                  style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('应用管理'),
              const Text(' → ', style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('我的应用'),
              const Text('，点右上角 ',
                  style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('创建新应用'),
            ]),
            line('名称随意填，比如「照片边框」；类型选「其他」，然后点创建。'),
          ]),
          step(
              '4',
              '添加 Key',
              [
                flow([
                  const Text('在刚创建的应用卡片上点 ',
                      style: TextStyle(fontSize: 11.5, height: 1.65)),
                  literal('添加 Key'),
                ]),
                line('Key 名称随意，比如「lumacraft-local」。'),
                flow([
                  const Text('服务平台必须选 ',
                      style: TextStyle(fontSize: 11.5, height: 1.65)),
                  literal('Web端 (JS API)'),
                ]),
                line('勾选协议后提交，会得到两项：Key（32 位）和安全密钥（也是 32 位）。两个都要复制。'),
              ],
              warning:
                  '服务平台选错是最常见的坑。选成「Web服务」「Android」或「iOS」地图都加载不出来，会报平台不匹配。'),
          step('5', '配置域名白名单', [
            flow([
              const Text('在 Key 那一行点 ',
                  style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('设置'),
              const Text(' 或 ', style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('编辑'),
              const Text('，找到 ',
                  style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('域名白名单'),
            ]),
            flow([
              const Text('填入 ', style: TextStyle(fontSize: 11.5, height: 1.65)),
              literal('127.0.0.1'),
              const Text('，点保存。',
                  style: TextStyle(fontSize: 11.5, height: 1.65)),
            ]),
            line('地图由软件在本机自己提供，地址是 127.0.0.1。白名单只匹配域名部分，'
                '不要带 http://、不要带端口号、不要加斜杠。'),
          ]),
          step('6', '填进这里', [
            line('把 32 位 Key 填到「高德地图 Key」，安全密钥填到「安全密钥」。'),
            line('两项长度一样，容易填反，建议复制后核对开头几位。'),
            line('填好后点「测试连接」，能查到地址就是配置成功。保存后等 1–2 分钟生效。'),
          ]),
          const SizedBox(height: 2),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse('https://console.amap.com/dev/key/app'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('打开高德控制台', style: TextStyle(fontSize: 12))))
        ]));
  }
}
