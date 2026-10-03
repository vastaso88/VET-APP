/// Walks are only offered for dogs (owner request, 2026-10-03) - one rule
/// shared by the pet detail page's Passeggiate tab and the home-screen
/// widget (walk_home_widget.dart) so the two can't disagree about which
/// pets count. Species are stored as the Italian label from
/// PetDemoStore.speciesOptions.
bool isDogSpecies(String species) => species.trim().toLowerCase() == 'cane';
