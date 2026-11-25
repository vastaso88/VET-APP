"""Collaudo K21: a number past the limit of a database `integer` column answered 500 instead of
400. One general rule for every route that writes: nothing the client sends is unbounded.

Read from the API's own OpenAPI document, so a new route or field is checked without anyone
remembering to add it here:
- a number (integer or float) in a body or in a query parameter needs an upper bound;
- a string in a body needs `maxLength`, a list needs `maxItems`;
- a free-form object is refused.

What is deliberately NOT bounded is listed below with the reason. An entry that no longer
matches anything is ignored, so a fix can land before its exception is removed."""

from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from apps.api.main import app

WRITE_METHODS = {"post", "put", "patch", "delete"}

# Strings whose format already bounds them: a date or a time is parsed strictly (10-35 characters
# or a 422), a uuid is 36, a file is checked against the size limit of its route.
BOUNDED_FORMATS = {"date", "date-time", "time", "uuid", "binary"}

# (route, where) -> why it is allowed to stay without an upper bound / length / item limit.
EXCEPTIONS: dict[tuple[str, str], str] = {
    # The age is judged by the service against the species (age_out_of_range, 422, in the
    # owner's language), before anything reaches a column; see test_pet_numbers_past_the_limit.
    ("POST /pets", "body.age_years"): "judged by the service: 422 age_out_of_range",
    ("PUT /pets/{pet_id}", "body.age_years"): "judged by the service: 422 age_out_of_range",
    # Uploaded files are bounded by the size checks of their routes (the attachment
    # limit), not by a schema keyword.
    ("POST /chat-attachments", "body.file"): "file: bounded by the upload size check",
    # Operator-only (admin token) schedule payload: its keys are validated one by one by
    # `_validated_schedule_payload` before it is stored.
    ("POST /admin/schedules", "body.payload"): "admin only, validated key by key",
}


def _schemas() -> dict[str, Any]:
    schemas: dict[str, Any] = app.openapi()["components"]["schemas"]
    return schemas


def _resolve(node: dict[str, Any]) -> dict[str, Any]:
    if "$ref" in node:
        resolved: dict[str, Any] = _schemas()[node["$ref"].split("/")[-1]]
        return resolved
    return node


def _leaves(node: dict[str, Any]) -> list[dict[str, Any]]:
    """The typed nodes behind anyOf/oneOf/allOf (and the items of a list), with the list
    itself as one of them."""
    node = _resolve(node)
    found: list[dict[str, Any]] = []
    for key in ("anyOf", "oneOf", "allOf"):
        for sub in node.get(key, []):
            found += _leaves(sub)
    if "type" in node:
        found.append(node)
    return found


def _check(
    node: dict[str, Any], where: str, seen: set[int], problems: list[tuple[str, str]]
) -> None:
    node = _resolve(node)
    if id(node) in seen:
        return
    if node.get("type") == "object" or "properties" in node:
        seen = seen | {id(node)}
        if "properties" not in node and node.get("additionalProperties", True):
            problems.append((where, "free-form object"))
        for name, prop in node.get("properties", {}).items():
            _check(prop, f"{where}.{name}", seen, problems)
        return
    for key in ("anyOf", "oneOf", "allOf"):
        for sub in node.get(key, []):
            _check(sub, where, seen, problems)
    kind = node.get("type")
    if kind in ("integer", "number") and not ({"maximum", "exclusiveMaximum"} & node.keys()):
        problems.append((where, "number without an upper bound"))
    if kind == "string" and not ({"maxLength", "enum", "const", "pattern"} & node.keys()):
        if node.get("format") not in BOUNDED_FORMATS:
            problems.append((where, "string without maxLength"))
    if kind == "array":
        if "maxItems" not in node:
            problems.append((where, "list without maxItems"))
        items = _resolve(node.get("items", {}))
        _check(items, f"{where}[]", seen, problems)


def _violations() -> list[tuple[str, str, str]]:
    spec = app.openapi()
    out: list[tuple[str, str, str]] = []
    for path, operations in spec["paths"].items():
        for method, operation in operations.items():
            if method not in WRITE_METHODS:
                continue
            route = f"{method.upper()} {path}"
            for content in operation.get("requestBody", {}).get("content", {}).values():
                problems: list[tuple[str, str]] = []
                _check(content["schema"], "body", set(), problems)
                out += [(route, where, why) for where, why in problems]
            for parameter in operation.get("parameters", []):
                if parameter["in"] != "query":
                    continue  # path ids and headers are bounded by the server's URL/header limits
                problems = []
                _check(parameter["schema"], f"query.{parameter['name']}", set(), problems)
                out += [(route, where, why) for where, why in problems]
    return out


