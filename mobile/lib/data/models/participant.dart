import 'package:freezed_annotation/freezed_annotation.dart';

part 'participant.freezed.dart';
part 'participant.g.dart';

/// A person participating in a hangout.
/// Can be a registered user (has userId) or a guest (userId is null).
@freezed
abstract class Participant with _$Participant {
  const factory Participant({
    required String id,
    String? userId,         // null = guest
    required String name,
    String? emoji,          // e.g. "🍕" — chosen at join
    required int colorIndex, // maps to AppColors.avatarColors
    @Default(false) bool isHost,
    @Default(false) bool isPayer, // who paid the physical bill
  }) = _Participant;

  factory Participant.fromJson(Map<String, dynamic> json) =>
      _$ParticipantFromJson(json);
}
