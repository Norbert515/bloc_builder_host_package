import 'dart:convert';
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
import 'package:analyzer/src/source/source_resource.dart';
import 'plugin.dart';
import 'dart:io' as io;

class EventNavigationContributor implements MyNavigationContributor {
  final Logger logger;

  EventNavigationContributor(this.logger);
  @override
  Future computeNavigation(NavigationRequest request, NavigationCollector collector) async {
    if (request is DartNavigationRequest) {

      logger.log('Starting!');
      logger.log('Again!!');
      logger.log('Seaching for ${request.offset} ${request.length}');

      // This request can also be for the whole file!!!!!!!!!!!!!!!!

      var visitor = EventVisitor(request.offset, request.length, logger);
      request.result.unit.accept(visitor);

      for (var it in visitor.foundElements) {

        var constructorName = it.beginToken.lexeme;
        logger.log('constructorName: $constructorName');
        var blocStateCollector = BlocStateCollector(constructorName, logger);

        for (var path
            in request.result.session.analysisContext.contextRoot.analyzedFiles().where((it) => it.endsWith(".dart"))) {
          var unitElement = await request.result.session.getResolvedUnit(path);
          if (!unitElement.isPart) {
            logger.log('Analyzing $path ....');
            unitElement.libraryElement.accept(blocStateCollector);
          }
        }

        var searchBlocWithType = SearchBlocWithEventType(blocStateCollector.superTypes, logger);

        for (var path
        in request.result.session.analysisContext.contextRoot.analyzedFiles().where((it) => it.endsWith(".dart"))) {
          var unitElement = await request.result.session.getResolvedUnit(path);
          if (!unitElement.isPart) {
            logger.log('Analyzing $path ....');
            unitElement.libraryElement.accept(searchBlocWithType);
          }
        }

        if (searchBlocWithType.bloc != null) {
          logger.log("We are getting close!");
          // This is indeed an event
          var eventName = constructorName;
          var methodFinder = MethodFinderAST(eventName, logger);

          var blocPath = (searchBlocWithType.bloc.source as FileSource).file.path;
          logger.log("Now doing the last stage at $blocPath");
          var blocUnit = await request.result.session.getResolvedUnit(blocPath);

          blocUnit.unit.accept(methodFinder);


          var location = methodFinder.location..file = blocPath;

          logger.log("${it.offset} + ${it.length}");
          logger.log(json.encode(location.toJson()));
          // BUT NOT THIS!?!??!
          //collector.addRegion(it.offset, it.length, plugin.ElementKind.FUNCTION, location);
          // WHY DOES THIS WORK
          var visitor2 = ItNavigationVisitor(collector, request.path, logger, eventName, location);
          request.result.unit.accept(visitor2);
        }
      }

    }
  }
}

class ItNavigationVisitor extends RecursiveAstVisitor {
  final NavigationCollector collector;

  final String path;
  final Logger logger;
  final String name;
  final plugin.Location location;
  ItNavigationVisitor(this.collector, this.path, this.logger, this.name, this.location);

  //final String haha = "C:\\Users\\Norbert\\workspace\\analysis_plugin\\bloc_builder_test_project\\lib\\test\\test_bloc.dart";

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    logger.log("Visiting ${node.name}");
    //if(node.name == name) {
    // TODO doing this doesnt make any sense, but I've literally been debuggin this for countless hours and I wasn't able
    // to find another fix
    if(node.name == name){
      //var file = io.File(path);
      //file.writeAsStringSync("//contents");

      //collector.addRegion(node.offset, node.length, plugin.ElementKind.FUNCTION, location);
      collector.addRegion(
          node.offset, node.length, plugin.ElementKind.FUNCTION, location);
      //logger.log("${json.encode(plugin.Location(path, 0, 0,0,0).toJson())}");
      //logger.log("Offset: ${node.offset} + Length: ${node.length}");
      //logger.log("DOING THE THING");

    }
    //collector.addRegion(0, 5, ElementKind.CLASS, Location());
    // ...
  }
}

class IsFinder extends RecursiveAstVisitor {
  final String eventName;
  plugin.Location location;

  final Logger logger;
  IsFinder(this.eventName, this.logger);

  @override
  visitIsExpression(IsExpression node) {
    logger.log("Visiting ${node.type.beginToken.lexeme}");
    logger.log("And event Name is $eventName");
    if (node.type.beginToken.lexeme == eventName) {
      var type = node.type;
      //token = node.type.beginToken;
      logger.log("Hurray we found the locaotion");
      location = plugin.Location(
        "",
        type.offset,
        type.length,
        0,
        0,
      );
      return;
    }
    return super.visitIsExpression(node);
  }
}

class MethodFinderAST extends RecursiveAstVisitor {
  final Logger logger;
  final String eventName;
  plugin.Location location;

  MethodFinderAST(this.eventName, this.logger);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    var finder = IsFinder(eventName, logger);
    var method = node.getMethod("mapEventToState")?.accept(finder);
    location = finder.location;
    return super.visitClassDeclaration(node);
  }
}

class EventVisitor extends RecursiveAstVisitor {
  final int offset;
  final int length;
  final Logger logger;

  List<InstanceCreationExpression> foundElements = [];

  EventVisitor(this.offset, this.length, this.logger);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    //var isWidget = node.staticElement.enclosingElement.allSupertypes.where((it) => it.name == 'Widget').isNotEmpty;

    //logger.log('Visiting ${node.beginToken.lexeme}');
    if (offset < node.offset && offset + length > node.offset + node.beginToken.length) {
      //logger.log('Found $node');
      foundElements.add(node);
    }

    return super.visitInstanceCreationExpression(node);
  }
}

class SearchBlocWithEventType extends RecursiveElementVisitor {

  final List<String> possibleEvents;

  final Logger logger;
  SearchBlocWithEventType(this.possibleEvents, this.logger);


  ClassElement bloc;

  bool isBlocSubclass(ClassElement element) {
    return element.supertype.element.name == "Bloc";
  }
  @override
  void visitClassElement(ClassElement element) {

    if(isBlocSubclass(element)) {
      var eventType = element.supertype.typeArguments.first.element.name;
      if(possibleEvents.contains(eventType)) {
        logger.log("Found Bloc that matches!");
        bloc = element;
        return;
      }

    }

    return super.visitClassElement(element);
  }
}

class BlocStateCollector extends RecursiveElementVisitor {


  final String name;

  final Logger logger;

  BlocStateCollector(this.name, this.logger);

  List<String> superTypes = [];

  @override
  void visitClassElement(ClassElement element) {
    if(element.name == name) {
      // There could be equatable above etc.
      superTypes = element.allSupertypes.map((it) => it.element.name).toList();
      logger.log(superTypes.join('-'));
      return;
    }

    return super.visitClassElement(element);
  }

}
