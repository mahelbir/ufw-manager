IMAGE=mahelbir/ufw-manager
VERSION=2.1.0

dev:
	docker compose -f docker-compose.dev.yaml up -d --build --force-recreate


push:
	docker buildx build \
	  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/386 \
	  -t $(IMAGE):$(VERSION) \
	  -t $(IMAGE):latest \
	  --push .


lint:
	bash -n src/ufw-manager
	docker run --rm -v "$(CURDIR)/src:/work" -w /work \
	  koalaman/shellcheck-alpine \
	  shellcheck ufw-manager

.PHONY: dev push lint