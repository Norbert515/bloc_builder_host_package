import 'dart:convert';
import 'dart:io';

void main() {
  var filepath = 'C:\\Users\\Norbert\\Desktop\\file22222.txt';
  var file = File(filepath);
  var content = file.readAsStringSync();


  // ignore: omit_local_variable_types
  String res = content.split('\n').where((it) => it.split(':').length > 2 && it.split(':')[1] == 'PluginNoti')
    .map((it) => it.substring(25, it.indexOf(':file::')))
    .map((it) => it.replaceAll('::', ':'))
    .map((it) => json.decode(it))
    .where((it) => it['event'] == 'plugin.error')
    .map((it) => it['params']['message'])
    .join('\n');


  print(res);



}