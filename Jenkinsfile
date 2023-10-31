pipeline {
    agent any

    stages {
        stage('Build Docker Images') {
            parallel {
                stage('Build Openresty Image') {
                    steps {
                        sh 'make build-openresty TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
                stage('Build PHP 7.2 Image') {
                    steps {
                        sh 'make build-php72 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
                stage('Build PHP 7.3 Image') {
                    steps {
                        sh 'make build-php73 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
                stage('Build PHP 7.4 Image') {
                    steps {
                        sh 'make build-php74 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
                stage('Build PHP 8.0 Image') {
                    steps {
                        sh 'make build-php80 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
                stage('Build PHP 8.1 Image') {
                    steps {
                        sh 'make build-php81 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                    }
                }
            }
        }
    }
}