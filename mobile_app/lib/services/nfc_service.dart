import 'dart:async';
import 'dart:convert';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart' show Ndef, NdefMessage, NdefRecord;

/// Service for handling NFC tag reading operations
class NFCService {
  /// Checks if NFC is available on the device
  Future<bool> isNFCAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  /// Starts an NFC session and reads a tag
  /// Returns the JSON payload as a string, or throws an exception on error
  Future<String> startNFCSession() async {
    // Check if NFC is available
    final isAvailable = await isNFCAvailable();
    if (!isAvailable) {
      throw NFCException('NFC is not available on this device');
    }

    // Use a Completer to wait for the callback results
    final completer = Completer<String>();

    try {
      await NfcManager.instance.startSession(
        // Polling options required in v4.0+
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            // Attempt to read the tag
            final payload = await readTag(tag);

            // If successful, stop the session
            await NfcManager.instance.stopSession();

            // Return the result via the completer
            if (!completer.isCompleted) {
              completer.complete(payload);
            }
          } catch (e) {
            // 'errorMessage' was renamed to 'errorMessageIos' in v4.0+
            await NfcManager.instance.stopSession(errorMessageIos: e.toString());

            // Return the error via the completer
            if (!completer.isCompleted) {
              completer.completeError(
                  e is Exception ? e : NFCException(e.toString()));
            }
          }
        },
      );
    } catch (e) {
      throw NFCException('Failed to start NFC session: $e');
    }

    // Wait here until the tag is scanned and processed
    return completer.future;
  }

  /// Reads an NFC tag and extracts the JSON payload from NDEF messages
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
        // FIX: Compare using the raw index value instead of NdefTypeNameFormat enum.
        // nfcWellKnown = 1 in the NdefTypeNameFormat enum across all versions.
        // This avoids the "getter 'NdefTypeNameFormat' isn't defined" compile error.
        if (record.typeNameFormat.index == 1) {
          final type = String.fromCharCodes(record.type);

          // 'T' = Text record type in NDEF Well Known format
          if (type == 'T') {
            final payload = record.payload;
            if (payload.isEmpty) continue;

            // First byte is the status byte:
            // bits 0-5 = language code length
            // bit 7    = encoding (0=UTF-8, 1=UTF-16)
            final statusByte = payload[0];
            final languageCodeLength = statusByte & 0x3F;
            final textStartIndex = 1 + languageCodeLength;

            if (payload.length <= textStartIndex) continue;

            final textBytes = payload.sublist(textStartIndex);
            final text = utf8.decode(textBytes);

            // Only return if the payload looks like a JSON object
            if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
              return text.trim();
            }
          }
        }
      } catch (e) {
        // Skip malformed records and try the next one
        continue;
      }
    }

    throw NFCException('No valid JSON payload found in NFC tag');
  }

  /// Stops the current NFC session
  Future<void> stopNFCSession() async {
    await NfcManager.instance.stopSession();
  }
}

class NFCException implements Exception {
  final String message;
  NFCException(this.message);

  @override
  String toString() => 'NFCException: $message';
}