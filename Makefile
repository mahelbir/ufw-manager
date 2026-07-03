IMAGE=mahelbir/ufw-manager
VERSION=2.1.0

BUMP := $(word 2,$(MAKECMDGOALS))

dev:
	make test
	docker compose -f docker-compose.dev.yaml up -d --build --force-recreate


push:
	docker buildx build \
	  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/386 \
	  -t $(IMAGE):$(VERSION) \
	  -t $(IMAGE):latest \
	  --push .


test:
	bash -n src/ufw-manager
	docker run --rm -v "$(CURDIR)/src:/work" -w /work \
	  koalaman/shellcheck-alpine \
	  shellcheck ufw-manager


version:
	@case "$(BUMP)" in \
	  patch|minor|major) ;; \
	  *) echo "usage: make version <patch|minor|major>"; exit 1 ;; \
	esac; \
	if [ -n "$$(git status --porcelain)" ]; then \
	  echo "working tree not clean; commit or stash first"; exit 1; \
	fi; \
	cur="$(VERSION)"; \
	major="$${cur%%.*}"; rest="$${cur#*.}"; minor="$${rest%%.*}"; patch="$${rest#*.}"; \
	case "$(BUMP)" in \
	  major) major=$$((major + 1)); minor=0; patch=0 ;; \
	  minor) minor=$$((minor + 1)); patch=0 ;; \
	  patch) patch=$$((patch + 1)) ;; \
	esac; \
	new="$$major.$$minor.$$patch"; \
	sed -i.bak "s/^VERSION=.*/VERSION=$$new/" Makefile && rm -f Makefile.bak; \
	git add Makefile; \
	git commit -m "$$new"; \
	git tag "v$$new"; \
	echo "bumped $(VERSION) -> $$new; tagged v$$new (next: make push && git push --follow-tags)"

patch minor major:
	@:

.PHONY: dev push test version patch minor major
