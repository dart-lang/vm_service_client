// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library vm_service_client;

import 'dart:async';
// TODO(nweiz): Conditionally import dart:io when cross-platform libraries work.
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart' as rpc;

import 'src/flag.dart';
import 'src/service_version.dart';
import 'src/vm.dart';

export 'src/flag.dart' hide newVMFlagList;
export 'src/vm.dart' hide newVM;
export 'src/service_version.dart' hide newVMServiceVersion;

/// A client for the [Dart VM service protocol][service api].
///
/// [service api]: https://github.com/dart-lang/sdk/blob/master/runtime/vm/service/service.md
///
/// Connect to a VM service endpoint using [connect], and use [getVM] to load
/// information about the VM itself.
///
/// The client supports VM service versions 2.x (which first shipped with Dart
/// 1.12) and 3.x (which first shipped with Dart 1.13). Some functionality may
/// be unavailable in older VM service versions; those places will be clearly
/// documented. You can check the version of the VM service you're connected to
/// using [getVersion].
class VMServiceClient {
  /// The underlying JSON-RPC peer used to communicate with the VM service.
  final rpc.Peer _peer;

  /// A future that fires when the underlying connection has been closed.
  ///
  /// Any connection-level errors will also be emitted through this future.
  final Future done;

  /// Connects to the VM service protocol at [url].
  ///
  /// [url] may be a `ws://` or a `http://` URL. If it's `ws://`, it's
  /// interpreted as the URL to connect to directly. If it's `http://`, it's
  /// interpreted as the URL for the Dart observatory, and the corresponding
  /// WebSocket URL is determined based on that. It may be either a [String] or
  /// a [Uri].
  static Future<VMServiceClient> connect(url) async {
    if (url is! Uri && url is! String) {
      throw new ArgumentError.value(url, "url", "must be a String or a Uri");
    }

    var uri = url is String ? Uri.parse(url) : url;
    if (uri.scheme == 'http') uri = uri.replace(scheme: 'ws', path: '/ws');

    // TODO(nweiz): check the protocol version before connecting, and add a
    // compatibility wrapper if it's 1.0.
    var peer = new rpc.Peer(await WebSocket.connect(uri.toString()));
    return new VMServiceClient._(peer);
  }

  // TODO(nweiz): add constructors that take raw Stream/Sink of either Strings
  // or decoded maps.

  VMServiceClient._(rpc.Peer peer)
      : _peer = peer,
        done = peer.listen();

  // TODO(nweiz): Add a method to validate the version number.

  /// Closes the underlying connection to the VM service.
  ///
  /// Returns a [Future] that fires once the connection has been closed.
  Future close() => _peer.close();

  /// Returns a list of flags that were passed to the VM.
  ///
  /// As of VM service version 3.0, this only includes VM-internal flags.
  Future<List<VMFlag>> getFlags() async =>
      newVMFlagList(await _peer.sendRequest("getFlagList", {}));

  /// Returns the version of the VM service protocol that this client is
  /// communicating with.
  ///
  /// Note that this is distinct from the version of Dart, which is accessible
  /// via [VM.version].
  Future<VMServiceVersion> getVersion() async =>
      newVMServiceVersion(await _peer.sendRequest("getVersion", {}));

  /// Returns information about the Dart VM.
  Future<VM> getVM() async =>
      newVM(_peer, await _peer.sendRequest("getVM", {}));
}