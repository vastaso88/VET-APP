"""Food, supplements and products with an active substance on the Mercatino (owner
decisions of 2026-11-23): what is refused, what needs a confirmation, what the team can
do afterwards. Synthetic data only."""

import pytest

from packages.core.application.services.create_listing import (
    CreateListingInput,
    CreateListingService,
)
from packages.core.application.services.listing_review import (
    ListingReviewConflictError,
    ListingReviewNotFoundError,
    ListingReviewService,
)
from packages.core.application.services.update_listing import (
    UpdateListingInput,
    UpdateListingService,
)
from packages.core.domain.geo.models import Coordinates
from packages.core.domain.marketplace.content_policy import (
    MEDICINE_POLICY_MESSAGE,
    offers_active_substances,
    offers_medicines,
)
from packages.core.domain.marketplace.content_review import (
    ContentNotice,
    ListingReview,
    highlighted,
    notices_for,
    sensitive_terms,
)
from packages.core.domain.marketplace.models import MarketplaceListing
from packages.infrastructure.persistence.in_memory_listing_reviews import (
    InMemoryListingReviewRepository,
)
from packages.infrastructure.persistence.in_memory_repositories import (
    InMemoryListingReportRepository,
    InMemoryMarketplaceListingRepository,
)
from packages.infrastructure.storage.listing_photo_vaults import InMemoryListingPhotoVault
from packages.shared.errors.base import RequirementMissingError, ValidationError

OWNER = "user-a"
ADMIN = "admin-1"
PLACE = Coordinates(latitude=45.46, longitude=9.19)


# --- what is refused -------------------------------------------------------------


@pytest.mark.parametrize(
    "text",
    [
        "Collare antipulci nuovo",
        "Collare per cani antipulci",
        "Collare anti-zecche",
        "Collare contro le pulci",
        "Pipette antiparassitarie",
        "Pipetta antipulci per gatti",
        "Pipette spot-on",
        "Spot-on per gatti",
        "Spot on gatto 3 pezzi",
        "Antiparassitario spot-on",
        "Spot-on treatment",
        "Spot-on für Katzen",
        "Spray antiparassitario",
        "Compresse antipulci",
        "Prodotto antizecche",
        "Shampoo antipulci",
        "Shampoo medicato",
        "Shampoo antiparassitario",
        "Seresto taglia M",
        "Frontline gatto",
        "Flea collar, never opened",
        "Flea & tick collar",
        "Anti-tick spray",
        "Medicated shampoo",
        "Collar antipulgas",
        "Champú medicado",
        "Pipetas antiparasitarias",
        "Flohhalsband",
        "Zeckenhalsband, neu",
        "Anti-Floh-Shampoo",
        "Collier antipuces",
        "Shampooing antiparasitaire",
    ],
)
def test_unequivocal_active_substances_are_refused(text: str) -> None:
    assert offers_active_substances(text)


@pytest.mark.parametrize(
    "text",
    [
        "Pettine antipulci",
        "Antipulci",
        "Antiparassitario",
        "Shampoo delicato",
        "Shampoo per cani",
        "Champú para perros",
        "Pinza antizecche",
        "Flea comb",
        "Tick remover tool",
        "Flohkamm",
        "Zeckenzange",
        "Peigne antipuces",
        "Peine antipulgas",
        "Collare in pelle",
        "Collare elastico, taglia M",
        "Spray bottle for training",
        "Flea market find: a lovely dog bed",
        "Lovely bed, the colour is spot on",
    ],
)
def test_combs_tools_and_bare_words_are_not_refused(text: str) -> None:
    assert not offers_active_substances(text)
    assert not offers_medicines(text)


# --- what needs a confirmation ---------------------------------------------------


