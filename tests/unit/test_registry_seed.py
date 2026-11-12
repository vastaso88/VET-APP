from packages.infrastructure.llm.sources.registry_seed import build_initial_seed_catalog


def test_registry_seed_catalog_contains_expected_registries_and_domains() -> None:
    catalog = build_initial_seed_catalog()

    registry_keys = {row["registry_key"] for row in catalog["registries"]}
    domain_hosts = {row["host"] for row in catalog["domains"]}

    assert {"ooir_jif", "research_com", "pjip_sjr", "avma_direct"} <= registry_keys
    assert {"ooir.org", "research.com", "pjip.org", "avmajournals.avma.org"} <= domain_hosts


def test_registry_seed_catalog_marks_ranking_sites_as_discovery_only() -> None:
    catalog = build_initial_seed_catalog()
    domains = {row["host"]: row for row in catalog["domains"]}

    assert domains["ooir.org"]["discovery_only"] is True
    assert domains["research.com"]["allowed_for_direct_ingest"] is False
    assert domains["pjip.org"]["allowed_for_direct_ingest"] is False
    assert domains["avmajournals.avma.org"]["allowed_for_direct_ingest"] is True


def test_registry_seed_catalog_carries_the_ethology_welfare_and_duty_bodies() -> None:
    # Repositioning (docs/product/11 §4, 2.4): the positions the chat prefers
    # on behaviour, welfare and owners' duties come from official domains.
    catalog = build_initial_seed_catalog()
    domains = {row["host"]: row for row in catalog["domains"]}

    for host in (
        "esvce.org",
        "avsab.org",
        "icatcare.org",
        "fve.org",
        "fecava.org",
        "rspca.org.uk",
        "salute.gov.it",
        "fnovi.it",
        "eur-lex.europa.eu",
    ):
        assert host in domains, host
        assert domains[host]["discovery_only"] is False, host
        assert domains[host]["allowed_for_direct_ingest"] is True, host
        assert domains[host]["evidence_policy"] == "allow_manual_docs", host
    assert domains["salute.gov.it"]["source_kind"] == "government"
    assert domains["eur-lex.europa.eu"]["source_kind"] == "government"
