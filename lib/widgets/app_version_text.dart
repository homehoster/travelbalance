import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionText extends StatelessWidget {
  final bool showBuild;
  final String prefix;
  final TextStyle? style;
  const AppVersionText({
    super.key,
    this.showBuild = true,
    this.prefix = 'Version ',
    this.style,
  });

  // einmal laden, danach aus dem Cache
  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) {
        final i = snap.data;
        final text = i == null
            ? '$prefix…'
            : '$prefix${i.version}${showBuild ? ' (${i.buildNumber})' : ''}';
        return Text(text, style: style);
      },
    );
  }
}