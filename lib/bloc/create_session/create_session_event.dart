part of 'create_session_bloc.dart';

abstract class CreateSessionEvent extends Equatable {
  const CreateSessionEvent();

  @override
  List<Object?> get props => [];
}

class CreateSessionTemplate extends CreateSessionEvent {
  final SessionTemplateModel template;

  /// Optional banner picked by the organizer; uploaded before the template is written.
  final XFile? banner;

  const CreateSessionTemplate(this.template, {this.banner});

  @override
  List<Object?> get props => [template, banner];
}
