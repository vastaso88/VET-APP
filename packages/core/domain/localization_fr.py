"""French fixed texts for the backend (NOT wired yet).

Same keys and placeholders as `localization._MESSAGES` (+ the per-language
dicts of `response_generator`, `interview_planner` and `triage_clarification`).
They stay here, unreferenced by production code, until `response_locale` /
`SupportedLocale` accept "fr" (owned by the MULTILANG maintainer); wiring is
one line per catalog, see docs/i18n/FRENCH_BACKEND_WIRING.md.
"""

# ruff: noqa: E501

MESSAGES_FR: dict[str, str] = {
    "summary_header": "# Résumé pour le vétérinaire — {subject}\n\nGénéré automatiquement par l'assistant de l'application le {date} à partir d'une conversation commencée le {started}. Il ne s'agit ni d'un diagnostic ni d'un avis vétérinaire : il reprend ce que le propriétaire a écrit à l'assistant.",
    "summary_footer": "---\nTexte généré par un assistant automatique à partir de ce qu'a indiqué le propriétaire ; à vérifier lors de la consultation. Aucune donnée personnelle du propriétaire n'est incluse.",
    "summary_subject": "l'animal",
    "summary_unreported": "Non indiqué",
    "summary_sections": "Animal|Motif du contact|Symptômes signalés par le propriétaire et depuis quand|Ce qui a été observé|Documents cités|Questions ouvertes pour le vétérinaire",
    "file_unreadable": "Je n'ai pas réussi à lire le fichier que vous avez joint, je ne peux donc pas vous dire ce qu'il contient. Essayez de l'envoyer à nouveau : un PDF ou une photo nette et bien éclairée fonctionnent en général. Vous pouvez aussi m'écrire ici les valeurs qui vous intéressent et je vous les explique.",
    "record_empty": "Je ne trouve aucun document dans le dossier médical de {pet_name}, je n'ai donc pas de compte rendu à vous expliquer. Vous pouvez le charger dans le dossier médical ou le joindre ici dans le chat ; vous pouvez aussi m'écrire les valeurs qui vous intéressent et je vous les explique.",
    "record_no_consent": "Le dossier médical de {pet_name} contient {documents_found}, mais je ne peux pas le consulter car le consentement n'est pas activé : je ne sais pas ce qu'il contient. Vous pouvez l'activer depuis la fiche de {pet_name}. Vous pouvez aussi joindre ici le compte rendu ou m'écrire les valeurs, et je vous les explique tout de suite.",
    "document_one": "un document",
    "document_many": "{count} documents",
    "record_unreadable": "Je vois {labels} dans le dossier, mais je n'ai pas réussi à lire le fichier : je ne peux pas vous dire ce qu'il contient sans l'inventer. Essayez de le charger à nouveau (un PDF ou une photo nette fonctionnent en général), ou écrivez-moi ici les valeurs et je vous les explique.",
    "record_no_content": "Je vois {labels} dans le dossier, mais sans fichier ni description à lire. Joignez ici le compte rendu ou écrivez-moi les valeurs qui vous intéressent et je vous les explique.",
    "multi_pet": "J'ai remarqué que vous me parlez de plusieurs animaux avec des problèmes qui semblent indépendants. Pour bien suivre chaque cas, il vaut mieux ouvrir une conversation séparée pour {pet_name} et une pour l'autre animal — ainsi chacun a son histoire et ses détails, sans mélanger les informations. Si en revanche le problème concerne justement une interaction entre les deux (par exemple ils se battent, se disputent la nourriture, l'un a eu peur de l'autre), dites-le-moi ici : dans ce cas, j'ai besoin du contexte de l'autre animal pour comprendre ce qui arrive à {pet_name}.",
    "interview_incomplete": "Je n'ai pas bien réussi à comprendre la situation avec les questions posées jusqu'ici, et je ne veux pas vous orienter à partir d'informations incomplètes. Vous pouvez essayer de me raconter à nouveau ce qui se passe, peut-être avec d'autres mots, ou recommencer une nouvelle conversation.",
    "safety_resolved": "Merci pour ces précisions. Ce que vous décrivez chez {pet_name} est souvent lié à un effort, à la chaleur ou à l'émotion du moment, et se résout généralement tout seul en peu de temps. En attendant : gardez-le au calme, proposez-lui de l'eau fraîche et observez-le pendant 15 à 20 minutes. S'il ne va pas mieux, s'il va moins bien, même légèrement, ou si vous avez le moindre doute, contactez tout de suite le vétérinaire — mieux vaut un appel de trop que de prendre un risque.",
    "observe_action": "Surveillance rapprochée ; contactez le vétérinaire si l'état ne s'améliore pas ou en cas de doute.",
    "no_evidence": "Je n'ai pas trouvé assez de preuves fiables pour répondre en toute sécurité à cette question. Je peux vous aider à la reformuler ou à préparer les informations à apporter au vétérinaire.",
    "no_evidence_limit": "Sans source, pas de réponse : la recherche du prototype n'a produit aucune source recevable.",
    "symptom_action": "Si le symptôme persiste, s'aggrave ou touche la douleur, l'appétit ou l'énergie, consultez le vétérinaire.",
    "general_limit": "Orientation générale sans recherche de preuves.",
    "natural_limit": "Réponse générée librement par le modèle, non limitée à des sources vérifiées — utile pour s'orienter, elle ne remplace pas une consultation vétérinaire.",
    "persistent_action": "Consultez le vétérinaire pour une évaluation personnalisée si les symptômes persistent.",
    "worsening_action": "Consultez le vétérinaire pour une évaluation personnalisée si les symptômes persistent ou s'aggravent.",
    "vet_action": "Consultez le vétérinaire pour une évaluation personnalisée.",
    "tier_limit": "Les sources récupérées ne comprennent ni recommandations ni revues systématiques de niveau A.",
    "species_limit": "Certaines sources ne sont pas spécifiques à l'espèce.",
    "abstract_limit": "Pour ces sources, nous n'avons que le titre et le résumé, pas le texte complet.",
    "husbandry_limit": "Les indications d'aménagement et d'élevage proviennent de références de vulgarisation sélectionnées, et non de la littérature scientifique à comité de lecture : vérifiez toujours les paramètres pour votre espèce et sous-espèce exactes auprès d'un vétérinaire spécialisé en animaux exotiques ou d'un éleveur spécialisé.",
    "informative_limit": "Les preuves restent informatives et ne remplacent pas une consultation vétérinaire.",
    "safety_unclear": "Avant tout : pour certains aspects que vous m'avez décrits, je n'ai pas encore assez de clarté pour exclure une situation sérieuse ; si l'état s'aggrave, n'attendez pas et contactez le vétérinaire. Cela dit :\n\n{answer}",
    "safety_unclear_limit": "Certains aspects de sécurité ne sont pas totalement clarifiés par l'entretien.",
    "consent_read": "Merci, j'ai jeté un œil au dossier médical. ",
    "consent_ok": "Très bien. ",
    "consent_declined": "Très bien, nous continuons sans le consulter. ",
    "describe_again": "Racontez-moi à nouveau ce que vous avez observé, et je vous répondrai.",
    "report_attached": "J'ai lu le document que vous avez joint.",
    "report_read": "J'ai lu {labels}.",
    "join_documents": " et ",
    "validation_source": "Je vous laisse tout de même les sources que j'avais trouvées, vous pouvez les consulter directement. ",
    "validation_answer": "Ce que j'allais vous dire n'a pas passé nos contrôles de sécurité (par exemple une référence invérifiable ou une affirmation trop absolue), je préfère donc ne pas vous le montrer tel quel. {source_note}Essayez de reformuler la question, ou consultez le vétérinaire pour une évaluation directe.",
    "validation_limit": "Réponse écartée par le contrôle de validation : {violation}",
    "weight_suggestion": "Une dernière chose : le poids manque dans le profil de {pet_name}. Si vous l'ajoutez depuis sa fiche, je pourrai en tenir compte dans mes prochaines réponses.",
    "weight_marker": "le poids manque",
    "record_notice": "Note : je ne peux pas consulter le dossier médical de {pet_name} car le consentement n'est pas activé, je réponds donc sans ses comptes rendus. Si vous souhaitez que j'en tienne compte, vous pouvez l'activer depuis le dossier médical.",
    "record_marker": "je ne peux pas consulter le dossier médical",
    "triage_opening": "Vous avez bien fait de m'écrire tout de suite. Ce que vous me racontez au sujet de {pet_name} est un signal qui mérite une évaluation vétérinaire immédiate. Voici ce qu'il faut faire maintenant :\n",
    "triage_toxin_opening": "Mieux vaut ne pas prendre de risque : ce dont vous me parlez peut être dangereux pour {pet_name}. Voici ce qu'il faut faire maintenant :\n",
    "triage_steps": "1) contactez tout de suite votre vétérinaire ou un service d'urgences vétérinaires ;\n2) en attendant, gardez {pet_name} au calme, au chaud et en sécurité ;\n3) évitez de lui donner de la nourriture, trop d'eau ou des médicaments sans l'avis du vétérinaire.",
    "triage_limitation": "Triage de précaution généré sans approfondissement diagnostique.",
    "triage_action": "Évaluation vétérinaire immédiate.",
    "dosage_answer": "Je ne vous donne pas de chiffre précis : la bonne dose d'un médicament dépend du poids exact, de l'état clinique et de la formulation spécifique du produit. C'est une évaluation qui revient au seul vétérinaire, le seul à pouvoir établir ou modifier un traitement. Avant d'administrer un médicament, confirmez toujours la dose exacte avec le vétérinaire.",
    "dosage_limitation": "Cette application soutient le travail du vétérinaire, elle ne le remplace pas : elle ne fournit jamais de posologies médicamenteuses précises.",
    "dosage_action": "Confirmez la posologie exacte avec le vétérinaire.",
    "provider_failure": "Pour le moment, je n'arrive pas à élaborer une réponse car le service est temporairement indisponible. Réessayez dans un instant, ou consultez le vétérinaire si la situation demande de l'attention dès maintenant.",
    "provider_failure_limitation": "Réponse indisponible : fournisseur LLM injoignable.",
    "consent_request": "Souhaitez-vous que je consulte le dossier médical de {pet_name} pour vous donner un conseil plus précis ? Je lirai les trois entrées les plus récentes, y compris le texte des documents joints, et je les enverrai au service d'intelligence artificielle qui rédige la réponse. Vous pouvez changer d'avis à tout moment depuis la fiche de {pet_name}.",
}

