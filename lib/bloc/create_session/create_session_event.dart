part of 'create_session_bloc.dart';

abstract class CreateSessionEvent extends Equatable {
  const CreateSessionEvent();

  @override
  List<Object> get props => [];
}

class CreateSessionTemplate extends CreateSessionEvent {
  final SessionTemplateModel template;

  const CreateSessionTemplate(this.template);

  @override
  List<Object> get props => [template];
}
