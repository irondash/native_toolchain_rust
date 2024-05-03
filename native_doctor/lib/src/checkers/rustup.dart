import 'package:collection/collection.dart';
import 'package:native_doctor/src/tool_error.dart';
import 'package:native_doctor/src/writer.dart';
import 'package:native_doctor/src/toolchain_checker.dart';
import 'package:native_doctor/src/native_doctor.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rustup/rustup.dart';
import 'package:yaml/yaml.dart';

class _RustToolchainRequirement {
  final String name;
  final Version minimalVersion;

  _RustToolchainRequirement({
    required this.name,
    required this.minimalVersion,
  });
}

class _RustToolchainValidationResult {
  _RustToolchainValidationResult({
    required this.name,
    this.installedVersion,
    this.requiredVersion,
    this.installedTargets = const [],
    this.missingTargets = const [],
  });

  bool get needInstall => installedVersion == null;
  bool get needUpdate =>
      installedVersion != null && installedVersion! < requiredVersion!;

  final String name;
  final Version? installedVersion;
  final Version? requiredVersion;
  final List<RustTarget> installedTargets;
  final List<RustTarget> missingTargets;

  ValidationResultSection toValidationResultSection(TextStyler styler) {
    return ValidationResultSection(
      ok: !needInstall && !needUpdate && missingTargets.isEmpty,
      title: needInstall
          ? 'Toolchain ${styler.bolden(name)} not installed'
          : 'Toolchain ${styler.bolden(name)} (version $installedVersion)',
      messages: [
        ValidationResultSectionMessage(
          ok: !needUpdate && !needInstall,
          message: 'Required minimum version: $requiredVersion',
        ),
        if (installedTargets.isNotEmpty)
          ValidationResultSectionMessage(
            ok: true,
            message: 'Installed targets: ${installedTargets.join(', ')}',
          ),
        if (missingTargets.isNotEmpty)
          ValidationResultSectionMessage(
            ok: false,
            message: 'Missing targets: ${missingTargets.join(', ')}',
          ),
      ],
    );
  }
}

class RustToolchainChecker extends ToolchainChecker {
  RustToolchainChecker({
    required this.doctor,
  });

  final NativeDoctor doctor;

  @override
  String get manifestKey => 'rust';

  @override
  String get displayName => 'Rust';

  final _requirements = <_RustToolchainRequirement>[];

  @override
  Future<void> updateFromManifest(
    ManifestContext context,
    YamlNode manifestNode,
  ) async {
    final info = RustManifestInfo.parse(manifestNode);
    for (final entry in info.toolchainToVersion.entries) {
      final existing =
          _requirements.firstWhereOrNull((r) => r.name == entry.key);
      if (existing == null || existing.minimalVersion < entry.value) {
        _requirements.removeWhere((r) => r.name == entry.key);
        _requirements.add(_RustToolchainRequirement(
          name: entry.key,
          minimalVersion: entry.value,
        ));
      }
    }
  }

  List<RustTarget> _requiredTargets() {
    // For host-only (i.e. dart packages) environment don't
    // require any targets.
    if (doctor.hostOnly) {
      return [];
    }
    final buildableSystems = doctor.targetPlatforms;
    return RustTarget.allTargets.where((t) {
      return buildableSystems.contains(t.os);
    }).toList(growable: false);
  }

  final results = <_RustToolchainValidationResult>[];

  @override
  Future<ValidationResult?> validate() async {
    if (_requirements.isEmpty) {
      // No package requires rust.
      return null;
    }
    final rustup = Rustup.systemRustup(logger: doctor.verboseLogger);
    final requiredTargets = _requiredTargets();
    for (final requirement in _requirements) {
      final toolchain = await rustup?.getToolchain(requirement.name);
      final installedVersion = await toolchain?.rustVersion();
      final targets = await toolchain?.installedTargets() ?? [];
      final missingTargets = requiredTargets.where((t) {
        return !targets.contains(t);
      }).toList(growable: false);
      results.add(
        _RustToolchainValidationResult(
          name: toolchain?.name ?? requirement.name,
          installedVersion: installedVersion,
          requiredVersion: requirement.minimalVersion,
          installedTargets: targets,
          missingTargets: missingTargets,
        ),
      );
    }

    return ValidationResult(sections: [
      if (rustup == null)
        ValidationResultSection(
          ok: false,
          title: 'Rustup not found',
          messages: [],
        ),
      if (rustup != null)
        ValidationResultSection(
          ok: true,
          title: 'Rustup installed',
          messages: [],
        ),
      for (final result in results)
        result.toValidationResultSection(doctor.writer),
    ], proposedActions: [
      if (rustup == null) ProposedAction(description: 'Install rustup'),
      if (results.any((r) => r.needUpdate))
        ProposedAction(description: 'Update Rust'),
      for (final result in results) ...[
        if (result.needInstall)
          ProposedAction(description: 'Install toolchain ${result.name}'),
        if (result.missingTargets.isNotEmpty)
          ProposedAction(
            description:
                'Install target${result.missingTargets.length > 1 ? 's' : ''} '
                '${result.missingTargets.join(', ')} '
                'for toolchain ${result.name}',
          ),
      ]
    ]);
  }

  @override
  Future<void> fix(ActionLogger logger) async {
    var rustup = Rustup.systemRustup(logger: doctor.verboseLogger);
    if (rustup == null) {
      await logger.logAction('Installing rustup', () async {
        final installer = await RustupInstaller.create();
        await installer.install();
        rustup = Rustup.systemRustup(logger: doctor.verboseLogger);
        if (rustup == null) {
          throw ToolError('Failed to install rustup');
        }
      });
    }

    bool needUpdate = false;
    for (final result in results) {
      needUpdate |= result.needUpdate;
      if (result.needInstall) {
        await logger.logAction('Installing Rust toolchain ${result.name}',
            () async {
          await rustup!.installToolchain(result.name);
          final toolchain = await rustup!.getToolchain(result.name);
          if (toolchain == null) {
            throw ToolError('Failed to install toolchain ${result.name}');
          }
        });
      }
      final toolchain = (await rustup!.getToolchain(result.name))!;
      for (final target in result.missingTargets) {
        await logger.logAction(
          'Installing target $target for toolchain ${result.name}',
          () async {
            await toolchain.installTarget(target);
          },
        );
      }
    }
    if (needUpdate) {
      await logger.logAction('Updating Rust', () async {
        await rustup!.runCommand(['update']);
      });
    }
  }
}
