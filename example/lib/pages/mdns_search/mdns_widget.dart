import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

class MdnsSearchWidget extends StatefulWidget {
  const MdnsSearchWidget({
    super.key,
    required this.activeHost,
  });

  final ActiveHost activeHost;

  @override
  State<MdnsSearchWidget> createState() => _MdnsSearchWidgetState();
}

class _MdnsSearchWidgetState extends State<MdnsSearchWidget> {
  @override
  initState() {
    super.initState();
    initialzeActiveHost();
  }

  MdnsInfo? mdnsInfo;
  bool mdnsInfoFound = false;

  String? hostName;
  bool hostNameFound = false;

  String? deviceName;
  bool deviceNameFound = false;

  String? macAddress;
  bool macAddressFound = false;

  initialzeActiveHost() {
    widget.activeHost.mdnsInfo.then((value) {
      setState(() {
        mdnsInfo = value;
        mdnsInfoFound = true;
      });
    });

    widget.activeHost.hostName.then((value) {
      setState(() {
        hostName = value;
        hostNameFound = true;
      });
    });

    widget.activeHost.deviceName.then((value) {
      setState(() {
        deviceName = value;
        deviceNameFound = true;
      });
    });

    widget.activeHost.getMacAddress().then((value) {
      setState(() {
        macAddress = value;
        macAddressFound = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!mdnsInfoFound ||
        !hostNameFound ||
        !deviceNameFound ||
        !macAddressFound) {
      return const SizedBox();
    }

    return ListTile(
      title: Text(widget.activeHost.weirdHostName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('mDNS: ${mdnsInfo?.mdnsName}'),
          const SizedBox(height: 5),
          Text('Device: $deviceName'),
          const SizedBox(height: 5),
          Text('Mac: $macAddress'),
          const SizedBox(height: 5),
          Text('Host: $hostName '),
        ],
      ),
    );
  }
}
