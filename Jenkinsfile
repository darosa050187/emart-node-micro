def notifySlack(String buildStatus) {
    def colorCode = buildStatus == 'SUCCESS' ? '#36a64f' : '#ff0000'
    def summary = "*Job:* ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                 "*Status:* ${buildStatus}\n" +
                 "*Duration:* ${currentBuild.durationString}\n" +
                 "*Details:* ${env.BUILD_URL}"

    slackSend(
        channel: env.SLACK_CHANNEL,
        color: colorCode,
        message: summary,
        tokenCredentialId: env.SLACK_CREDENTIALS_ID
    )
}
pipeline{
    agent any 
    environment{
        REQUIRED_TOOLS = "docker, aws, nodejs"
        BRANCH_NAME = "feature-json-release"
        PROJECT_NAME = "emart-jsonapi-micro"
        ARTIFACT_NAME = "book-work-0.0.1-SNAPSHOT.jar"
        GIT_REPO_URL = "https://github.com/darosa050187/emart-node-micro.git"
        AWS_REGION = "us-east-1"
        ECR_REGISTRY_URI = "https://084828572941.dkr.ecr.us-east-1.amazonaws.com"
        ECR_REGISTRY_REPO = "084828572941.dkr.ecr.us-east-1.amazonaws.com"
        ECR_REGISTRY_NAME = "emart-emartapi-repository"
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        AWS_REGISTRY_CREDENTIAL = "ecr:us-east-1:AWS"
        IMAGE_NAME = "emart-emartapi-repository"
        IMAGE_VERSION = "latest"
    }
    stages{
        stage("Validate Jenkins Environment Tools"){
            steps{
                script{
                    def tools = REQUIRED_TOOLS.split(',').collect { it.trim() }
                    echo "Checking for required tools: ${tools.join(', ')}"
                    tools.each { tool ->
                        echo "Checking for ${tool}..."
                        def exitCode = sh(script: "which ${tool}", returnStatus: true)
                        if (exitCode != 0) {
                            error "Required tool '${tool}' is not installed"
                        }
                    }
                }
            }
            post{
                always{
                    echo "###########################################"
                    echo "#### VALIDATE JENKINS ENVIRONMENT TOOLS ###"
                    echo "###########################################"
                }
                success{
                    echo "All required tools are available"
                }
                failure{
                    error "Required tool '${tool}' is not installed"
                }
            }
        }
        stage('List files in repo on Unix Slave') {
            steps {
                echo "Workspace location: ${env.WORKSPACE}"    
                sh 'ls -l'
            }
        }
        stage("Checkout project from github") {
            steps {
                dir("${env.WORKSPACE}/tmp/") {
                    sh "git clone --branch ${BRANCH_NAME} ${GIT_REPO_URL}"
                }
            }
        }
        stage("Code Test Processes") {
            parallel {
                // stage("Unit Test") {
                //     steps {
                //         dir("${env.WORKSPACE}/tmp/${env.PROJECT_FOLDER}") {
                //             sh 'mvn test'
                //         }
                //     }
                // }
                // stage("Integration Test") {
                //     steps {
                //         dir("${env.WORKSPACE}/tmp/${env.PROJECT_FOLDER}") {
                //             sh 'mvn verify -e'
                //         }
                //     }
                // }
                stage("Static test code analysis") {
                    steps {
                        dir("${env.WORKSPACE}/tmp/${env.PROJECT_FOLDER}") {
                            sh 'npm test'
                        }
                    }
                }
                stage("Build and compile") {
                    steps {
                        dir("${env.WORKSPACE}/tmp/${env.PROJECT_NAME}") {
                            echo 'Start build stage .... '
                            sh '''
                                npm ci
                                CI=true npm run build --verbose
                            '''
                            echo 'Build completed. '
                        }
                    }
                }
            }
        }
        stage("Check code With SonarQube") {
          environment {
            scannerHome = tool 'sonar6.2'
          }
          steps {
            dir("${env.WORKSPACE}/tmp/${env.PROJECT_NAME}") {
              withSonarQubeEnv('Jenkins2Sonar') { 
                sh '''${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=emart_nodeapi_api \
                        -Dsonar.projectName=emart_nodeapi_api \
                        -Dsonar.projectVersion=1.0 \
                        -Dsonar.sources=. ''' 
                    }
                }
            } 
        }
        // stage("Quality Gate") {
        //   steps {
        //     timeout(time: 1, unit: 'HOURS') {
        //                     waitForQualityGate abortPipeline: true
        //     }
        //   }
        // }
        stage('Copy Artifact to workspace') {
          steps {
            script {
              sh "cp ${env.WORKSPACE}/tmp/${PROJECT_NAME}/target/${env.ARTIFACT_NAME} ${env.WORKSPACE}"
            } 
          }
        }
        stage('Build docker image') {
          steps {
            script {
              sh "docker build -t ${IMAGE_NAME}:${IMAGE_VERSION} ."
              sh "docker tag ${IMAGE_NAME}:${IMAGE_VERSION} ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
              sh "docker tag ${IMAGE_NAME}:${IMAGE_VERSION} ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
            }
          }
        }
        stage('Clean up process') {
            steps {
                dir("${env.WORKSPACE}") {
                            sh "rm -rf *"
                        }
            }
        }
        stage('Push images to the ECR repository') {
            steps {
                script {
                    docker.withRegistry (ECR_REGISTRY_URI, AWS_REGISTRY_CREDENTIAL) {
                        try {
                            try {
                                withAWS(credentials: 'AWS', region: 'us-east-1') {
                                    sh "docker images -q ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
                                    sh "docker images -q ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
                                }
                            } catch (Exception ImagenNF) {
                                error "Image ${IMAGE_NAME} Not found locally"    
                            }              
                            try {
                                withAWS(credentials: 'AWS', region: 'us-east-1') {
                                    sh "docker push ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
                                    sh "docker push ${ECR_REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
                                }
                            } catch (Exception PushFail) {
                                error "Image ${IMAGE_NAME} Push failed"    
                            }
                        } catch (Exception e) {
                            error "Failed to push ${IMAGE_NAME}: ${e.message}"
                        }
                    }
                }
            }
        }
        stage('Clean up images from local host') {
            steps {
                script {
                    try {
                        sh '''
                            docker images | grep ${IMAGE_NAME} | awk '{print $3}' | xargs -r docker rmi -f
                            docker system prune -f
                        '''
                    } catch (Exception e) {
                        echo "Warning: Failed to clean up Docker images: ${e.message}"
                    }
                }
            }
        }
    }
    post{
        always{
            script {
                if (currentBuild.result == 'SUCCESS') {
                    notifySlack('SUCCESS')
                }
                else if (currentBuild.result == 'FAILURE') {
                    notifySlack('FAILURE')
                }
                else if (currentBuild.result == 'UNSTABLE') {
                    notifySlack('UNSTABLE')
                }
            }
        }
        success{
            echo "========pipeline executed successfully ========"
        }
        failure{
            echo "========pipeline execution failed========"
        }
    }
}