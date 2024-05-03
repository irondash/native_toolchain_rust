import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

class ManifestContext {
  ManifestContext({
    required this.manifestVersion,
  });

  final Version manifestVersion;
}

class ValidationResultSectionMessage {
  ValidationResultSectionMessage({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class ValidationResultSection {
  ValidationResultSection({
    required this.ok,
    required this.title,
    required this.messages,
  });

  final bool ok;
  final String title;
  final List<ValidationResultSectionMessage> messages;
}

class ProposedAction {
  ProposedAction({required this.description});

  final String description;
}

class ValidationResult {
  final List<ValidationResultSection> sections;
  final List<ProposedAction> proposedActions;

  ValidationResult({
    required this.sections,
    required this.proposedActions,
  });
}

abstract class ActionLogger {
  Future<void> logAction(String message, Future<void> Function() action);
}

abstract class ToolchainChecker {
  String get manifestKey;
  String get displayName;

  Future<void> updateFromManifest(
    ManifestContext context,
    YamlNode manifestNode,
  );

  Future<ValidationResult?> validate();
  Future<void> fix(ActionLogger logger);
}
