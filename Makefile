ifndef TAG
	TAG := dev
endif

help:
	@echo ""
	@echo "usage: make COMMAND VAR1=something VAR2=something [...]"
	@echo ""
	@echo "Vars:"
	@echo "    TAG		default 'dev' otherwise please specify as TAG=main etc."
	@echo ""
	@echo "Commands:"
	@echo "    build-all		Builds all PHP and Openresty images with the same tag"
	@echo "    build-php72		Builds a PHP 7.2 image"
	@echo "    build-php73		Builds a PHP 7.3 image"
	@echo "    build-php74		Builds a PHP 7.4 image"
	@echo "    build-php80		Builds a PHP 8.0 image"
	@echo "    build-php81		Builds a PHP 8.1 image"
	@echo ""

build-all:
	build-php72 build-php73 build-php74 build-php80 build-php81

build-php72:
	@echo "$$(tr -d '\r' < ./phpfpm/php72.txt)" > ./phpfpm/php72.txt
	docker build --build-arg PHP_VERSION=7.2 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php72.txt)" -t nhsl-ubuntu-phpv2:7.2-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php73:
	@echo "$$(tr -d '\r' < ./phpfpm/php73.txt)" > ./phpfpm/php73.txt
	docker build --build-arg PHP_VERSION=7.3 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php73.txt)" -t nhsl-ubuntu-phpv2:7.3-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php74:
	@echo "$$(tr -d '\r' < ./phpfpm/php74.txt)" > ./phpfpm/php74.txt
	docker build --build-arg PHP_VERSION=7.4 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php74.txt)" -t nhsl-ubuntu-phpv2:7.4-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php80:
	@echo "$$(tr -d '\r' < ./phpfpm/php80.txt)" > ./phpfpm/php80.txt
	docker build --build-arg PHP_VERSION=8.0 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php80.txt)" -t nhsl-ubuntu-phpv2:8.0-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-php81:
	@echo "$$(tr -d '\r' < ./phpfpm/php81.txt)" > ./phpfpm/php81.txt
	docker build --build-arg PHP_VERSION=8.1 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php81.txt)" -t nhsl-ubuntu-phpv2:8.1-${TAG} -f ./phpfpm/Dockerfile ./phpfpm/

build-openresty:
	docker build -t nhsl-ubuntu-openresty:${TAG} -f ./openresty/Dockerfile ./openresty/