@pytest.mark.parametrize(
    ("text", "notices"),
    [
        ("Crocchette 12 kg", ["food"]),
        ("Ciotola per crocchette", ["food"]),
        ("Croccantini e scatolette", ["food"]),
        ("Fieno per conigli", ["food"]),
        ("Semi per canarini", ["food"]),
        ("Snack dentali", ["food"]),
        ("Ossa da masticare", ["food"]),
        ("Integratore per articolazioni", ["food"]),
        ("Vitamine per cani", ["food"]),
        ("Latte in polvere per gattini", ["food"]),
        ("Olio di salmone", ["food"]),
        ("Pasta al malto", ["food"]),
        ("Dry food for puppies", ["food"]),
        ("Dog treats", ["food"]),
        ("Pienso para gatos", ["food"]),
        ("Trockenfutter 10 kg", ["food"]),
        ("Kausnacks", ["food"]),
        ("Nahrungsergänzung für Hunde", ["food"]),
        ("Pâtée pour chat", ["food"]),
        ("Pettine antipulci", ["active_substance"]),
        ("Antiparassitario", ["active_substance"]),
        ("Shampoo delicato", ["active_substance"]),
        ("Flea comb", ["active_substance"]),
        ("Peigne antipuces", ["active_substance"]),
        ("Shampoo e crocchette", ["food", "active_substance"]),
    ],
)
def test_sensitive_words_call_for_their_notice(text: str, notices: list[str]) -> None:
    assert notices_for(sensitive_terms(text)) == notices


@pytest.mark.parametrize(
    "text",
    [
        "Cuccia imbottita",
        "Ciotola in acciaio",
        "Trasportino per gatti",
        "Osso di gomma",
        "Cappottino per chow chow",
        "Futternapf aus Edelstahl",
        "Futterspender",
        "Collare in pelle",
        "Comprata al mercatino delle pulci",
        "Pienso que es nuevo",
        "Panier pour chien",
    ],
)
def test_accessories_need_nothing(text: str) -> None:
    assert sensitive_terms(text) == []


def test_the_portal_gets_the_words_already_marked() -> None:
    pieces = highlighted("Ciotola per Crocchette, nuova")

    assert [piece["text"] for piece in pieces if piece["hit"]] == ["Crocchette"]
    assert "".join(str(piece["text"]) for piece in pieces) == "Ciotola per Crocchette, nuova"


# --- publishing and editing ------------------------------------------------------


class _Market:
    def __init__(self) -> None:
        self.listings = InMemoryMarketplaceListingRepository()
        self.reviews = InMemoryListingReviewRepository()
        self.vault = InMemoryListingPhotoVault()
        self.vault.public = {"user-a/ad/1.jpg", "user-a/ad/2.jpg"}
        self.reports = InMemoryListingReportRepository()
        self.service = ListingReviewService(self.listings, self.reviews, self.vault, self.reports)

    def publish(
        self,
        title: str,
        *confirmations: ContentNotice,
        description: str | None = None,
        photos: list[str] | None = None,
        owner: str = OWNER,
    ) -> MarketplaceListing:
        return (
            CreateListingService(self.listings, self.reviews, self.vault)
            .execute(
                CreateListingInput(
                    owner_id=owner,
                    title=title,
                    description=description,
                    category="toys",
                    condition="good",
                    exact_location=PLACE,
                    photo_urls=photos or [],
                    content_confirmations=list(confirmations),
                )
            )
            .listing
        )

    def edit(
        self,
        listing: MarketplaceListing,
        *confirmations: ContentNotice,
        title: str | None = None,
        photos: list[str] | None = None,
        price_cents: int | None = None,
    ) -> MarketplaceListing:
        return (
            UpdateListingService(self.listings, self.reviews, self.vault)
            .execute(
                UpdateListingInput(
                    owner_id=listing.owner_id,
                    listing_id=listing.id,
                    title=title if title is not None else listing.title,
                    description=listing.description,
                    category=listing.category,
                    condition=listing.condition,
                    exact_location=PLACE,
                    photo_urls=photos if photos is not None else listing.photo_urls,
                    price_cents=price_cents,
                    content_confirmations=list(confirmations),
                )
            )
            .listing
        )

    def status(self, listing: MarketplaceListing) -> str:
        current = self.listings.get(listing.id)
        assert current is not None
        return current.status

    def all_reviews(self, listing: MarketplaceListing) -> list[ListingReview]:
        return sorted(
            self.reviews.list_by_listings([listing.id]), key=lambda item: item.confirmed_at
        )

    def open_review(self, listing: MarketplaceListing) -> ListingReview:
        (review,) = [item for item in self.all_reviews(listing) if item.status == "open"]
        return review


@pytest.fixture
def market() -> _Market:
    return _Market()


def test_a_medicine_is_refused_and_nothing_of_it_is_kept(market: _Market) -> None:
    with pytest.raises(ValidationError) as refused:
        market.publish("Collare antipulci", "food", "active_substance")

    # The installed apps compare this sentence: it never changes.
    assert str(refused.value) == MEDICINE_POLICY_MESSAGE
    assert market.listings.list_by_owner(OWNER, 10) == []
    assert market.reviews.items == {}


