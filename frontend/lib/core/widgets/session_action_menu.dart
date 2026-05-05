import 'package:flutter/material.dart';

enum SessionActionMenuItem { connectivity, signOut }

class SessionActionMenu extends StatelessWidget {
  const SessionActionMenu({
    super.key,
    required this.displayName,
    required this.signOutLabel,
    required this.onSignOut,
    this.subtitle,
    this.isOnline,
    this.goOnlineLabel,
    this.goOfflineLabel,
    this.onToggleConnectivity,
  });

  final String displayName;
  final String signOutLabel;
  final String? subtitle;
  final bool? isOnline;
  final String? goOnlineLabel;
  final String? goOfflineLabel;
  final VoidCallback onSignOut;
  final VoidCallback? onToggleConnectivity;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SessionActionMenuItem>(
      tooltip: displayName,
      onSelected: (value) {
        switch (value) {
          case SessionActionMenuItem.connectivity:
            onToggleConnectivity?.call();
            break;
          case SessionActionMenuItem.signOut:
            onSignOut();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<SessionActionMenuItem>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName, style: Theme.of(context).textTheme.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onToggleConnectivity != null &&
            isOnline != null &&
            goOnlineLabel != null &&
            goOfflineLabel != null)
          PopupMenuItem<SessionActionMenuItem>(
            value: SessionActionMenuItem.connectivity,
            child: Row(
              children: [
                Icon(isOnline! ? Icons.wifi : Icons.wifi_off),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(isOnline! ? goOfflineLabel! : goOnlineLabel!),
                ),
              ],
            ),
          ),
        PopupMenuItem<SessionActionMenuItem>(
          value: SessionActionMenuItem.signOut,
          child: Row(
            children: [
              const Icon(Icons.logout),
              const SizedBox(width: 10),
              Expanded(child: Text(signOutLabel)),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.more_horiz),
      ),
    );
  }
}
