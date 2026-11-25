# ruff: noqa: E501
"""The reminder sent 7 days before a yearly plan renews: the reviewed texts, five languages.

Copied word for word from the translations reviewed on 25 November 2026 (approved by the owner
the same day); `tests/fixtures/billing_texts_2026_11_25.json` is the copy the tests compare them
with. A service message only: no offer, no invitation to stay. The fields are filled by
`renewal_notice`; the company and the contact come from the environment, never from here.
"""

from packages.core.domain.localization import SupportedLocale

SUBJECTS: dict[SupportedLocale, str] = {
    "it": "Il tuo piano annuale Quokka si rinnova tra 7 giorni",
    "en": "Your Quokka yearly plan renews in 7 days",
    "es": "Tu plan anual de Quokka se renueva en 7 días",
    "de": "Ihr Quokka-Jahresabo verlängert sich in 7 Tagen",
    "fr": "Votre abonnement annuel Quokka se renouvelle dans 7 jours",
}

BODIES: dict[SupportedLocale, str] = {
    "it": "Ciao {nome}, il {data_rinnovo} il tuo piano annuale Quokka si rinnova da solo e {store} addebita {prezzo}. Se vuoi continuare, non devi fare nulla. Se non vuoi rinnovare, puoi disdire quando vuoi da Impostazioni → Abbonamento e pagamenti o dallo store, prima di quella data: usi il piano fino alla fine del periodo già pagato. Questa è una comunicazione di servizio sul tuo abbonamento. {titolare}, {contatto}.",
    "en": "Hi {nome}, on {data_rinnovo} your yearly Quokka plan renews automatically and {store} charges {prezzo}. If you want to continue, you do not need to do anything. If you do not want to renew, you can cancel at any time before that date in Settings → Subscription and payments or in the store: you keep using the plan until the end of the period you have already paid for. This is a service message about your subscription. {titolare}, {contatto}.",
    "es": "Hola {nome}, el {data_rinnovo} tu plan anual de Quokka se renueva automáticamente y {store} cobra {prezzo}. Si quieres continuar, no tienes que hacer nada. Si no quieres renovar, puedes cancelar cuando quieras antes de esa fecha en Ajustes → Suscripción y pagos o en la tienda: usas el plan hasta el final del periodo ya pagado. Este es un mensaje de servicio sobre tu suscripción. {titolare}, {contatto}.",
    "de": "Hallo {nome}, am {data_rinnovo} verlängert sich Ihr Quokka-Jahresabo automatisch, und {store} bucht {prezzo} ab. Wenn Sie weitermachen möchten, müssen Sie nichts tun. Wenn Sie nicht verlängern möchten, können Sie jederzeit vor diesem Datum unter Einstellungen → Abo und Zahlungen oder im Store kündigen: Sie nutzen das Abo bis zum Ende des bereits bezahlten Zeitraums. Dies ist eine Servicemitteilung zu Ihrem Abo. {titolare}, {contatto}.",
    "fr": "Bonjour {nome}, le {data_rinnovo}, votre abonnement annuel Quokka se renouvelle automatiquement et {store} prélève {prezzo}. Si vous souhaitez continuer, vous n'avez rien à faire. Si vous ne souhaitez pas renouveler, vous pouvez résilier à tout moment, avant cette date, dans Paramètres → Abonnement et paiements ou dans la boutique\u00a0: vous utilisez l'abonnement jusqu'à la fin de la période déjà payée. Ceci est un message de service concernant votre abonnement. {titolare}, {contatto}.",
}
