import 'dart:isolate';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer_plugin/plugin/assist_mixin.dart';
import 'package:analyzer_plugin/plugin/navigation_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer/src/dart/analysis/driver.dart'
    show AnalysisDriver, AnalysisDriverGeneric, AnalysisDriverScheduler;
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/protocol/protocol.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/assist/assist_contributor_mixin.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/context/context_root.dart';
import 'package:analyzer/src/context/builder.dart';
import 'bloc_builder.dart';
import 'event_navigation.dart';
import 'my_stuff.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/dart/element/visitor.dart';

abstract class Logger {
  void log(String msg);
}



void main(List<String> args, SendPort sendPort) async {
  start(args, sendPort);

}

void start(List<String> args, SendPort sendPort) {
  ServerPluginStarter(MyPlugin(PhysicalResourceProvider.INSTANCE))
      .start(sendPort);
}
class MyPlugin extends ServerPlugin with MyAssistsMixin, MyDartAssistsMixin, MyNavigationMixin, MyDartNavigationMixin implements Logger{
  MyPlugin(ResourceProvider provider) : super(provider) {
    testAssistContributor = TestAssistContributor(channel);
  }

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*.dart'];

  @override
  String get name => 'Bloc plugin';

  @override
  String get version => '1.0.0';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    var root = ContextRoot(contextRoot.root, contextRoot.exclude,
        pathContext: resourceProvider.pathContext)
      ..optionsFilePath = contextRoot.optionsFile;
    var contextBuilder = ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = analysisDriverScheduler
      ..byteStore = byteStore
      ..performanceLog = performanceLog
      ..fileContentOverlay = fileContentOverlay;
    var result = contextBuilder.buildDriver(root);
    result.results.listen(_processResult);
    return result;
  }

  @override
  void contentChanged(String path) {
    super.driverForPath(path).addFile(path);
  }

  void _processResult(ResolvedUnitResult result) {
    /*if(result.unit != null) {
      testAssistContributor.unitResult = result;
      channel.sendNotification(Notification("plugin.error", {
        'isFatal': false,
        "message": """
      Getting a new ResolvedUnitResult!
      """,
      }));
    }*/
  }

  @override
  void log(String msg) {
    channel.sendNotification(Notification('plugin.error', {
      'isFatal': false,
      'message': msg,
      'stackTrace': 'No Trace',
    }));

  }

  TestAssistContributor testAssistContributor;

  @override
  List<MyAssistContributor> getAssistContributors(String path) {
    return [testAssistContributor];
  }

  @override
  List<MyNavigationContributor> getNavigationContributors(String path) {
    return <MyNavigationContributor>[EventNavigationContributor(this)];
  }
}

class LOLMyNavigationContributor implements NavigationContributor {
  @override
  void computeNavigation(
      NavigationRequest request, NavigationCollector collector) {
    if (request is DartNavigationRequest) {
      var visitor = NavigationVisitor(collector, request.path);
      request.result.unit.accept(visitor);
    }
  }
}

class NavigationVisitor extends RecursiveAstVisitor {
  final NavigationCollector collector;

  final String path;
  NavigationVisitor(this.collector, this.path);

  @override
  void visitAssertInitializer(AssertInitializer node) {
    node.visitChildren(this);
    collector.addRegion(node.offset, node.length, plugin.ElementKind.FUNCTION, plugin.Location(path, 0,0,0,0));
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    collector.addRegion(node.offset, node.length, plugin.ElementKind.FUNCTION, plugin.Location(path, 0,0,0,0));
    //collector.addRegion(0, 5, ElementKind.CLASS, Location());
    // ...
  }
}