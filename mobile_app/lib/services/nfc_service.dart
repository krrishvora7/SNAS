import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

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

    // Start NFC session and wait for tag
    String? payload;
    Exception? error;

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          payload = await readTag(tag);
          // Stop session after successful read
          await NfcManager.instance.stopSession();
        } catch (e) {
          error = e is Exception ? e : Exception(e.toString());
          await NfcManager.instance.stopSession(errorMessage: e.toString());
        }
      },
    );

    // If an error occurred during reading, throw it
    if (error != null) {
      throw error!;
    }

    // If no payload was read, throw an error
    if (payload == null) {
      throw NFCException('Failed to read NFC tag');
    }

    return payload!;
  }

  /// Reads an NFC tag and extracts the JSON payload from NDEF messages
  /// Returns the JSON string from the NDEF text record
  Future<String> readTag(NfcTag tag) async {
    // Try to read NDEF data
    final ndef = Ndef.from(tag);
    
    if (ndef == null) {
      throw NFCException('Tag does not contain NDEF data');
    }

    // Check if tag is empty
    final cachedMessage = ndef.cachedMessage;
    if (cachedMessage == null || cachedMessage.records.isEmpty) {
      throw NFCException('Tag is empty or unreadable');
    }

    // Parse NDEF records to find text record with JSON payload
    for (final record in cachedMessage.records) {
      try {
        // Check if this is a text record (TNF: 0x01, Type: "T")
        if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
          final type = String.fromCharCodes(record.type);
          
          if (type == 'T') {
            // Parse text record
            final payload = record.payload;
            
            // First byte contains status byte (language code length + encoding)
            if (payload.isEmpty) {
              continue;
            }
            
            final statusByte = payload[0];
            final languageCodeLength = statusByte & 0x3F; // Lower 6 bits
            
            // Skip status byte and language code to get actual text
            final textStartIndex = 1 + languageCodeLength;
            if (payload.length <= textStartIndex) {
              continue;
            }
            
            final textBytes = payload.sublist(textStartIndex);
            final text = utf8.decode(textBytes);
            
            // Validate that it looks like JSON
            if (text.trim().startsWith('{') && text.trim().endsWith('}')) {
              return text.trim();
            }
          }
        }
      } catch (e) {
        // Continue to next record if this one fails
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

/// Custom exception for NFC-related errors
class NFCException implements Exception {
  final String message;
  
  NFCException(this.message);
  
  @override
  String toString() => 'NFCException: $message';
}
