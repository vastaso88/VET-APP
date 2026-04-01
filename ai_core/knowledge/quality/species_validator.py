from packages.core.domain.knowledge.models import EvidenceSource

CROSS_SPECIES_ALLOWED: dict[str, set[str]] = {
    "dog": {"other"},
    "cat": {"other"},
    "rabbit": set(),
    "rodent": set(),
    "bird": set(),
    "reptile": set(),
    "fish": set(),
    "exotic_mammal": set(),
}


class SpeciesValidator:
    def validate_species_match(self, source: EvidenceSource, pet_species: str) -> bool:
        if source.species == pet_species:
            return True
        return self.validate_cross_species_applicability(source, pet_species)

    def validate_cross_species_applicability(
        self,
        source: EvidenceSource,
        pet_species: str,
    ) -> bool:
        if source.species != "other":
            return False
        allowed = CROSS_SPECIES_ALLOWED.get(pet_species, set())
        if "other" not in allowed:
            return False
        return source.tier in {"A", "B"}
