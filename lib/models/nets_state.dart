import 'dart:typed_data';
// Uint8List, the decoded QR image bytes

// where the payment has got to. the panel renders one branch per value
enum NetsStatus {
  loading,
  // asking NETS for a QR code
  awaitingScan,
  // QR is on screen, countdown running, waiting for the user to pay
  success,
  // NETS confirmed the payment - premium is unlocked
  failed,
  // NETS declined it, or the five minutes ran out
  unavailable,
  // no key set, or the sandbox could not be reached - demo mode
}

class NetsState {
// everything the payment UI needs, in one immutable snapshot
//
// note copyWith's plain parameters cannot clear a field back to null -
// passing null means "leave it alone". message is the one field that
// does need clearing (the ordinary success write must drop the last
// webhook line rather than let it survive under the confirmation), so
// it gets the explicit clearMessage flag below instead of overloading
// null for that. retry() does not need this - it throws the whole
// state away and starts from a fresh NetsState()

  final NetsStatus status;
  final Uint8List? qrCode;
  final String? txnRef;
  final int timeLeft;
  // seconds remaining, counts down from 300 (the NETS 5 minute window)
  final String? message;
  // the latest webhook text, or why we are in demo mode

  const NetsState({
    this.status = NetsStatus.loading,
    this.qrCode,
    this.txnRef,
    this.timeLeft = 300,
    this.message,
  });

  NetsState copyWith({
    NetsStatus? status,
    Uint8List? qrCode,
    String? txnRef,
    int? timeLeft,
    String? message,
    bool clearMessage = false,
    // set true to reset message to null; a plain omitted `message` keeps
    // the previous value instead, so clearing needs its own switch
  }) {
    return NetsState(
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      txnRef: txnRef ?? this.txnRef,
      timeLeft: timeLeft ?? this.timeLeft,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
