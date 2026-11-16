"""The plan rules on what the app writes straight into the database.

The app writes some tables with the publishable key and the owner's own token,
without going through the backend (inventory and decision:
docs/security/11_scritture_dirette_piano_proposta.md, owner decisions
2026-11-09). Row-level security there only checks that the row is the
owner's, so the plan rules are enforced in the database as well, by
scripts/setup/plan_access_rules.sql, which
scripts/maintenance/gen_plan_access_sql.py writes from this module and from
limits.py. A test fails when the script is out of date.

After the trial an owner without a plan may read, export and delete their own
data, never add or change it (Terms it/03 §4). Writes made by the backend
(service role) are not touched: the backend applies the same rules itself.
"""

# Tables the app inserts into or updates directly: after the trial, refused.
# Deletes stay allowed on every one of them (erasing one's own data).
GATED_TABLES: tuple[str, ...] = (
    "pet_profiles",
    "clinical_events",
    "pet_conditions",
    "reminders",
    "dog_walks",
    "pet_weight_measurements",
    "pet_photos",
    "local_activities",
)

# The one write an owner WITHOUT a plan may still make (owner decision 2026-11-16):
# moving a pet to Ricordi, i.e. `is_memorial` from false to true on a profile that
# exists, with the date of the loss. Someone who loses an animal after the trial
# must not meet a paywall to stop its reminders, medicines and birthday wishes;
# the move takes no place of the plan and costs nothing. Every other write stays
# refused, bringing the pet back among the animals included.
MEMORIAL_MOVE_TABLE = "pet_profiles"

# Written directly too, but deliberately outside the rule (owner decision
# 2026-11-09): the place the owner set has no value for a plan, and a report
# is a safety tool that must keep working for everyone.
EXEMPT_TABLES: tuple[str, ...] = ("user_locations", "marketplace_listing_reports")

# The storage bucket of pet photos, videos and the profile photo: uploading
# (and replacing) is refused after the trial, removing is not.
GATED_BUCKET = "pet-photos"

# What the database answers, the same codes the backend uses (apps/api/main.py),
# so the app recognises one set. PostgREST turns SQLSTATE "PTxyz" into HTTP xyz.
SUBSCRIPTION_REQUIRED_CODE = "subscription_required"
SUBSCRIPTION_REQUIRED_SQLSTATE = "PT402"
PLAN_LIMIT_CODE = "plan_limit_reached"
PLAN_LIMIT_SQLSTATE = "PT403"
# `details` of a plan-limit refusal: which allowance, as in PlanLimitError.kind.
PETS_LIMIT_KIND = "pets"
# The cap on pets kept in Ricordi (limits.DEFAULT_MAX_MEMORIAL_PETS): same code,
# its own `details`, hint = the cap. Raised only when a pet is moved to Ricordi.
MEMORIALS_LIMIT_KIND = "memorials"
