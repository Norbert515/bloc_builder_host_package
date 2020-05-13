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
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';




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
  static AssistKind wrapInIf2 = AssistKind('wrapInIf2', 100, "Wrap in an 'if' statement");

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
    await _control();
    await _wrapInWhile();
  }

  Future _control() async {
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
    var blocVisitor = BlocWrapperVisitor(request.offset);

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
    request.result.unit.accept(blocVisitor);

    if(blocVisitor.it != null) {
      var literal = blocVisitor.it;
      var toWrap = request.result.content.substring(literal.offset, literal.end);


      int offset = offsetToStartOfLine(request.result.content, literal.offset);

      var space = ' ' * offset;




      var builder = DartChangeBuilder(session);
      await builder.addFileEdit(request.result.path, (builder) {
        builder.addReplacement(SourceRange(literal.offset, literal.length), (builder) {
          /*var conElement = ConstructorMember(ConstructorElementImpl("Bloc<>", -1), Substitution.fromMap({
            TypeParameterElementImpl("builder", -1):null
          }));*/
          //conElement.constantInitializers = [];
          //builder.writeReference(conElement);
          builder.writeln("BlocBuilder<void, void>(");
          builder.writeln("$space  builder: (context, state) {");
          builder.write("$space    return ");
          builder.write(toWrap);
          builder.writeln(";");
          builder.writeln("},");
          builder.writeln("),");
        });
      });
      collectIt(100, 'Wrap in BlocBuilder', builder.sourceChange);
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

  int offsetToStartOfLine(String content, int offset) {
    int index = offset;
    int tillBeginning = 0;
    while(index > 0) {
      index--;
      tillBeginning ++;
      if(request.result.content[index] == "\n") {
        return tillBeginning;

      }
    }
  }


  void collectIt(int prio, String msg, plugin.SourceChange sourceChange) {
    collector.addAssist(plugin.PrioritizedSourceChange(prio, plugin.SourceChange(
        msg,
        edits: sourceChange.edits,
        linkedEditGroups: sourceChange.linkedEditGroups,
        selection: sourceChange.selection,
        id: "uhm, what id?"
    )));
  }
}

class BlocWrapperVisitor extends RecursiveAstVisitor {

  final int offset;

  InstanceCreationExpression it;

  BlocWrapperVisitor(this.offset);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var isWidget = node.staticElement.enclosingElement.allSupertypes.where((it) => it.name == 'Widget').isNotEmpty;

    if(offset > node.offset && offset < node.offset + node.beginToken.length) {
      if(isWidget) {
        it = node;
      }
    }

    return super.visitInstanceCreationExpression(node);
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