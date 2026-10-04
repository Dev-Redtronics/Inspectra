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

/// Network settings shared by every remote call Inspectra makes.
///
/// Corresponds to the `network:` section of `inspectra.yaml`. Every value can
/// also be set through `INSPECTRA_NETWORK_<KEY>` environment variables or the
/// `--set network.<key>=<value>` flag.
final class NetworkConfig {
  /// Creates network settings; every parameter has a production default.
  const NetworkConfig({
    this.offline = false,
    this.timeout = const Duration(seconds: 30),
    this.maxAttempts = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.concurrency = 8,
    this.proxy,
    this.caCertificates,
    this.osvUrl = defaultOsvUrl,
    this.pubHostedUrl = defaultPubHostedUrl,
  });

  /// The public OSV.dev API endpoint.
  static const String defaultOsvUrl = 'https://api.osv.dev';

  /// The public pub.dev package repository.
  static const String defaultPubHostedUrl = 'https://pub.dev';

  /// When `true`, no network connection is opened at all.
  ///
  /// Commands that cannot work without the network fail with exit code `69`;
  /// optional steps such as downloading Trivy are skipped.
  final bool offline;

  /// The timeout applied to connecting and to each response.
  final Duration timeout;

  /// How often a request is attempted before giving up, at least one.
  final int maxAttempts;

  /// The initial back-off delay; it doubles with every retry.
  final Duration retryBaseDelay;

  /// The maximum number of concurrent requests to a single service.
  final int concurrency;

  /// An explicit proxy such as `http://proxy.corp:3128`.
  ///
  /// When `null`, the standard `HTTPS_PROXY`, `HTTP_PROXY` and `NO_PROXY`
  /// variables are honoured.
  final String? proxy;

  /// A PEM file with additional trusted certificate authorities, for
  /// corporate proxies that intercept TLS.
  final String? caCertificates;

  /// The OSV.dev compatible API base URL, for example an internal mirror.
  final String osvUrl;

  /// The pub repository base URL, taken from `PUB_HOSTED_URL` by default.
  final String pubHostedUrl;
}
