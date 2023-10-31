pipeline {
    agent any

    stages {
        stage('Build Docker Images') {
            parallel {
                stage('Build Openresty Image') {
                    steps {
                        sh 'make build-openresty TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-openresty TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
                stage('Build PHP 7.2 Image') {
                    steps {
                        sh 'make build-php72 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-php72 TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
                stage('Build PHP 7.3 Image') {
                    steps {
                        sh 'make build-php73 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-php73 TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
                stage('Build PHP 7.4 Image') {
                    steps {
                        sh 'make build-php74 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-php74 TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
                stage('Build PHP 8.0 Image') {
                    steps {
                        sh 'make build-php80 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-php80 TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
                stage('Build PHP 8.1 Image') {
                    steps {
                        sh 'make build-php81 TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
                        sh 'make build-php81 TAG=${GIT_BRANCH#*/} REPO="481015924503.dkr.ecr.eu-west-2.amazonaws.com/"'
                    }
                }
            }
        }
        stage('Push Docker Images') {
            parallel {
                stage('Push Openresty Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-openresty:${GIT_BRANCH#*/}'
                }
                stage('Push PHP 7.2 Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-phpv2:7.2-${GIT_BRANCH#*/}'
                        sh 'docker push nhsleadershipacademy/nhsl-ubuntu-phpv2:7.2-${GIT_BRANCH#*/}'
                }
                stage('Push PHP 7.3 Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-phpv2:7.3-${GIT_BRANCH#*/}'
                        sh 'docker push nhsleadershipacademy/nhsl-ubuntu-phpv2:7.3-${GIT_BRANCH#*/}'
                }
                stage('Push PHP 7.4 Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-phpv2:7.4-${GIT_BRANCH#*/}'
                        sh 'docker push nhsleadershipacademy/nhsl-ubuntu-phpv2:7.4-${GIT_BRANCH#*/}'
                }
                stage('Push PHP 8.0 Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-phpv2:8.0-${GIT_BRANCH#*/}'
                        sh 'docker push nhsleadershipacademy/nhsl-ubuntu-phpv2:8.0-${GIT_BRANCH#*/}'
                }
                stage('Push PHP 8.1 Image to ECR and DockerHub') {
                        sh 'docker push 481015924503.dkr.ecr.eu-west-2.amazonaws.com/nhsl-ubuntu-phpv2:8.1-${GIT_BRANCH#*/}'
                        sh 'docker push nhsleadershipacademy/nhsl-ubuntu-phpv2:8.1-${GIT_BRANCH#*/}'
                }
                
            }
        }
    }
}