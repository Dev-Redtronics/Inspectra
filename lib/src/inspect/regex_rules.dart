/*
 * Copyright 2026 Davils
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:inspectra/src/inspect/regex_rule.dart';
import 'package:inspectra/src/model/severity.dart';

/// The built-in pattern rules of the source inspector.
///
/// The first fourteen rules keep the identifiers of `dart_audit` so that
/// existing ignore lists keep working. Compared to `dart_audit`:
///
/// * the URL rule checks the exact host instead of a prefix, so
///   `https://github.com.evil.io` is no longer considered trusted;
/// * `BASE64_EVAL` and `DATA_EXFIL` really span lines;
/// * `PROCESS_RUN` also covers `Process.runSync`;
/// * the crypto mining rule no longer fires on the word "monero" in prose;
/// * two rules cover shell and PowerShell scripts shipped in packages.
final class RegexRules {
  /// Prevents instantiation; this type only offers the rule list.
  const RegexRules._();

  /// Dart source files.
  static const _dart = <String>{'.dart'};

  /// Script files that can be executed on a developer machine.
  static const _scripts = <String>{
    '.sh',
    '.bash',
    '.zsh',
    '.ps1',
    '.bat',
    '.cmd',
    '.py',
    '.js',
    '.rb',
  };

  /// Dart sources and scripts.
  static const _all = <String>{..._dart, ..._scripts};

  /// The rules in evaluation order.
  static final all = <RegexRule>[
    RegexRule(
      id: 'HARDCODED_URL',
      pattern: r'''https?://[^\s'"`<>)\]]{10,}''',
      severity: Severity.high,
      description: 'URL hardcoded to unknown domain',
      extensions: _all,
      checksHost: true,
    ),
    RegexRule(
      id: 'RAW_SOCKET',
      pattern: r'RawSocket\.|ServerSocket\.|Socket\.connect',
      severity: Severity.high,
      description: 'Raw socket usage (may be legitimate — verify context)',
      extensions: _dart,
    ),
    RegexRule(
      id: 'PROCESS_RUN',
      pattern: r'Process\.(?:run|runSync|start)\s*\(',
      severity: Severity.critical,
      description: 'OS process execution',
      extensions: _dart,
    ),
    RegexRule(
      id: 'SHELL_INJECTION',
      pattern: r'''Process\.(?:run|runSync|start)\s*\(\s*['"](?:bash|sh|cmd|powershell|pwsh|zsh|/bin/)''',
      severity: Severity.critical,
      description: 'Direct shell invocation',
      extensions: _dart,
    ),
    RegexRule(
      id: 'SENSITIVE_FILE_ACCESS',
      pattern: r'''File\s*\(\s*['"](?:/etc/|/proc/|~?/\.ssh/|~?/\.aws/|~?/\.config/gcloud|C:\\Windows\\|[^'"]*AppData\\)''',
      severity: Severity.high,
      description: 'Access to sensitive system path',
      extensions: _dart,
    ),
    RegexRule(
      id: 'HEX_ENCODING',
      pattern: r'(?:\\x[0-9a-fA-F]{2}){4,}',
      severity: Severity.medium,
      description: 'Hex-encoded byte sequence (≥4 consecutive bytes)',
      extensions: _dart,
    ),
    RegexRule(
      id: 'BASE64_EVAL',
      pattern: r'base64(?:Decode|\.decode)[\s\S]{0,200}?(?:Isolate\.spawn|loadLibrary|Process\.)',
      severity: Severity.high,
      description: 'Base64-decoded data used with dynamic code execution',
      extensions: _dart,
      wholeFile: true,
    ),
    RegexRule(
      id: 'UNICODE_ESCAPE',
      pattern: r'(?:\\u[0-9a-fA-F]{4}){4,}',
      severity: Severity.medium,
      description:
          'Multiple consecutive unicode escapes (possible obfuscation)',
      extensions: _dart,
    ),
    RegexRule(
      id: 'CHAR_CODE_CONCAT',
      pattern: r'String\.fromCharCodes?\s*\(.+\)\s*\+',
      severity: Severity.medium,
      description: 'String construction from concatenated char codes',
      extensions: _dart,
    ),
    RegexRule(
      id: 'CRYPTO_MINING',
      pattern:
          r'stratum\+(?:tcp|ssl)://|mining\.pool|coinhive|xmrig|cryptonight',
      severity: Severity.critical,
      description: 'Cryptomining-related keyword',
      extensions: _all,
    ),
    RegexRule(
      id: 'BACKDOOR_PATTERNS',
      pattern: r'reverse.?shell|bind.?shell|/dev/tcp/|\bnetcat\b|\bnc\s+-e\b',
      severity: Severity.critical,
      description: 'Backdoor or reverse-shell pattern',
      extensions: _all,
    ),
    RegexRule(
      id: 'DATA_EXFIL',
      pattern: r'(?:SharedPreferences|FlutterSecureStorage|Keychain)[\s\S]{0,200}?https?://',
      severity: Severity.high,
      description: 'Stored data potentially sent to external URL',
      extensions: _dart,
      wholeFile: true,
    ),
    RegexRule(
      id: 'DYNAMIC_LIBRARY',
      pattern: r'DynamicLibrary\.open\s*\(',
      severity: Severity.high,
      description: 'Dynamic native library loading',
      extensions: _dart,
    ),
    RegexRule(
      id: 'ISOLATE_SPAWN_URI',
      pattern: r'Isolate\.spawnUri\s*\(',
      severity: Severity.high,
      description: 'Remote code loading via Isolate.spawnUri',
      extensions: _dart,
    ),
    RegexRule(
      id: 'DOWNLOAD_AND_EXECUTE',
      pattern: r'(?:curl|wget|iwr|Invoke-WebRequest)\b[^|\n]*\|\s*(?:sh|bash|zsh|iex|Invoke-Expression)\b',
      severity: Severity.critical,
      description: 'Downloads a script and pipes it into a shell',
      extensions: _scripts,
    ),
    RegexRule(
      id: 'ENCODED_POWERSHELL',
      pattern: r'-(?:e|enc|encodedcommand)\s+[A-Za-z0-9+/=]{20,}',
      severity: Severity.high,
      description: 'Runs a Base64 encoded PowerShell command',
      extensions: _scripts,
    ),
  ];
}
