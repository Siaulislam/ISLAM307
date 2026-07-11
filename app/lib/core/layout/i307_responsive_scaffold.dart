import 'package:flutter/material.dart';
import 'i307_breakpoints.dart';

/// Centers content and applies responsive padding — use on every screen.
class I307ResponsiveScaffold extends StatelessWidget {
  const I307ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Colors.white,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: I307Breakpoints.contentMaxWidth(context)),
          child: body,
        ),
      ),
    );
  }
}

/// Master-detail for tablet / foldable / wide phone landscape.
class I307MasterDetail extends StatelessWidget {
  const I307MasterDetail({
    super.key,
    required this.master,
    required this.detail,
    this.masterFlex = 2,
    this.detailFlex = 3,
  });

  final Widget master;
  final Widget detail;
  final int masterFlex;
  final int detailFlex;

  @override
  Widget build(BuildContext context) {
    if (!I307Breakpoints.useMasterDetail(context)) {
      return detail;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: masterFlex, child: master),
        VerticalDivider(width: 1, color: Colors.grey.shade200),
        Expanded(flex: detailFlex, child: detail),
      ],
    );
  }
}
