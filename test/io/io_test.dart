/*
 * Copyright 2026 Redtronics
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

import 'dart:io';

import 'package:inspectra/inspectra.dart';
import 'package:inspectra/src/host/cpu_architecture.dart';
import 'package:inspectra/src/host/operating_system.dart';
import 'package:inspectra/src/io/ansi_styler.dart';
import 'package:inspectra/src/io/console.dart';
import 'package:inspectra/src/io/executable_resolver.dart';
import 'package:inspectra/src/io/verbosity.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Tests the console, colour detection, executable lookup and processes.
void main() {
  group('AnsiStyler', () {
    /// Detects colours for [variables] on an ANSI terminal.
    bool detect(Map<String, String> variables, {bool flag = false}) =>
        AnsiStyler.detect(
          environment: Environment(variables),
          noColorFlag: flag,
          hasTerminal: true,
          supportsAnsi: true,
        );

    test('honours --no-color, NO_COLOR, FORCE_COLOR and TERM=dumb', () {
      expect(detect(const <String, String>{}), isTrue);
      expect(detect(const <String, String>{}, flag: true), isFalse);
      expect(detect(<String, String>{'NO_COLOR': '1'}), isFalse);
      expect(detect(<String, String>{'TERM': 'dumb'}), isFalse);
      expect(
        AnsiStyler.detect(
          environment: const Environment(<String, String>{'FORCE_COLOR': '1'}),
          noColorFlag: false,
          hasTerminal: false,
          supportsAnsi: false,
        ),
        isTrue,
      );
    });

    test('decorates only when enabled', () {
      const on = AnsiStyler(enabled: true);
      const off = AnsiStyler(enabled: false);
      expect(on.red('x'), '\x1B[31mx\x1B[0m');
      expect(off.red('x'), 'x');
      for (final Severity severity in Severity.values) {
        expect(on.severityLabel(severity), contains(severity.label));
      }
      expect(on.green('a') + on.cyan('b') + on.dim('c'), contains('b'));
    });
  });

  test('Console separates reports from diagnostics by verbosity', () {
    final out = StringBuffer();
    final err = StringBuffer();
    Console(
        out: out,
        err: err,
        styler: const AnsiStyler(enabled: false),
        verbosity: Verbosity.quiet,
      )
      ..report('report')
      ..info('info')
      ..detail('detail')
      ..warning('warn')
      ..error('fail');
    expect('$out', 'report');
    expect('$err', 'warning: warn\nerror: fail\n');
    final verbose = StringBuffer();
    Console(
        out: StringBuffer(),
        err: verbose,
        styler: const AnsiStyler(enabled: false),
        verbosity: Verbosity.verbose,
      )
      ..info('info')
      ..detail('detail');
    expect('$verbose', 'info\ndetail\n');
  });

  group('ExecutableResolver', () {
    test('tries PATHEXT extensions on Windows', () {
      const resolver = ExecutableResolver(
        environment: Environment(<String, String>{'PATHEXT': '.EXE;.CMD'}),
        host: HostPlatform(OperatingSystem.windows, CpuArchitecture.x64),
      );
      expect(resolver.candidateNames('trivy'), <String>[
        'trivy.exe',
        'trivy.cmd',
        'trivy',
      ]);
    });

    test('finds executables on the PATH and in extra directories', () {
      final Directory directory = Directory.systemTemp.createTempSync(
        'resolver_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final tool = File(p.join(directory.path, 'tool'))..writeAsStringSync('x');
      final plain = File(p.join(directory.path, 'plain'))
        ..writeAsStringSync('x');
      if (!Platform.isWindows) {
        Process.runSync('chmod', <String>['755', tool.path]);
      }
      final resolver = ExecutableResolver(
        environment: const Environment(<String, String>{
          'PATH': '/nonexistent',
        }),
        host: HostPlatform.current(),
      );
      expect(
        resolver.resolve('tool', extraDirectories: <String>[directory.path]),
        tool.absolute.path,
      );
      expect(resolver.resolve('missing'), isNull);
      expect(resolver.resolve(tool.path), tool.absolute.path);
      if (!Platform.isWindows) {
        expect(resolver.resolve(plain.path), isNull);
      }
    });
  });

  group('SystemProcessRunner', () {
    test('runs a process and captures its output', () async {
      final ProcessOutcome outcome = await const SystemProcessRunner().run(
        Platform.resolvedExecutable,
        const <String>['--version'],
      );
      expect(outcome.succeeded, isTrue);
      expect('${outcome.stdout}${outcome.stderr}', contains('Dart'));
    });

    test('kills processes that exceed the timeout', () async {
      final script =
          File(
            '${Directory.systemTemp.createTempSync('runner_').path}/sleep.dart',
          )..writeAsStringSync(
            'Future<void> main() => Future.delayed(Duration(minutes: 5));',
          );
      final ProcessOutcome outcome = await const SystemProcessRunner().run(
        Platform.resolvedExecutable,
        <String>['run', script.path],
        timeout: const Duration(milliseconds: 500),
      );
      expect(outcome.exitCode, SystemProcessRunner.timedOutExitCode);
      expect(outcome.stderr, contains('killed'));
    });

    test('reports missing executables as ProcessException', () {
      expect(
        () => const SystemProcessRunner().run('no-such-tool-x', const []),
        throwsA(isA<ProcessException>()),
      );
    });
  });

  test('the system context wraps the real process', () {
    final context = CommandContext.system();
    expect(context.workingDirectory, Directory.current.path);
    expect(context.clock.now().isUtc, isTrue);
  });
}
