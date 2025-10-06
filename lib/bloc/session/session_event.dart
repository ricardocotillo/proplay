import 'package:equatable/equatable.dart';
import 'package:proplay/models/session_template_model.dart';

abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object> get props => [];
}

class SessionTemplateCreateRequested extends SessionEvent {
  final SessionTemplateModel template;

  const SessionTemplateCreateRequested(this.template);

  @override
  List<Object> get props => [template];
}