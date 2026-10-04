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

import 'package:args/args.dart';
import 'package:inspectra/src/changelog/changelog_generator.dart';
import 'package:inspectra/src/changelog/changelog_links.dart';
import 'package:inspectra/src/changelog/changelog_markdown.dart';
import 'package:inspectra/src/changelog/changelog_release.dart';
import 'package:inspectra/src/changelog/changelog_report.dart';
import 'package:inspectra/src/changelog/changelog_values.dart';
import 'package:inspectra/src/changelog/changelog_writer.dart';
import 'package:inspectra/src/changelog/git_history.dart';
import 'package:inspectra/src/cli/command_session.dart';
import 'package:inspectra/src/cli/inspectra_command.dart';
import 'package:inspectra/src/config/changelog_config.dart';
import 'package:inspectra/src/model/inspectra_exception.dart';
import 'package:inspectra/src/pub/pubspec.dart';
import 'package:inspectra/src/report/command_report.dart';

/// `inspectra changelog generate`: generates the changelog section of the
/// next release from the Conventional Commits since the latest release
/// tag, and with `--write` adds it to the changelog.
final class ChangelogGenerateCommand extends InspectraCommand {
  /// Creates the command.
  ChangelogGenerateCommand(super.context) {
    argParser
      ..addOption(
        'from',
        help:
            'Leave out the commits reachable from this revision '
            '(default: the latest release tag).',
        valueHelp: 'revision',
      )
      ..addOption(
        'to',
        help: 'Include the commits reachable from this revision.',
        defaultsTo: 'HEAD',
        valueHelp: 'revision',
      )
      ..addOption(
        'release',
        help:
            'The version to release (default: suggested from the commits '
            'by Semantic Versioning).',
        valueHelp: 'version',
      )
      ..addOption(
        'date',
        help: 'The release date (default: today).',
        valueHelp: 'YYYY-MM-DD',
      )
      ..addFlag(
        'write',
        negatable: false,
        help: 'Add the section to the changelog file.',
      );
  }

  /// The command name.
  @override
  String get name => 'generate';

  /// The one line description.
  @override
  String get description =>
      'Generate the changelog section of the next release from the Git '
      'history.';

  /// Generates the section and writes it when asked to.
  ///
  /// Returns the changelog report.
  @override
  Future<CommandReport> execute(
    CommandSession session,
    ArgResults results,
  ) async {
    final ChangelogConfig config = session.config.changelog;
    final String date = _date(session, results['date'] as String?);
    final history = GitHistory(
      processRunner: session.context.processRunner,
      workingDirectory: session.workingDirectory,
    );
    if (await history.isShallow()) {
      session.console.warning(
        'The repository is a shallow clone, so commits and release tags may '
        'be missing. Fetch the whole history, for example with '
        '"fetch-depth: 0" in actions/checkout.',
      );
    }
    final Pubspec? pubspec = session.pubspec();
    final ChangelogRelease release =
        await ChangelogGenerator(
          history: history,
          config: config,
          packageVersion: pubspec?.version,
        ).generate(
          date: date,
          to: results['to'] as String,
          from: results['from'] as String?,
          release: results['release'] as String?,
        );
    final String? repository = ChangelogLinks.normalizeRepository(
      config.repository ?? pubspec?.repository,
    );
    final String markdown = ChangelogMarkdown(
      links: repository == null
          ? null
          : ChangelogLinks(
              repository: repository,
              commitUrl: config.commitUrl,
              compareUrl: config.compareUrl,
            ),
    ).render(release);
    if (release.changes.isEmpty) {
      return ChangelogReport(release: release, markdown: markdown);
    }
    _describe(session, release, pubspec?.version);
    if (results['write'] != true) {
      return ChangelogReport(release: release, markdown: markdown);
    }
    final String path = session.resolve(config.file);
    const ChangelogWriter().write(path, release, markdown);
    return ChangelogReport(
      release: release,
      markdown: markdown,
      written: session.display(path),
    );
  }

  /// Reads the release date given with `--date` as [option], or today.
  ///
  /// Returns the date as `YYYY-MM-DD`.
  ///
  /// Throws an [InvalidUsageException] for anything but a valid date.
  String _date(CommandSession session, String? option) {
    if (option == null) {
      return formatIsoDate(session.context.clock.now());
    }
    if (!isIsoDate(option)) {
      throw InvalidUsageException(
        '"$option" is not a date in the form YYYY-MM-DD.',
      );
    }
    return option;
  }

  /// Tells the user where the version of [release] comes from and whether
  /// the [packageVersion] of `pubspec.yaml` still has to be updated.
  void _describe(
    CommandSession session,
    ChangelogRelease release,
    String? packageVersion,
  ) {
    final String? previous = release.previousTag;
    final int count = release.changes.length;
    final changes = '$count change${count == 1 ? '' : 's'}';
    final String size = release.changes.bump?.id ?? 'patch';
    session.console.info(
      previous == null
          ? 'Version ${release.version}: $changes, the first release.'
          : 'Version ${release.version}: $changes since $previous, a $size '
                'release.',
    );
    final bool outdated =
        packageVersion != null && packageVersion != release.version;
    if (outdated) {
      session.console.info(
        'pubspec.yaml declares version $packageVersion; set it to '
        '${release.version} before tagging ${release.tag}.',
      );
    }
  }
}
