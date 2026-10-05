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

/// The icons of the HTML report: outlines from the Lucide icon set (ISC
/// License), inlined so that the report loads nothing.
final class HtmlIcons {
  /// Prevents instantiation; this type only offers constants.
  const HtmlIcons._();

  /// A shield with a check mark, the logo.
  static const shield =
      '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 '
      '4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 '
      '3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>';

  /// A circle with a check mark: passed.
  static const passed =
      '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>';

  /// A circle with a cross: failed.
  static const failed =
      '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path '
      'd="m9 9 6 6"/>';

  /// A warning triangle: could not run.
  static const error =
      '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 '
      '0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>';

  /// A dashed circle: skipped.
  static const skipped =
      '<path d="M10.1 2.182a10 10 0 0 1 3.8 0"/><path d="M13.9 21.818a10 10 0 '
      '0 1-3.8 0"/><path d="M17.609 3.721a10 10 0 0 1 2.69 2.7"/><path '
      'd="M2.182 13.9a10 10 0 0 1 0-3.8"/><path d="M20.279 17.609a10 10 0 0 '
      '1-2.7 2.69"/><path d="M21.818 10.1a10 10 0 0 1 0 3.8"/><path '
      'd="M3.721 6.391a10 10 0 0 1 2.7-2.69"/><path d="M6.391 20.279a10 10 0 '
      '0 1-2.69-2.7"/>';

  /// Four tiles: the overview.
  static const dashboard =
      '<rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" '
      'height="5" x="14" y="3" rx="1"/><rect width="7" height="9" x="14" '
      'y="12" rx="1"/><rect width="7" height="5" x="3" y="16" rx="1"/>';

  /// A bulleted list: the findings.
  static const list =
      '<path d="M3 12h.01"/><path d="M3 18h.01"/><path d="M3 6h.01"/><path '
      'd="M8 12h13"/><path d="M8 18h13"/><path d="M8 6h13"/>';

  /// A file with code: the code base.
  static const code =
      '<path d="M10 12.5 8 15l2 2.5"/><path d="m14 12.5 2 2.5-2 2.5"/><path '
      'd="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M15 2H6a2 2 0 0 0-2 '
      '2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/>';

  /// Stacked layers: the evaluations.
  static const layers =
      '<path d="M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 '
      '3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83z"/><path d="m22 '
      '17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/><path d="m22 12.65-9.17 4.16a2 2 '
      '0 0 1-1.66 0L2 12.65"/>';

  /// A magnifier: search.
  static const search =
      '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>';

  /// A chevron pointing down: expand.
  static const chevron = '<path d="m6 9 6 6 6-6"/>';

  /// An arrow out of a box: an external link.
  static const external =
      '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 '
      '1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3"/>';

  /// Returns the icon [paths] as an SVG element with the class [name].
  static String svg(String paths, {String name = 'icon'}) =>
      '<svg class="$name" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round" aria-hidden="true">$paths</svg>';
}
