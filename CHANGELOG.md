# Changelog

## [2.0.0](https://github.com/nwarila-platform/windows-certificate-store-exporter/compare/windows-certificate-store-exporter-v1.0.0...windows-certificate-store-exporter-v2.0.0) (2026-06-23)


### ⚠ BREAKING CHANGES

* the default -StoreName is now Root only; CA is an explicit, warned opt-in. Consumers that relied on the previous Root,CA default (which also exported intermediate CA certificates) must now pass -StoreName Root,CA (or -StoreName CA) to keep that behavior. Intermediates in a flat trust bundle are promoted to standalone trust anchors by partial-chain consumers (Python 3.13+, curl >=7.68); root-only is the safe default.

### Bug Fixes

* **export:** default StoreName to Root-only trust anchors ([#72](https://github.com/nwarila-platform/windows-certificate-store-exporter/issues/72)) ([377d8d7](https://github.com/nwarila-platform/windows-certificate-store-exporter/commit/377d8d70a06e81ec7edbc9070ea05fcc28f264c2))
* **pem:** escape non-BMP distinguished-name characters as full UTF-8 scalars ([#75](https://github.com/nwarila-platform/windows-certificate-store-exporter/issues/75)) ([eead911](https://github.com/nwarila-platform/windows-certificate-store-exporter/commit/eead91194c33ddc7dfcf0a35188c419adc52472a))
* **write:** fail closed on stale sha256 sidecar ([#69](https://github.com/nwarila-platform/windows-certificate-store-exporter/issues/69)) ([07672d3](https://github.com/nwarila-platform/windows-certificate-store-exporter/commit/07672d391fd218131f961bb6f72790957f2225ff))
* **write:** roll back the bundle atomically when the manifest swap fails ([#74](https://github.com/nwarila-platform/windows-certificate-store-exporter/issues/74)) ([40d9719](https://github.com/nwarila-platform/windows-certificate-store-exporter/commit/40d97197119f84f6327e8273e03b49dd6d96c432))


### Miscellaneous Chores

* release windows-certificate-store-exporter 2.0.0 ([#77](https://github.com/nwarila-platform/windows-certificate-store-exporter/issues/77)) ([074f106](https://github.com/nwarila-platform/windows-certificate-store-exporter/commit/074f10685688e75f916f21bedca919def69ddc82))

## 1.0.0 (2026-06-19)

Initial release of `Export-CertificateStoreBundle.ps1`.