CONNECTORS_FR: dict[str, str] = {
    "uncertain_prefix": "Certaines sources suggèrent aussi que ",
    "uncertain_suffix": ", même si ce n'est pas tout à fait certain.",
    "conflicting_prefix": "Les sources ne sont pas d'accord sur ce point : ",
    "actions_prefix": "En attendant, vous pouvez : ",
    "monitoring_prefix": "Surveillez : ",
    "referral_prefix": "Contactez le vétérinaire si : ",
}

QUESTION_TEMPLATES_FR: dict[str, str] = {
    "safety_critical_unknowns": "Pouvez-vous me donner un peu plus de détails ? Cela m'aidera à comprendre l'urgence de la situation.",
    "presenting_problem": "Qu'avez-vous observé exactement ? Racontez-moi avec vos mots ce qui se passe.",
    "onset": "Depuis quand l'observez-vous ?",
    "observed_behaviours": "Pouvez-vous décrire en détail ce qui se passe à ces moments-là ?",
    "associated_signs": "En dehors de cela, avez-vous remarqué des changements dans l'appétit, la soif, l'énergie, les urines ou les selles ?",
    "environmental_changes": "Quelque chose a-t-il changé récemment : alimentation, logement, un autre animal, un voyage ?",
    "contexts": "Dans quelles situations cela arrive-t-il le plus souvent ?",
    "known_medical_context": "Existe-t-il des problèmes de santé connus ou des traitements en cours dont je devrais être informé ?",
}

