/// Lightweight snapshot of a finalized hangout stored in local history.
/// Avoids persisting the full item graph — just what the home screen needs.
class HangoutSummary {
  const HangoutSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.total,
    required this.currency,
    required this.participantNames,
    required this.settlements,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final double total;
  final String currency;
  final List<String> participantNames; // first names only
  final List<SettlementSummary> settlements;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'total': total,
        'currency': currency,
        'participantNames': participantNames,
        'settlements': settlements.map((s) => s.toJson()).toList(),
      };

  factory HangoutSummary.fromJson(Map<String, dynamic> json) => HangoutSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        total: (json['total'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        participantNames: List<String>.from(json['participantNames'] as List),
        settlements: (json['settlements'] as List)
            .map((e) => SettlementSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SettlementSummary {
  const SettlementSummary({
    required this.fromName,
    required this.toName,
    required this.amount,
  });

  final String fromName;
  final String toName;
  final double amount;

  Map<String, dynamic> toJson() => {
        'fromName': fromName,
        'toName': toName,
        'amount': amount,
      };

  factory SettlementSummary.fromJson(Map<String, dynamic> json) =>
      SettlementSummary(
        fromName: json['fromName'] as String,
        toName: json['toName'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}
