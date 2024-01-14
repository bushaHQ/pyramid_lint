import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:meta/meta.dart' show immutable;
import 'package:yaml/yaml.dart' show YamlList;

import '../../utils/constants.dart';

@immutable
class PreferLibraryPrefixesOptions {
  const PreferLibraryPrefixesOptions({
    bool? includeDefaultLibraries,
    List<String>? libraries,
  })  : _includeDefaultLibraries = includeDefaultLibraries ?? true,
        _libraries = libraries ?? const [];

  final bool _includeDefaultLibraries;
  final List<String> _libraries;

  static const defaultLibraries = [
    'dart:developer',
    'dart:math',
  ];

  List<String> get libraries => [
        if (_includeDefaultLibraries) ...defaultLibraries,
        ..._libraries,
      ];

  factory PreferLibraryPrefixesOptions.fromJson(Map<String, dynamic>? json) {
    final includeDefaultLibraries =
        switch (json?['include_default_libraries']) {
      final bool includeDefaultLibraries => includeDefaultLibraries,
      _ => null,
    };

    final libraries = switch (json?['libraries']) {
      final YamlList libraries => libraries.cast<String>(),
      _ => null,
    };

    return PreferLibraryPrefixesOptions(
      includeDefaultLibraries: includeDefaultLibraries,
      libraries: libraries,
    );
  }
}

class PreferLibraryPrefixes extends DartLintRule {
  const PreferLibraryPrefixes._(this.options)
      : super(
          code: const LintCode(
            name: name,
            problemMessage: 'Prefix should be used for this library.',
            correctionMessage: 'Consider adding a prefix to this library.',
            url: '$dartLintDocUrl/${PreferLibraryPrefixes.name}',
            errorSeverity: ErrorSeverity.INFO,
          ),
        );

  static const name = 'prefer_library_prefixes';

  final PreferLibraryPrefixesOptions options;

  factory PreferLibraryPrefixes.fromConfigs(CustomLintConfigs configs) {
    final options = PreferLibraryPrefixesOptions.fromJson(
      configs.rules[PreferLibraryPrefixes.name]?.json,
    );

    return PreferLibraryPrefixes._(options);
  }

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      if (!options.libraries.contains(uri)) return;

      final prefix = node.prefix;
      if (prefix != null) return;

      reporter.reportErrorForNode(code, node);
    });
  }

  @override
  List<Fix> getFixes() => [_AddPrefix()];
}

class _AddPrefix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addImportDirective((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final uri = node.uri.stringValue;
      if (uri == null) return;

      final uriSegments = uri.split(RegExp('[/:]'));
      if (uriSegments.isEmpty) return;

      final lastUriSegment = uriSegments.last.replaceAll('.dart', '');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add prefix to the library',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.uri.end,
          ' as $lastUriSegment',
        );
      });
    });
  }
}