# Translation only: REASSURING_MARKERS / red-flag keyword lists have no French
# entries yet, so a French reply is never read as reassuring (safe default).
CLARIFYING_QUESTIONS_FR: dict[str, str] = {
    "respiratory": "Deux questions rapides avant de vous orienter : la respiration rapide a-t-elle commencé après avoir couru, joué ou eu chaud, ou au repos ? Est-ce qu'elle se calme maintenant, reste identique ou s'aggrave ?",
    "collapse": "Deux questions rapides : est-il maintenant éveillé, réactif et se déplace-t-il normalement, ou reste-t-il au sol et peu réactif ? L'épisode a-t-il duré quelques secondes ou plus longtemps ?",
    "seizure": "Deux questions rapides : les convulsions sont-elles terminées et est-il redevenu attentif, ou continuent-elles en ce moment ? Est-ce la première fois ?",
    "bleeding_trauma": "Deux questions rapides : saigne-t-il encore ou le saignement s'est-il arrêté ou réduit ? Était-ce quelques gouttes ou une quantité qui vous inquiète ?",
    "urinary": "Deux questions rapides : depuis combien d'heures n'a-t-il pas uriné ? Essaie-t-il sans y parvenir ou montre-t-il de la douleur ?",
    "gi_stasis": "Deux questions rapides : depuis combien d'heures exactement n'a-t-il ni mangé ni fait ses besoins ? S'est-il approché de la nourriture ou a-t-il produit ne serait-ce que quelques petites selles ?",
}
