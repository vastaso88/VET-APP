import '../../age/domain/age_status.dart';

/// There is no usage-analytics tool in the app today (privacy notice §3), so a
/// consent to it would be a consent to something that does not happen: the
/// "Analisi d'uso" switch stays hidden everywhere until this becomes true.
const analyticsToolExists = false;

/// Marketing e-mail is offered to adults only (privacy notice §9): a declared
/// minor never sees the switch. An age not known yet is not a reason to hide
/// it from an adult who has just not been read.
bool marketingConsentOffered(AgeBand band) =>
    band != AgeBand.minor && band != AgeBand.underMinimum;
