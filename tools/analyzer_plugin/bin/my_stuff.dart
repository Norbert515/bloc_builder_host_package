
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/generator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/src/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/generator.dart';

/// A mixin that can be used when creating a subclass of [ServerPlugin] and
/// mixing in [AssistsMixin]. This implements the creation of the assists request
/// based on the assumption that the driver being created is an [AnalysisDriver].
///
/// Clients may not extend or implement this class, but are allowed to use it as
/// a mix-in when creating a subclass of [ServerPlugin] that also uses
/// [AssistsMixin] as a mix-in.
abstract class MyDartAssistsMixin implements MyAssistsMixin {
  @override
  Future<AssistRequest> getAssistRequest(
      EditGetAssistsParams parameters) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    // ignore: omit_local_variable_types
    String path = parameters.file;
    // ignore: omit_local_variable_types
    ResolvedUnitResult result = await getResolvedUnitResult(path);
    return DartAssistRequestImpl(
        resourceProvider, parameters.offset, parameters.length, result);
  }
}


mixin MyAssistsMixin implements ServerPlugin {
  /// Return a list containing the assist contributors that should be used to
  /// create assists for the file with the given [path].
  List<MyAssistContributor> getAssistContributors(String path);

  /// Return the assist request that should be passes to the contributors
  /// returned from [getAssistContributors].
  ///
  /// Throw a [RequestFailure] if the request could not be created.
  Future<AssistRequest> getAssistRequest(EditGetAssistsParams parameters);

  @override
  Future<EditGetAssistsResult> handleEditGetAssists(
      EditGetAssistsParams parameters) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    // ignore: omit_local_variable_types
    String path = parameters.file;
    // ignore: omit_local_variable_types
    AssistRequest request = await getAssistRequest(parameters);
    // ignore: omit_local_variable_types
    MyAssistGenerator generator = MyAssistGenerator(getAssistContributors(path));
    // ignore: omit_local_variable_types
    GeneratorResult<EditGetAssistsResult> result = await generator.generateAssistsResponse(request);
    result.sendNotifications(channel);
    return result.result;
  }
}

abstract class MyAssistContributor {
  /// Contribute assists for the location in the file specified by the given
  /// [request] into the given [collector].
  Future<void> computeAssists(
      covariant AssistRequest request, AssistCollector collector);
}

/// A generator that will generate an 'edit.getAssists' response.
///
/// Clients may not extend, implement or mix-in this class.
class MyAssistGenerator {
  /// The contributors to be used to generate the assists.
  final List<MyAssistContributor> contributors;

  /// Initialize a newly created assists generator to use the given
  /// [contributors].
  MyAssistGenerator(this.contributors);

  /// Create an 'edit.getAssists' response for the location in the file specified
  /// by the given [request]. If any of the contributors throws an exception,
  /// also create a non-fatal 'plugin.error' notification.
  Future<GeneratorResult<EditGetAssistsResult>> generateAssistsResponse(
      AssistRequest request) async {
    // ignore: omit_local_variable_types
    List<Notification> notifications = <Notification>[];
    // ignore: omit_local_variable_types
    AssistCollectorImpl collector = AssistCollectorImpl();
    // ignore: omit_local_variable_types
    for (MyAssistContributor contributor in contributors) {
      try {
        await contributor.computeAssists(request, collector);
      } catch (exception, stackTrace) {
        notifications.add(PluginErrorParams(
            false, exception.toString(), stackTrace.toString())
            .toNotification());
      }
    }
    // ignore: omit_local_variable_types
    EditGetAssistsResult result = EditGetAssistsResult(collector.assists);
    return GeneratorResult(result, notifications);
  }
}