def test_food_without_the_box_is_not_published(market: _Market) -> None:
    with pytest.raises(RequirementMissingError) as refused:
        market.publish("Ciotola per crocchette")

    assert refused.value.code == "content_confirmation_required"
    assert refused.value.fix == {
        "field": "content_confirmations",
        "value": ["food"],
        "terms": [{"notice": "food", "text": "crocchette"}],
    }
    assert market.listings.list_by_owner(OWNER, 10) == []


def test_the_wrong_box_is_not_enough(market: _Market) -> None:
    with pytest.raises(RequirementMissingError):
        market.publish("Pettine antipulci", "food")
    with pytest.raises(RequirementMissingError):
        market.publish("Shampoo e crocchette", "food")


def test_once_confirmed_the_ad_is_online_at_once_and_to_be_checked(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    assert market.status(listing) == "active"
    review = market.open_review(listing)
    assert review.terms == ["crocchette"]
    assert review.notices == ["food"]
    assert review.confirmation_version


def test_an_accessory_opens_no_check(market: _Market) -> None:
    listing = market.publish("Cuccia imbottita")

    assert market.status(listing) == "active"
    assert market.reviews.items == {}


def test_without_the_record_of_the_confirmation_the_ad_does_not_go_online(
    market: _Market, monkeypatch: pytest.MonkeyPatch
) -> None:
    def broken(_review: ListingReview) -> ListingReview:
        raise RuntimeError("database down")

    monkeypatch.setattr(market.reviews, "save", broken)
    with pytest.raises(RuntimeError):
        market.publish("Ciotola per crocchette", "food")

    assert market.listings.list_by_owner(OWNER, 10) == [], "nothing left behind either"


def test_a_bowl_cannot_become_kibble_without_a_new_confirmation(market: _Market) -> None:
    listing = market.publish("Cuccia imbottita")

    with pytest.raises(RequirementMissingError):
        market.edit(listing, title="Crocchette 12 kg")
    with pytest.raises(ValidationError, match="farmaci"):
        market.edit(listing, "food", "active_substance", title="Pipette antipulci")

    unchanged = market.listings.get(listing.id)
    assert unchanged is not None and unchanged.title == "Cuccia imbottita"


def test_a_new_price_needs_no_new_confirmation(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    market.edit(listing, price_cents=900)

    assert len(market.all_reviews(listing)) == 1


@pytest.mark.parametrize(
    "change",
    [{"title": "Ciotola grande per crocchette"}, {"photos": ["user-a/ad/2.jpg"]}],
)
def test_new_text_or_photos_need_the_confirmation_again_and_another_check(
    market: _Market, change: dict[str, object]
) -> None:
    listing = market.publish("Ciotola per crocchette", "food", photos=["user-a/ad/1.jpg"])

    with pytest.raises(RequirementMissingError):
        market.edit(listing, **change)  # type: ignore[arg-type]
    market.edit(listing, "food", **change)  # type: ignore[arg-type]

    assert [item.status for item in market.all_reviews(listing)] == ["superseded", "open"]
    assert market.status(listing) == "active"


def test_a_checked_ad_is_checked_again_after_an_edit(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    market.service.decide(market.open_review(listing).id, "checked", admin_id=ADMIN)

    market.edit(listing, "food", title="Distributore di crocchette")

    assert [item.status for item in market.all_reviews(listing)] == ["checked", "open"]


def test_when_the_words_go_away_the_check_is_closed(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    market.edit(listing, title="Ciotola in acciaio")

    assert [item.status for item in market.all_reviews(listing)] == ["superseded"]
    assert market.service.queue() == []


# --- the team --------------------------------------------------------------------


def test_the_queue_shows_what_is_to_be_checked_first(market: _Market) -> None:
    first = market.publish("Ciotola per crocchette", "food")
    second = market.publish("Pettine antipulci", "active_substance")
    market.service.decide(market.open_review(first).id, "checked", admin_id=ADMIN)

    rows = market.service.queue()

    assert [(row["listing_id"], row["status"]) for row in rows] == [
        (second.id, "open"),
        (first.id, "checked"),
    ]
    assert rows[1]["decided_by_admin_id"] == ADMIN and rows[1]["decided_at"]


def test_the_detail_marks_the_words(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    detail = market.service.detail(market.open_review(listing).id)

    assert detail is not None
    assert {"text": "crocchette", "hit": True} in detail["highlighted_title"]  # type: ignore[operator]


def test_checked_leaves_the_ad_online_and_is_recorded(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    market.service.decide(market.open_review(listing).id, "checked", admin_id=ADMIN)

    assert market.status(listing) == "active"
    assert [item.outcome for item in market.reviews.decisions] == ["checked"]


def test_removed_hides_the_ad_with_a_reason_and_the_seller_cannot_edit_it(
    market: _Market,
) -> None:
    listing = market.publish("Ciotola per crocchette", "food")

    market.service.decide(
        market.open_review(listing).id, "removed", admin_id=ADMIN, reason="food", note="  vende  "
    )

    assert market.status(listing) == "removed_policy"
    (review,) = market.all_reviews(listing)
    assert (review.status, review.removal_reason, review.note) == ("removed", "food", "vende")
    with pytest.raises(ValidationError, match="non si può più modificare"):
        market.edit(listing, "food", title="Ciotola")


def test_an_ad_already_checked_can_still_be_removed_later(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    review_id = market.open_review(listing).id
    market.service.decide(review_id, "checked", admin_id=ADMIN)

    market.service.decide(review_id, "removed", admin_id=ADMIN, reason="food")

    assert market.status(listing) == "removed_policy"


def test_a_review_asked_by_the_seller_can_bring_the_ad_back(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    review_id = market.open_review(listing).id
    market.service.decide(review_id, "removed", admin_id=ADMIN, reason="other")

    market.service.decide(review_id, "restored", admin_id=ADMIN)

    assert market.status(listing) == "active"
    (review,) = market.all_reviews(listing)
    assert review.status == "checked" and review.removal_reason is None
    assert [item.outcome for item in market.reviews.decisions] == ["removed", "restored"]


def test_nothing_is_decided_on_a_text_the_admin_has_not_seen(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    seen = market.open_review(listing).id
    market.edit(listing, "food", title="Distributore di crocchette")

    with pytest.raises(ListingReviewConflictError):
        market.service.decide(seen, "removed", admin_id=ADMIN, reason="food")

    assert market.status(listing) == "active"
    assert market.reviews.decisions == []


def test_a_decision_cannot_be_taken_twice_nor_on_a_sold_ad(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    review_id = market.open_review(listing).id
    market.service.decide(review_id, "removed", admin_id=ADMIN, reason="food")

    with pytest.raises(ListingReviewConflictError):
        market.service.decide(review_id, "removed", admin_id=ADMIN, reason="food")
    with pytest.raises(ListingReviewConflictError):
        market.service.decide(review_id, "checked", admin_id=ADMIN)

    sold = market.publish("Pettine antipulci", "active_substance")
    market.listings.save(sold.model_copy(update={"status": "sold"}))
    with pytest.raises(ListingReviewConflictError):
        market.service.decide(
            market.open_review(sold).id, "removed", admin_id=ADMIN, reason="medicine"
        )
    with pytest.raises(ListingReviewConflictError):
        market.service.decide(market.open_review(sold).id, "restored", admin_id=ADMIN)


def test_a_missing_check_is_not_found(market: _Market) -> None:
    with pytest.raises(ListingReviewNotFoundError):
        market.service.decide("nope", "checked", admin_id=ADMIN)
    assert market.service.detail("nope") is None


def test_the_register_holds_no_seller_and_no_text(market: _Market) -> None:
    listing = market.publish("Ciotola per crocchette", "food")
    market.service.decide(
        market.open_review(listing).id, "removed", admin_id=ADMIN, reason="food", note="nota"
    )

    (entry,) = market.reviews.decisions
    assert set(entry.model_dump()) == {
        "id",
        "listing_id",
        "outcome",
        "reason",
        "admin_id",
        "decided_at",
    }
    assert OWNER not in entry.model_dump_json() and "crocchette" not in entry.model_dump_json()


def test_each_seller_finds_only_their_own_ads(market: _Market) -> None:
    mine = market.publish("Ciotola per crocchette", "food")
    market.publish("Pettine antipulci", "active_substance", owner="user-b")

    assert [item.listing.id for item in market.service.own_listings(OWNER)] == [mine.id]
