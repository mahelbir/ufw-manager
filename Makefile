IMAGE=mahelbir/ufw-manager
VERSION=1.0.0

dev:
	docker compose -f docker-compose.dev.yaml up --build --force-recreate

push:
	docker buildx build \
	  --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6,linux/386 \
	  -t $(IMAGE):$(VERSION) \
	  -t $(IMAGE):latest \
	  --push .