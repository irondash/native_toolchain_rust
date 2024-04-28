import 'package:logging/logging.dart';
import 'package:native_doctor/native_doctor.dart';

void main(List<String> arguments) async {
  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  run(arguments);
}
