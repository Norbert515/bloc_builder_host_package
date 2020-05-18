import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/channel/channel.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/assist/assist.dart';
import 'package:analyzer_plugin/utilities/assist/assist_contributor_mixin.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'my_stuff.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';

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
    //await _control();
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


    var blocVisitor = BlocWrapperVisitor(request.offset);


    request.result.unit.accept(blocVisitor);

    var blocCollector = BlocCollector();
    for(var path in request.result.session.analysisContext.contextRoot.analyzedFiles().where((it) => it.endsWith(".dart"))) {
      var unitElement = await request.result.session.getResolvedUnit(path);
      if(!unitElement.isPart) {
        unitElement.libraryElement.accept(blocCollector);
      }
    }

    if(blocVisitor.it != null) {
      var literal = blocVisitor.it;
      var toWrap = request.result.content.substring(literal.offset, literal.end);
      var content = request.result.content;

      // The offset if the line start of this
      int startOfLine = offsetOfStartOfLine(content, literal.offset);

      // Number of empty characters until first character starting from startOfLine
      int empties = numberOfUntilFirstNonEmpty(content, startOfLine + 1);


      //debug("$startOfLine");
      //debug("$empties");

      var builder = DartChangeBuilder(session);
      await builder.addFileEdit(request.result.path, (builder) {

        builder.addReplacement(SourceRange(literal.offset, literal.length), (builder) {
          builder.write("BlocBuilder<");
          builder.addSimpleLinkedEdit(
              "test",
              "Bloc",
              kind: plugin.LinkedEditSuggestionKind.TYPE,
              suggestions: blocCollector.names.map((it) => it.bloc).toList());

          builder.write(", ");

          builder.addSimpleLinkedEdit(
              "test2",
              "State",
              kind: plugin.LinkedEditSuggestionKind.TYPE,
              suggestions: blocCollector.names.map((it) => it.state).toList());

          builder.writeln(">(");

          builder.writeln("${space(empties + 2)}builder: (context, state) {");
          builder.write("${space(empties + 4)}return ");
          builder.writeln(toWrap.split('\n').first);
          builder.write(addSpaceToEachLine(toWrap.split('\n').sublist(1).join('\n'), 4));
          builder.writeln(";");
          builder.writeln("${space(empties + 2)}},");
          builder.write("${space(empties)})");

        });
      });
      collectIt(100, 'Wrap in BlocBuilder', builder.sourceChange);
    }
  }

  String addSpaceToEachLine(String it, int spaces) {
    return it.split('\n').map((it) => space(spaces) + it).join('\n');

  }
  String space(int number) {
    return ' ' * number;
  }

  int numberOfUntilFirstNonEmpty(String content, int offset) {
    var start = offset;
    var num = 0;
    while(start < content.length) {
      if(content[start].trim().isNotEmpty) {
        //debug("This was the first: ${content[start]}");
        return num;
      }

      start++;
      num++;
    }

  }


  int offsetOfStartOfLine(String content, int offset) {
    var start = offset;
    while(start > 0) {
      if(content[start] == '\n') {
        return start;
      }

      start--;
    }
    return -1;
  }

  /*int offsetToStartOfLine(String content, int offset) {
    var index = offset;
    var tillBeginning = 0;
    while(index > 0) {
      index--;
      tillBeginning ++;
      if(request.result.content[index] == '\n') {
        return tillBeginning;

      }
    }
    return -1;
  }*/

  void debug(String it) {
    collectIt(10000000000, it, plugin.SourceChange(it));
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

class BlocAndState {
  final String bloc;
  final String state;

  BlocAndState(this.bloc, this.state);
}

class BlocCollector extends RecursiveElementVisitor {

  List<BlocAndState> names = [];

  bool isBlocSubclass(ClassElement element) {
    return element.supertype.element.name == "Bloc";
  }

  @override
  void visitClassElement(ClassElement element) {
    if(isBlocSubclass(element)) {
      var state = element.supertype.typeArguments[1].element.name;
      names.add(BlocAndState(element.name, state));
    }



    return super.visitClassElement(element);
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
      return;
    }

    return super.visitInstanceCreationExpression(node);
  }

}