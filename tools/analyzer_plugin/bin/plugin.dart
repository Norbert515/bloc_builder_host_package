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
import 'my_stuff.dart';
import 'package:analyzer/dart/analysis/results.dart';




void main(List<String> args, SendPort sendPort) async {
  /*var builder = DartChangeBuilder(AnalysisSessionImpl(null));
  await builder.addFileEdit("asdasd", (builder) {
    builder.addDeletion(SourceRange(20, 10));
    builder.addSimpleInsertion(4, "Hello this is pretty!");
  });

  builder.sourceChange.message = 'HELLO THERE';
*/
  start(args, sendPort);

}

void start(List<String> args, SendPort sendPort) {
  ServerPluginStarter(MyPlugin(PhysicalResourceProvider.INSTANCE))
      .start(sendPort);
}
class MyPlugin extends ServerPlugin with MyAssistsMixin, MyDartAssistsMixin, NavigationMixin, DartNavigationMixin{
  MyPlugin(ResourceProvider provider) : super(provider) {
    testAssistContributor = TestAssistContributor(channel);
  }

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*.dart'];

  @override
  String get name => 'My fantastic plugin';

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

  TestAssistContributor testAssistContributor;
  @override
  List<MyAssistContributor> getAssistContributors(String path) {
    return [testAssistContributor];
  }

  @override
  List<NavigationContributor> getNavigationContributors(String path) {
    return <NavigationContributor>[MyNavigationContributor()];
  }
}

class TestAssistContributor extends Object
    with AssistContributorMixin
    implements MyAssistContributor {

  static AssistKind wrapInIf = AssistKind('wrapInIf', 100, "Wrap in an 'if' statement");

  DartAssistRequest request;

  final PluginCommunicationChannel channel;
  @override
  AssistCollector collector;

  TestAssistContributor(this.channel);

  AnalysisSession get session => request.result.session;

  //ResolvedUnitResult unitResult;

  @override
  Future<void> computeAssists(DartAssistRequest request, AssistCollector collector) async {
    this.request = request;
    this.collector = collector;
    await _wrapInIf();
    await _wrapInWhile();
  }

  Future _wrapInIf() async {
    ChangeBuilder builder = DartChangeBuilder(session);
    await builder.setSelection(plugin.Position(request.result.path, 0));
    await builder.addFileEdit(request.result.path, (builder) {
      builder.addDeletion(SourceRange(20, 10));
    });
    // TODO Build the edit to wrap the selection in a 'if' statement.
    addAssist(wrapInIf, builder);
  }

  Future<void> _wrapInWhile() async {


    var visitor = WrapVisitor(request.offset);

    /*
    if(unitResult == null) {
      channel.sendNotification(Notification("plugin.error", {
        'isFatal': false,
        "message": """
        Tried to access unitResult but it wasnt provided yet
      """,
      }));
      return;
    }*/
    request.result.unit.accept(visitor);

    if(visitor.it != null) {
      var literal = visitor.it;
      var builder = DartChangeBuilder(session);
      await builder.addFileEdit(request.result.path, (builder) {
        builder.addReplacement(SourceRange(literal.offset, literal.length), (builder) {
          builder.write(literal.value? "false": "true");
        });
      });
      addAssist(wrapInIf, builder);
    }
    /*
    channel.sendNotification(Notification("plugin.error", {
      'isFatal': false,
      "message": """
      ${builder.sourceChange.toJson()}
      --------------------------------
      ${builder.sourceChange.message}
      --------------------------------
      """,
    }));*/

  }
}


class WrapVisitor extends RecursiveAstVisitor {

  final int offset;

  WrapVisitor(this.offset);

  BooleanLiteral it;

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    if(offset > node.offset && offset < node.offset + node.length) {
      it = node;
    }
    return super.visitBooleanLiteral(node);
  }
}



class MyNavigationContributor implements NavigationContributor {
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