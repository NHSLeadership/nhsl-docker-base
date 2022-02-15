help:
	@echo ""
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "    build-php72			Builds a PHP 7.2 image"
	@echo ""

build-php72:
	@echo "$$(tr -d '\r' < ./phpfpm/php72.txt)" > ./phpfpm/php72.txt
	docker build --build-arg PHP_VERSION=7.2 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php72.txt)" -t nhsla-php72:latest -f ./phpfpm/Dockerfile ./phpfpm/

build-php73:
	@echo "$$(tr -d '\r' < ./phpfpm/php73.txt)" > ./phpfpm/php73.txt
	docker build --build-arg PHP_VERSION=7.3 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php73.txt)" -t nhsla-php73:latest -f ./phpfpm/Dockerfile ./phpfpm/

build-php74:
	@echo "$$(tr -d '\r' < ./phpfpm/php74.txt)" > ./phpfpm/php74.txt
	docker build --build-arg PHP_VERSION=7.4 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php74.txt)" -t nhsla-php74:latest -f ./phpfpm/Dockerfile ./phpfpm/

build-php80:
	@echo "$$(tr -d '\r' < ./phpfpm/php80.txt)" > ./phpfpm/php80.txt
	docker build --build-arg PHP_VERSION=8.0 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php80.txt)" -t nhsla-php80:latest -f ./phpfpm/Dockerfile ./phpfpm/

build-php81:
	@echo "$$(tr -d '\r' < ./phpfpm/php81.txt)" > ./phpfpm/php81.txt
	docker build --build-arg PHP_VERSION=8.1 --build-arg PHP_PACKAGES="$$(cat ./phpfpm/php81.txt)" -t nhsla-php81:latest -f ./phpfpm/Dockerfile ./phpfpm/