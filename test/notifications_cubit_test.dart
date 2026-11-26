import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/bloc/notifications/notifications_cubit.dart';
import 'package:proplay/services/notification_service.dart';

class _FakePush implements NotificationService {
  PushStatus current = PushStatus.off;
  PushStatus onEnable = PushStatus.on;
  Object? error;
  final calls = <String>[];

  @override
  Future<PushStatus> status(String uid) async => current;

  @override
  Future<PushStatus> enable(String uid) async {
    calls.add('enable:$uid');
    if (error != null) throw error!;
    return onEnable;
  }

  @override
  Future<void> disable(String uid) async {
    calls.add('disable:$uid');
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('load reads the device status', () async {
    final push = _FakePush()..current = PushStatus.on;
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.load();
    expect(cubit.state.status, PushStatus.on);
  });

  test('turning on registers this device', () async {
    final push = _FakePush();
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.load();
    await cubit.set(true);
    expect(push.calls, ['enable:u1']);
    expect(cubit.state.status, PushStatus.on);
    expect(cubit.state.message, isNull);
    expect(cubit.state.busy, isFalse);
  });

  test('a blocked browser explains how to unblock', () async {
    final push = _FakePush()..onEnable = PushStatus.blocked;
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.set(true);
    expect(cubit.state.status, PushStatus.blocked);
    expect(cubit.state.message, contains('bloqueadas'));
  });

  test('turning off forgets this device', () async {
    final push = _FakePush()..current = PushStatus.on;
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.load();
    await cubit.set(false);
    expect(push.calls, ['disable:u1']);
    expect(cubit.state.status, PushStatus.off);
  });

  test('an error keeps the previous status and says so', () async {
    final push = _FakePush()
      ..current = PushStatus.on
      ..error = Exception('sin red');
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.load();
    await cubit.set(false);
    expect(cubit.state.status, PushStatus.on);
    expect(cubit.state.message, contains('No pudimos cambiar los avisos'));
  });

  test('unsupported platforms stay unsupported', () async {
    final push = _FakePush()..current = PushStatus.unsupported;
    final cubit = NotificationsCubit(push, 'u1');
    await cubit.load();
    expect(cubit.state.status, PushStatus.unsupported);
  });
}
