"""French fixed texts for the backend, wired into `response_generator`,
`interview_planner` and `triage_clarification` (the fixed messages of
`localization._MESSAGES` carry their `"fr"` entries inline). Same keys and
placeholders as the Italian catalogs; tests/unit/test_localization_fr.py checks it.
"""

# ruff: noqa: E501

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
