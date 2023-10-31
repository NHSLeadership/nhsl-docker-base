pipeline {
    agent any

    stages {
        stage('Build Openresty Image') {
            steps {
                sh 'make build-openresty TAG=${GIT_BRANCH#*/} REPO="nhsleadershipacademy/"'
            }
        }
    }
}