def _is_excepted(route: str, where: str) -> bool:
    # An exception for "body.photo_urls" also covers its items "body.photo_urls[]".
    return any(
        (route, excepted) in EXCEPTIONS
        for excepted in {where, where.removesuffix("[]"), where.split("[")[0]}
    )


def test_every_route_that_writes_bounds_what_the_client_sends() -> None:
    unbounded = [
        f"{route}  {where}: {why}"
        for route, where, why in _violations()
        if not _is_excepted(route, where)
    ]

    assert unbounded == [], (
        "A write route accepts an unbounded value (a number past an `integer` column is a 500, "
        "an unbounded string or list is a free ride for a megabyte). Give it Field(le=...) / "
        "max_length / max_length on the list, or add a motivated entry to EXCEPTIONS:\n"
        + "\n".join(unbounded)
    )


def test_the_check_itself_sees_a_number_without_a_limit() -> None:
    problems: list[tuple[str, str]] = []

    _check({"type": "object", "properties": {"n": {"type": "integer"}}}, "body", set(), problems)
    _check(
        {"type": "object", "properties": {"n": {"type": "integer", "maximum": 5}}},
        "ok",
        set(),
        problems,
    )

    assert problems == [("body.n", "number without an upper bound")]


def test_every_exception_still_has_a_reason() -> None:
    assert all(reason.strip() for reason in EXCEPTIONS.values())


# --- what the bounds do on the wire: 422 with no write, never 500 ----------------------

HUGE = 10**12


@pytest.fixture
def client() -> TestClient:
    return TestClient(app, raise_server_exceptions=False)


def test_pet_numbers_past_the_limit_are_refused_not_a_500(client: TestClient) -> None:
    base = {"name": "Rex", "species": "Cane"}

    assert client.post("/pets", json={**base, "age_years": HUGE}).status_code == 422
    for field in ("length_cm", "width_cm", "height_cm", "volume_liters"):
        refused = client.post("/pets", json={**base, "habitat": {field: HUGE}})
        assert refused.status_code == 422, field
    stock = {"species": "Neon", "male_count": HUGE}
    assert client.post("/pets", json={**base, "aquarium_stock": [stock]}).status_code == 422
    too_many = [{"species": "Neon"}] * 101
    assert client.post("/pets", json={**base, "aquarium_stock": too_many}).status_code == 422
    long_text = {"habitat": {"notes": "x" * 1001}}
    assert client.post("/pets", json={**base, **long_text}).status_code == 422


def test_a_real_aquarium_still_saves(client: TestClient) -> None:
    response = client.post(
        "/pets",
        json={
            "name": "Acquario",
            "species": "Pesce",
            "habitat": {"length_cm": 120, "width_cm": 40, "height_cm": 50, "volume_liters": 240},
            "aquarium_stock": [{"species": "Neon", "male_count": 6, "female_count": 6}],
        },
    )

    assert response.status_code == 200, response.text
    saved = response.json()["pet_profile"]
    assert saved["habitat"]["volume_liters"] == 240
    assert saved["aquarium_stock"][0]["female_count"] == 6


def test_update_applies_the_same_bounds(client: TestClient) -> None:
    pet_id = client.post("/pets", json={"name": "Rex", "species": "Cane"}).json()["pet_profile"][
        "id"
    ]

    assert client.put(f"/pets/{pet_id}", json={"age_years": HUGE}).status_code == 422
    assert (
        client.put(f"/pets/{pet_id}", json={"habitat": {"volume_liters": HUGE}}).status_code == 422
    )
    assert (
        client.put(f"/pets/{pet_id}", json={"aquarium_stock": [{"species": "x" * 81}]}).status_code
        == 422
    )


def test_ids_and_keys_in_bodies_are_bounded(client: TestClient) -> None:
    big = "x" * 5000

    assert client.post("/chat", json={"pet_id": big, "user_message": "ciao"}).status_code == 422
    assert (
        client.post(
            "/chat", json={"pet_id": "p", "conversation_id": big, "user_message": "ciao"}
        ).status_code
        == 422
    )
    assert (
        client.post("/account/consents", json={"consent_key": big, "granted": True}).status_code
        == 422
    )
    assert (
        client.post(
            "/billing/purchases/restore",
            json={"store": "apple", "store_subscription_ids": [big]},
        ).status_code
        == 422
    )
