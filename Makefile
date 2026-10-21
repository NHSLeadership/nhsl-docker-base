ifndef TAG
	TAG := dev
endif

help:
	@echo ""
	@echo "usage: make COMMAND VAR1=something VAR2=something [...]"
	@echo ""
	@echo "Vars:"
	@echo "    REPO		default is blank. Prepends a Docker repo name. <repo>/<image>:<tag>"
	@echo "    TAG		default 'dev'. Appends a Docker tag <repo>/<image>:<tag>"
	@echo ""
	@echo "Commands:"
	@echo "    build-all		Builds all PHP and Openresty images with the same tag"
	@echo "    build-openresty	Builds the NHSLA Openresty image"
	@echo "    build-php82		Builds a PHP 8.2 image"
	@echo "    build-php82		Builds a PHP 8.3 image"
	@echo "    build-php83          Builds a PHP 8.3 image"
	@echo "    build-php84          Builds a PHP 8.4 image"
	@echo ""
	@echo "!! Test containers will be available at http://localhost:8080 once running."
	@echo "    test-php82		Builds and runs a Docker stack on port 8080 to test PHP 8.2"
	@echo "    test-php83		Builds and runs a Docker stack on port 8080 to test PHP 8.3"
	@echo "    test-php84           Builds and runs a Docker stack on port 8080 to test PHP 8.4"
	@echo ""

build-all:
	build-openresty build-php82 build-php83 build-php84

build-openresty:
	docker build --platform linux/amd64,linux/arm64 -t ${REPO}nhsl-ubuntu-openresty:${TAG} -f ./openresty/Dockerfile ./openresty/

build-php82:
	@echo "$$(tr -d '\r' < ./phpfpm/php82.txt)" > ./phpfpm/php82.txt
	docker build --platform linux/amd64,linux/arm64 --no-cache --build-arg PHP_VERSION=8.2 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php82.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.2-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php83:
	@echo "$$(tr -d '\r' < ./phpfpm/php83.txt)" > ./phpfpm/php83.txt
	docker build --platform linux/amd64,linux/arm64 --no-cache --build-arg PHP_VERSION=8.3 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php83.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.3-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php84:
	@echo "$$(tr -d '\r' < ./phpfpm/php84.txt)" > ./phpfpm/php84.txt
	docker build --platform linux/amd64,linux/arm64 --no-cache --build-arg PHP_VERSION=8.4 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php84.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.4-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

test-php82:
	@echo "$$(tr -d '\r' < ./phpfpm/php82.txt)" > ./phpfpm/php82.txt
	env phpmods="$$(cat ./phpfpm/php82.txt)" env phpvers=8.2 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php83:
	@echo "$$(tr -d '\r' < ./phpfpm/php83.txt)" > ./phpfpm/php83.txt
	env phpmods="$$(cat ./phpfpm/php83.txt)" env phpvers=8.3 docker compose -f tests/docker-compose.yml up --build --force-recreate

test-php84:
	@echo "$$(tr -d '\r' < ./phpfpm/php84.txt)" > ./phpfpm/php84.txt
	env phpmods="$$(cat ./phpfpm/php84.txt)" env phpvers=8.4 docker compose -f tests/docker-compose.yml up --build --force-recreate
