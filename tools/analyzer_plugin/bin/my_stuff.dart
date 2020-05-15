
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/generator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer_plugin/src/utilities/navigation/navigation.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer_plugin/src/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/generator.dart';
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';

/// A mixin that can be used when creating a subclass of [ServerPlugin] and
/// mixing in [AssistsMixin]. This implements the creation of the assists request
/// based on the assumption that the driver being created is an [AnalysisDriver].
///
/// Clients may not extend or implement this class, but are allowed to use it as
/// a mix-in when creating a subclass of [ServerPlugin] that also uses
/// [AssistsMixin] as a mix-in.
abstract class MyDartAssistsMixin implements MyAssistsMixin {

  Future<ResolvedLibraryResult> getResolvedLibraryResult(String path) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    AnalysisDriverGeneric driver = driverForPath(path);
    if (driver is! AnalysisDriver) {
      // Return an error from the request.
      throw new RequestFailure(
          RequestErrorFactory.pluginError('Failed to analyze $path', null));
    }
    var result = await (driver as AnalysisDriver).getResolvedLibrary(path);
    ResultState state = result.state;
    if (state != ResultState.VALID) {
      // Return an error from the request.
      throw new RequestFailure(
          RequestErrorFactory.pluginError('Failed to analyze $path', null));
    }
    return result;
  }

  @override
  Future<AssistRequest> getAssistRequest(
      EditGetAssistsParams parameters) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    // ignore: omit_local_variable_types
    String path = parameters.file;
    // ignore: omit_local_variable_types
    ResolvedUnitResult result = await getResolvedUnitResult(path);
    var libRes = await getResolvedLibraryResult(path);
    var res = DartAssistRequestImpl(
        resourceProvider, parameters.offset, parameters.length, result);

    //res.setLib(libRes);
    return res;
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


/////////////////////////////7


/**
 * A mixin that can be used when creating a subclass of [ServerPlugin] to
 * provide most of the implementation for handling navigation requests.
 *
 * Clients may not implement this mixin, but are allowed to use it as a mix-in
 * when creating a subclass of [ServerPlugin].
 */
mixin MyNavigationMixin implements ServerPlugin {
  /// Return a list containing the navigation contributors that should be used to
  /// create navigation information for the file with the given [path]
  List<MyNavigationContributor> getNavigationContributors(String path);

  /// Return the navigation request that should be passes to the contributors
  /// returned from [getNavigationContributors].
  ///
  /// Throw a [RequestFailure] if the request could not be created.
  Future<NavigationRequest> getNavigationRequest(
      AnalysisGetNavigationParams parameters);

  @override
  Future<AnalysisGetNavigationResult> handleAnalysisGetNavigation(
      AnalysisGetNavigationParams parameters) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    var path = parameters.file;
    var request = await getNavigationRequest(parameters);
    var generator = MyNavigationGenerator(getNavigationContributors(path));
    var result = await generator.generateNavigationResponse(request);
    result.sendNotifications(channel);
    return result.result;
  }

  /// Send a navigation notification for the file with the given [path] to the
  /// server.
  @override
  Future<void> sendNavigationNotification(String path) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    try {
      var request = await getNavigationRequest(AnalysisGetNavigationParams(path, -1, -1));
      var generator = MyNavigationGenerator(getNavigationContributors(path));
      var generatorResult = generator.generateNavigationNotification(request);
      generatorResult.sendNotifications(channel);
    } on RequestFailure {
      // If we couldn't analyze the file, then don't send a notification.
    }
  }
}


/**
 * A mixin that can be used when creating a subclass of [ServerPlugin] and
 * mixing in [NavigationMixin]. This implements the creation of the navigation
 * request based on the assumption that the driver being created is an
 * [AnalysisDriver].
 *
 * Clients may not implement this mixin, but are allowed to use it as a mix-in
 * when creating a subclass of [ServerPlugin] that also uses [NavigationMixin]
 * as a mix-in.
 */
mixin MyDartNavigationMixin implements MyNavigationMixin {
  @override
  Future<NavigationRequest> getNavigationRequest(
      AnalysisGetNavigationParams parameters) async {
    // TODO(brianwilkerson) Determine whether this await is necessary.
    await null;
    var path = parameters.file;
    var result = await getResolvedUnitResult(path);
    var offset = parameters.offset;
    var length = parameters.length;
    if (offset < 0 && length < 0) {
      offset = 0;
      length = result.content.length;
    }
    return DartNavigationRequestImpl(
        resourceProvider, offset, length, result);
  }
}

/// An object used to produce navigation regions.
///
/// Clients may implement this class when implementing plugins.
abstract class MyNavigationContributor {
  /// Contribute navigation regions for the portion of the file specified by the
  /// given [request] into the given [collector].
  Future computeNavigation(
      NavigationRequest request, NavigationCollector collector);
}


/// A generator that will generate an 'analysis.navigation' notification.
///
/// Clients may not extend, implement or mix-in this class.
class MyNavigationGenerator {
  /// The contributors to be used to generate the navigation data.
  final List<MyNavigationContributor> contributors;

  /// Initialize a newly created navigation generator to use the given
  /// [contributors].
  MyNavigationGenerator(this.contributors);

  /// Create an 'analysis.navigation' notification for the portion of the file
  /// specified by the given [request]. If any of the contributors throws an
  /// exception, also create a non-fatal 'plugin.error' notification.
  GeneratorResult generateNavigationNotification(NavigationRequest request) {
    var notifications = <Notification>[];
    var collector = NavigationCollectorImpl();
    for (var contributor in contributors) {
      try {
        contributor.computeNavigation(request, collector);
      } catch (exception, stackTrace) {
        notifications.add(PluginErrorParams(
            false, exception.toString(), stackTrace.toString())
            .toNotification());
      }
    }
    collector.createRegions();
    notifications.add(AnalysisNavigationParams(
        request.path, collector.regions, collector.targets, collector.files)
        .toNotification());
    return GeneratorResult(null, notifications);
  }

  /// Create an 'analysis.getNavigation' response for the portion of the file
  /// specified by the given [request]. If any of the contributors throws an
  /// exception, also create a non-fatal 'plugin.error' notification.
  Future<GeneratorResult<AnalysisGetNavigationResult>> generateNavigationResponse(
      NavigationRequest request) async {
    var notifications = <Notification>[];
    var collector = NavigationCollectorImpl();
    for (var contributor in contributors) {
      try {
        await contributor.computeNavigation(request, collector);
      } catch (exception, stackTrace) {
        notifications.add(PluginErrorParams(
            false, exception.toString(), stackTrace.toString())
            .toNotification());
      }
    }
    collector.createRegions();
    var result = AnalysisGetNavigationResult(
        collector.files, collector.targets, collector.regions);
    return GeneratorResult(result, notifications);
  }
}