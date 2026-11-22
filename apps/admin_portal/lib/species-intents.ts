// Values shared by the scientific schedule form (app/jobs) and the discovery
// panel (components/scientific-discovery-panel). Plain data, safe in client and
// server components. Defaults, labels and handlers stay in each form.

export const SPECIES_VALUES = [
  "dog",
  "cat",
  "small_mammal",
  "bird",
  "reptile_amphibian",
  "fish",
  "other",
] as const;

export const INTENT_VALUES = [
  "clinical_question",
  "nutrition_question",
  "behavior_question",
  "preventive_care",
] as const;
