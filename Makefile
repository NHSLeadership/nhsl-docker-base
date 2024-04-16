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
	@echo "    build-php72		Builds a PHP 7.2 image"
	@echo "    build-php73		Builds a PHP 7.3 image"
	@echo "    build-php74		Builds a PHP 7.4 image"
	@echo "    build-php80		Builds a PHP 8.0 image"
	@echo "    build-php81		Builds a PHP 8.1 image"
	@echo "    build-php82		Builds a PHP 8.2 image"
	@echo "    build-php82		Builds a PHP 8.3 image"
	@echo ""
	@echo "!! Test containers will be available at http://localhost:8080 once running."
	@echo "    test-php72		Builds and runs a Docker stack on port 8080 to test PHP 7.2"
	@echo "    test-php73		Builds and runs a Docker stack on port 8080 to test PHP 7.3"
	@echo "    test-php74		Builds and runs a Docker stack on port 8080 to test PHP 7.4"
	@echo "    test-php80		Builds and runs a Docker stack on port 8080 to test PHP 8.0"
	@echo "    test-php81		Builds and runs a Docker stack on port 8080 to test PHP 8.1"
	@echo "    test-php82		Builds and runs a Docker stack on port 8080 to test PHP 8.2"
	@echo "    test-php83		Builds and runs a Docker stack on port 8080 to test PHP 8.3"
	@echo ""

build-all:
	build-openresty build-php72 build-php73 build-php74 build-php80 build-php81 build-php82

build-openresty:
	docker build -t ${REPO}nhsl-ubuntu-openresty:${TAG} -f ./openresty/Dockerfile ./openresty/

build-php72:
	@echo "$$(tr -d '\r' < ./phpfpm/php72.txt)" > ./phpfpm/php72.txt
	docker build --no-cache --build-arg PHP_VERSION=7.2 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php72.txt)" -t ${REPO}nhsl-ubuntu-phpv2:7.2-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php73:
	@echo "$$(tr -d '\r' < ./phpfpm/php73.txt)" > ./phpfpm/php73.txt
	docker build --no-cache --build-arg PHP_VERSION=7.3 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php73.txt)" -t ${REPO}nhsl-ubuntu-phpv2:7.3-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php74:
	@echo "$$(tr -d '\r' < ./phpfpm/php74.txt)" > ./phpfpm/php74.txt
	docker build --no-cache --build-arg PHP_VERSION=7.4 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php74.txt)" -t ${REPO}nhsl-ubuntu-phpv2:7.4-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php80:
	@echo "$$(tr -d '\r' < ./phpfpm/php80.txt)" > ./phpfpm/php80.txt
	docker build --no-cache --build-arg PHP_VERSION=8.0 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php80.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.0-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php81:
	@echo "$$(tr -d '\r' < ./phpfpm/php81.txt)" > ./phpfpm/php81.txt
	docker build --no-cache --build-arg PHP_VERSION=8.1 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php81.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.1-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php82:
	@echo "$$(tr -d '\r' < ./phpfpm/php82.txt)" > ./phpfpm/php82.txt
	docker build --no-cache --build-arg PHP_VERSION=8.2 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php82.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.2-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php83:
	@echo "$$(tr -d '\r' < ./phpfpm/php83.txt)" > ./phpfpm/php83.txt
	docker build --no-cache --build-arg PHP_VERSION=8.3 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php83.txt)" -t ${REPO}nhsl-ubuntu-phpv2:8.3-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

test-php72:
	@echo "$$(tr -d '\r' < ./phpfpm/php72.txt)" > ./phpfpm/php72.txt
	env phpmods="$$(cat ./phpfpm/php72.txt)" env phpvers=7.2 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php73:
	@echo "$$(tr -d '\r' < ./phpfpm/php73.txt)" > ./phpfpm/php73.txt
	env phpmods="$$(cat ./phpfpm/php73.txt)" env phpvers=7.3 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php74:
	@echo "$$(tr -d '\r' < ./phpfpm/php74.txt)" > ./phpfpm/php74.txt
	env phpmods="$$(cat ./phpfpm/php74.txt)" env phpvers=7.4 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php80:
	@echo "$$(tr -d '\r' < ./phpfpm/php80.txt)" > ./phpfpm/php80.txt
	env phpmods="$$(cat ./phpfpm/php80.txt)" env phpvers=8.0 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php81:
	@echo "$$(tr -d '\r' < ./phpfpm/php81.txt)" > ./phpfpm/php81.txt
	env phpmods="$$(cat ./phpfpm/php81.txt)" env phpvers=8.1 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php82:
	@echo "$$(tr -d '\r' < ./phpfpm/php82.txt)" > ./phpfpm/php82.txt
	env phpmods="$$(cat ./phpfpm/php82.txt)" env phpvers=8.2 docker-compose -f tests/docker-compose.yml up --build --force-recreate

test-php83:
	@echo "$$(tr -d '\r' < ./phpfpm/php83.txt)" > ./phpfpm/php83.txt
	env phpmods="$$(cat ./phpfpm/php83.txt)" env phpvers=8.3 docker-compose -f tests/docker-compose.yml up --build --force-recreate