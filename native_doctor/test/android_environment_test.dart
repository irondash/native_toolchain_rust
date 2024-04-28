import 'package:native_doctor/src/android_sdk.dart';
import 'package:native_doctor/src/command.dart';
import 'package:test/test.dart';
import 'package:rustup/src/internal/fake_process_manager.dart';

void main() {
  test('android environment', () async {
    final processManager = FakeProcessManager.list([
      FakeCommand(
        command: ['flutter', 'config', '--machine'],
        stdout: '''
{
  "enable-macos-desktop": true,
  "enable-linux-desktop": true,
  "cli-animations": false,
  "enable-native-assets": true,
  "android-studio-dir": "/Applications/Android Studio.app/Contents",
  "android-sdk": "/Users/Matej/Library/Android/sdk",
  "jdk-dir": "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
}
''',
      )
    ]);
    await withProcessManager(processManager, () async {
      final androidSdkInfo = await AndroidSdkInfo.find();
      expect(androidSdkInfo, isNotNull);
      expect(androidSdkInfo!.androidSdk, '/Users/Matej/Library/Android/sdk');
      expect(androidSdkInfo.javaHome,
          '/Applications/Android Studio.app/Contents/jbr/Contents/Home');
      expect(processManager, hasNoRemainingExpectations);
    });
  });
}
