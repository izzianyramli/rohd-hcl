// Copyright (C) 2024-2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// axi4_main_driver.dart
// A driver for AXI4 requests.
//
// 2025 January
// Author: Josh Kimmel <joshua1.kimmel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/interfaces/interfaces.dart';
import 'package:rohd_hcl/src/models/axi4_bfm/axi4_bfm.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A driver for the [Axi4ReadInterface] interface.
///
/// Driving from the perspective of the Main agent.
class Axi4ReadMainDriver extends PendingClockedDriver<Axi4ReadRequestPacket> {
  /// AXI4 System Interface.
  final Axi4SystemInterface sIntf;

  /// AXI4 Read Interface.
  final Axi4ReadInterface rIntf;

  /// Creates a new [Axi4ReadMainDriver].
  Axi4ReadMainDriver({
    required Component parent,
    required this.sIntf,
    required this.rIntf,
    required super.sequencer,
    super.timeoutCycles = 500,
    super.dropDelayCycles = 30,
    String name = 'axi4ReadMainDriver',
  }) : super(
          name,
          parent,
          clk: sIntf.clk,
        );

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    Simulator.injectAction(() {
      rIntf.arValid.put(0);
      rIntf.arId?.put(0);
      rIntf.arAddr.put(0);
      rIntf.arLen?.put(0);
      rIntf.arSize?.put(0);
      rIntf.arBurst?.put(0);
      rIntf.arLock?.put(0);
      rIntf.arCache?.put(0);
      rIntf.arProt.put(0);
      rIntf.arQos?.put(0);
      rIntf.arRegion?.put(0);
      rIntf.arUser?.put(0);
      rIntf.rReady.put(0);
    });

    // wait for reset to complete before driving anything
    await sIntf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      if (pendingSeqItems.isNotEmpty) {
        await _drivePacket(pendingSeqItems.removeFirst());
      } else {
        await sIntf.clk.nextPosedge;
      }
    }
  }

  /// Drives a packet onto the interface.
  Future<void> _drivePacket(Axi4RequestPacket packet) async {
    if (packet is Axi4ReadRequestPacket) {
      logger.info('Driving read packet.');
      await _driveReadPacket(packet);
    } else {
      await sIntf.clk.nextPosedge;
    }
  }

  // TODO(kimmeljo): need a more robust way of
  // driving the "ready" signals RREADY for read data responses
  // specifically, when should they toggle on/off?
  //  ON => either always or when the associated request is driven?
  //  OFF => either never or when there are no more
  //         outstanding requests of the given type?
  // should we enable the ability to backpressure??

  Future<void> _driveReadPacket(Axi4ReadRequestPacket packet) async {
    await sIntf.clk.nextPosedge;
    Simulator.injectAction(() {
      rIntf.arValid.put(1);
      rIntf.arId?.put(packet.id);
      rIntf.arAddr.put(packet.addr);
      rIntf.arLen?.put(packet.len);
      rIntf.arSize?.put(packet.size);
      rIntf.arBurst?.put(packet.burst);
      rIntf.arLock?.put(packet.lock);
      rIntf.arCache?.put(packet.cache);
      rIntf.arProt.put(packet.prot);
      rIntf.arQos?.put(packet.qos);
      rIntf.arRegion?.put(packet.region);
      rIntf.arUser?.put(packet.user);
      rIntf.rReady.put(1);
    });

    // need to hold the request until receiver is ready
    await sIntf.clk.nextPosedge;
    if (!rIntf.arReady.previousValue!.toBool()) {
      await rIntf.arReady.nextPosedge;
    }

    // now we can release the request
    // in the future, we may want to wait for the response to complete
    Simulator.injectAction(() {
      rIntf.arValid.put(0);
      packet.complete();
    });
  }
}
