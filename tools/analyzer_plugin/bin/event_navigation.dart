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
import 'my_stuff.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/ast/ast.dart';
import 'package:analyzer/src/dart/element/handle.dart';
import 'package:analyzer/src/dart/element/member.dart';
import 'package:analyzer/src/dart/element/type_algebra.dart';
import 'package:analyzer/dart/element/visitor.dart';

class EventNavigationContributor implements MyNavigationContributor {

  @override
  Future computeNavigation (
      NavigationRequest request, NavigationCollector collector) async {
    if (request is DartNavigationRequest) {
      var visitor = EventVisitor(request.offset);
      request.result.unit.accept(visitor);
      String path = visitor.it.staticParameterElement.source.uri.path;

    }
  }
}

/*
class EventVisitor extends RecursiveElementVisitor {

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

}*/

class EventVisitor extends RecursiveAstVisitor {

  final int offset;

  InstanceCreationExpression it;

  EventVisitor(this.offset);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    //var isWidget = node.staticElement.enclosingElement.allSupertypes.where((it) => it.name == 'Widget').isNotEmpty;

    if(offset > node.offset && offset < node.offset + node.beginToken.length) {
      //if(isWidget) {
        it = node;
      //}
      return;
    }

    return super.visitInstanceCreationExpression(node);
  }
}