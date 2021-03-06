// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bignum/bignum.dart';

import 'signing.dart';

// Magic string we put at the top of all bundle files.
const String kBundleMagic = '#!mojo mojo:sky_viewer\n';

// Prefix of the above, used when reading bundle files. This allows us to be
// more flexbile about what we accept.
const String kBundleMagicPrefix = '#!mojo ';

Future<List<int>> _readBytesWithLength(RandomAccessFile file) async {
  ByteData buffer = new ByteData(4);
  await file.readInto(buffer.buffer.asUint8List());
  int length = buffer.getUint32(0, Endianness.LITTLE_ENDIAN);
  return await file.read(length);
}

const int kMaxLineLen = 10*1024;
const int kNewline = 0x0A;
Future<String> _readLine(RandomAccessFile file) async {
  String line = '';
  while (line.length < kMaxLineLen) {
    int byte = await file.readByte();
    if (byte == -1 || byte == kNewline)
      break;
    line += new String.fromCharCode(byte);
  }
  return line;
}

// Writes a 32-bit length followed by the content of [bytes].
void _writeBytesWithLengthSync(File outputFile, List<int> bytes) {
  if (bytes == null)
    bytes = new Uint8List(0);
  assert(bytes.length < 0xffffffff);
  ByteData length = new ByteData(4)..setUint32(0, bytes.length, Endianness.LITTLE_ENDIAN);
  outputFile.writeAsBytesSync(length.buffer.asUint8List(), mode: FileMode.APPEND);
  outputFile.writeAsBytesSync(bytes, mode: FileMode.APPEND);
}

// Represents a parsed .flx Bundle. Contains information from the bundle's
// header, as well as an open File handle positioned where the zip content
// begins.
// The bundle format is:
// #!mojo <any string>\n
// <32-bit length><signature of the manifest data>
// <32-bit length><manifest data>
// <zip content>
//
// The manifest is a JSON string containing the following keys:
// (optional) name: the name of the package.
// version: the package version.
// update-url: the base URL to download a new manifest and bundle.
// key: a BASE-64 encoded DER-encoded ASN.1 representation of the Q point of the
//   ECDSA public key that was used to sign this manifest.
// content-hash: an integer SHA-256 hash value of the <zip content>.
class Bundle {
  Bundle._fromFile(this.path);
  Bundle.fromContent({
    this.path,
    this.manifest,
    contentBytes,
    KeyPair keyPair: null
  }) : _contentBytes = contentBytes {
    assert(path != null);
    assert(manifest != null);
    assert(_contentBytes != null);
    manifestBytes = serializeManifest(manifest, keyPair?.publicKey, _contentBytes);
    signatureBytes = signManifest(manifestBytes, keyPair?.privateKey);
  }

  final String path;
  List<int> signatureBytes;
  List<int> manifestBytes;
  Map<String, dynamic> manifest;

  // File byte offset of the start of the zip content. Only valid when opened
  // from a file.
  int _contentOffset;

  // Zip content bytes. Only valid when created in memory.
  List<int> _contentBytes;

  Future<bool> _readHeader() async {
    RandomAccessFile file = await new File(path).open();
    String magic = await _readLine(file);
    if (!magic.startsWith(kBundleMagicPrefix)) {
      file.close();
      return false;
    }
    signatureBytes = await _readBytesWithLength(file);
    manifestBytes = await _readBytesWithLength(file);
    _contentOffset = await file.position();
    file.close();

    String manifestString = UTF8.decode(manifestBytes);
    manifest = JSON.decode(manifestString);
    return true;
  }

  static Future<Bundle> readHeader(String path) async {
    Bundle bundle = new Bundle._fromFile(path);
    if (!await bundle._readHeader())
      return null;
    return bundle;
  }

  // When opened from a file, verifies that the package has a valid signature
  // and content.
  Future<bool> verifyContent() async {
    assert(_contentOffset != null);
    if (!verifyManifestSignature(manifest, manifestBytes, signatureBytes))
      return false;

    Stream<List<int>> content = await new File(path).openRead(_contentOffset);
    BigInteger expectedHash = new BigInteger(manifest['content-hash'], 10);
    if (!await verifyContentHash(expectedHash, content))
      return false;

    return true;
  }

  // Writes the in-memory representation to disk.
  void writeSync() {
    assert(_contentBytes != null);
    File outputFile = new File(path);
    outputFile.writeAsStringSync('#!mojo mojo:sky_viewer\n');
    _writeBytesWithLengthSync(outputFile, signatureBytes);
    _writeBytesWithLengthSync(outputFile, manifestBytes);
    outputFile.writeAsBytesSync(_contentBytes, mode: FileMode.APPEND, flush: true);
  }
}
