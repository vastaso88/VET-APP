PYTHON ?= python
UV ?= uv

setup:
	$(UV) sync --all-extras

format:
	$(UV) run ruff format .

lint:
	$(UV) run ruff check .

typecheck:
	$(UV) run mypy apps packages tests

test:
	$(UV) run pytest

eval:
	$(UV) run python scripts/eval/run_evaluation.py

run-api:
	$(UV) run uvicorn apps.api.main:app --reload

run-web:
	cd apps/mobile_app && flutter pub get && flutter run -d chrome

run-web-server:
	cd apps/mobile_app && flutter pub get && flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080

build-web:
	cd apps/mobile_app && flutter pub get && flutter build web
