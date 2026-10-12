import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/nearby_places/data/radar_contributions_repository.dart';
import 'package:vet_app_mobile/features/nearby_places/domain/radar_community.dart';

void main() {
  test('known backend messages keep their Italian text, unknown ones pass through', () {
    expect(localizedBackendMessage('Hai già fatto questa segnalazione.'),
        'Hai già fatto questa segnalazione.');
    expect(localizedBackendMessage('Puoi fare al massimo 5 segnalazioni al giorno.'),
        'Puoi fare al massimo 5 segnalazioni al giorno.');
    expect(localizedBackendMessage('Il nome può avere al massimo 60 caratteri.'),
        'Il nome può avere al massimo 60 caratteri.');
    expect(localizedBackendMessage('something new'), 'something new');
  });

  test('plural labels read as before', () {
    expect(const RadarRating(count: 1).communityLabel,
        'Voto della community: 1 voto · la media compare da 3 voti');
    expect(const RadarRating(count: 4, average: 4.25).communityLabel,
        'Voto della community: 4,3 su 5 · 4 voti');
    expect(const RadarReportInfo(
            reportId: 'r', isPending: true, confirmations: 0, required: 5, expiresInDays: 1)
        .expiryLabel, 'Scade tra 1 giorno se nessuno conferma.');
  });
}
