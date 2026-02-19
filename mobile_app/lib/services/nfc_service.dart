import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart' show Ndef;

class NFCService {
  // Add this field to track the pending session
  Completer<String>? _sessionCompleter;

  Future<bool> isNFCAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  Future<String> startNFCSession() async {
    final isAvailable = await isNFCAvailable();
    if (!isAvailable) {
      throw NFCException('NFC is not available on this device');
    }

    // Initialize the completer to track this session
    _sessionCompleter = Completer<String>();

    try {
      await NfcManager.instance.startSession(
        // Note: On Android, pollingOptions are largely ignored by the platform 
        // but keeping them doesn't hurt.
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final payload = await readTag(tag);
            await NfcManager.instance.stopSession();
            
            if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
              _sessionCompleter!.complete(payload);
            }
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessageIos: e.toString());
            if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
              _sessionCompleter!.completeError(
                  e is Exception ? e : NFCException(e.toString()));
            }
          } finally {
            _sessionCompleter = null; 
          }
        },
      );
    } catch (e) {
      throw NFCException('Failed to start NFC session: $e');
    }

    return _sessionCompleter!.future;
  }

  Future<String> readTag(NfcTag tag) async {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      throw NFCException('Tag does not contain NDEF data');
    }
    final cachedMessage = ndef.cachedMessage;
    if (cachedMessage == null || cachedMessage.records.isEmpty) {
      throw NFCException('Tag is empty or unreadable');
    }

    for (final record in cachedMessage.records) {
      try {
        // Check for Well Known Text record (Index 1 = WellKnown)
        if (record.typeNameFormat.index == 1) {
          final type = String.fromCharCodes(record.type);
          if (type == 'T') {
            final payload = record.payload;
            if (payload.isEmpty) continue;

            final statusByte = payload[0];
            final languageCodeLength = statusByte & 0x3F;
            final textStartIndex = 1 + languageCodeLength;
            
            if (payload.length <= textStartIndex) continue;

            final textBytes = payload.sublist(textStartIndex);
            final text = utf8.decode(textBytes);

            if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
              return text.trim();
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    throw NFCException('No valid JSON payload found in NFC tag');
  }

  /// Stops the session and cancels the ongoing waiter
  Future<void> stopNFCSession() async {
    await NfcManager.instance.stopSession();
    
    // CRITICAL FIX: Notify the waiting code that we cancelled!
    if (_sessionCompleter != null && !_sessionCompleter!.isCompleted) {
      _sessionCompleter!.completeError(NFCException('Session canceled by user'));
      _sessionCompleter = null;
    }
  }
}

class NFCException implements Exception {
  final String message;
  NFCException(this.message);
  @override
  String toString() => 'NFCException: $message';
}