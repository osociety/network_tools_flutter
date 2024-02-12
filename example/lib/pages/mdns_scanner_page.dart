import 'package:flutter/material.dart';
import 'package:network_tools_flutter/network_tools_flutter.dart';

class MdnsScannerPage extends StatefulWidget {
  const MdnsScannerPage({super.key});

  @override
  State<MdnsScannerPage> createState() => _MdnsScannerPageState();
}

class _MdnsScannerPageState extends State<MdnsScannerPage> {
  List<ActiveHost> activeHosts = [];

  @override
  void initState() {
    super.initState();
    searchMdns();
  }

  searchMdns() async {
    NetInterface? netInt = await NetInterface.localInterface();
    if (netInt == null) {
      return;
    }
    List<ActiveHost> hosts = await MdnsScannerService.instance
        .searchMdnsDevices(forceUseOfSavedSrvRecordList: true);

    setState(() {
      activeHosts.addAll(hosts);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('mDNS Devices'),
      ),
      body: Center(
        child: activeHosts.isEmpty
            ? const CircularProgressIndicator()
            : ListView.builder(
                itemCount: activeHosts.length,
                itemBuilder: (context, index) {
                  final ActiveHost activeHost = activeHosts[index];
                  return ListTile(
                    title: Text(activeHost.weirdHostName),
                    subtitle: FutureBuilder(
                      future: activeHost.mdnsInfo,
                      builder: (BuildContext context, mdnsInfoResult) =>
                          mdnsInfoResult.hasData
                              ? Text(mdnsInfoResult.data?.mdnsName ?? '')
                              : const SizedBox(),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
