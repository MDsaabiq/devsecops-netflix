# DevSecOps Netflix Clone on AWS EKS

A production-style DevSecOps CI/CD pipeline that builds, scans, secures, and deploys a Netflix-like web app using AWS, Jenkins, Docker, Kubernetes (EKS), SonarQube, Trivy, and OWASP ZAP, Gmail, Grafana, Prometheus. This project demonstrates real-world DevSecOps practices, not just deployment.

## Project Highlights

- End-to-end CI/CD pipeline using Jenkins
- Security at every stage (container scan, owasp, sonarqube)
- Dockerized application deployed to AWS EKS
- Automated vulnerability scanning with policy-based gates
- grafana monitoring with prometheus
- terraform for infrastructure provisioning
- gmail notification for pipeline status

## Architecture Overview

![Pipeline 1](public/assets/pipeline1.png)

Developer
  |
  | (git push)
  v
GitHub Repository
  |
  v
Jenkins CI/CD Pipeline
  |
  |-- SonarQube (SAST)
  |-- Trivy FS Scan (Dependencies)
  |-- Docker Build and Push
  |-- Trivy Image Scan
  |
  v
AWS EKS (Kubernetes)
  |
  |-- Application exposed via LoadBalancer
  |
  v
OWASP ZAP (DAST on Live App)

## Demo Video

<a href="https://github.com/user-attachments/assets/1ae5d562-53e4-4051-946c-e1b98a370791" target="_blank" rel="noopener">
  <img src="public/assets/pipeline2.jpg" alt="Demo Video" />
</a>

## Tech Stack

Cloud and Infrastructure

- AWS EC2: Jenkins controller
- AWS EKS: Kubernetes cluster
- AWS ECR or Docker Hub: image registry

CI/CD and DevOps

- Jenkins: pipeline orchestration
- Docker: containerization
- Kubernetes: application orchestration

Security (DevSecOps)

- SonarQube: Static Application Security Testing (SAST)
- Trivy: dependency and container vulnerability scanning
- OWASP ZAP: Dynamic Application Security Testing (DAST)

Application

- React + Node.js
- Netflix-style frontend consuming TMDB API

## Security Integration (DevSecOps)

This pipeline enforces security at multiple layers:

| Stage | Tool | Purpose |
| --- | --- | --- |
| Code Analysis | SonarQube | Detect code smells and vulnerabilities |
| Dependency Scan | Trivy FS | Scan npm dependencies |
| Image Scan | Trivy Image | Scan OS and libraries |
| Runtime Scan | OWASP ZAP | Scan live app on Kubernetes |

Pipeline fails only for high-risk vulnerabilities, following real industry practices.

## Jenkins Pipeline Stages

1. Clean workspace
2. Checkout source code
3. SonarQube analysis (SAST)
4. Quality gate validation
5. Install dependencies
6. Trivy file system scan
7. Docker build and push
8. Trivy image scan
9. Deploy to Docker (EC2)
10. Deploy to Kubernetes (EKS)
11. OWASP ZAP scan on Kubernetes service
12. Email notification with reports

## Jenkinsfile (Declarative Pipeline)

```groovy
pipeline {
  agent any

  tools {
    jdk 'jdk23'
    nodejs 'nodejs'
  }

  environment {
    SCANNER_HOME = tool 'sonar-scanner'
    TMDB_API_KEY = "********"
  }

  stages {

    stage('Clean Workspace') {
      steps {
        cleanWs()
      }
    }

    stage('Checkout from Git') {
      steps {
        git branch: 'main',
          url: 'https://github.com/MDsaabiq/devsecops-netflix.git'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv('sonar-server') {
          sh """
          ${SCANNER_HOME}/bin/sonar-scanner \
            -Dsonar.projectName=netflix \
            -Dsonar.projectKey=netflix
          """
        }
      }
    }

    stage('Quality Gate') {
      steps {
        script {
          waitForQualityGate abortPipeline: false,
            credentialsId: 'sonar-token'
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        sh 'npm install'
      }
    }

    stage('TRIVY FS SCAN') {
      steps {
        sh 'trivy fs . > trivyfs.txt'
      }
    }

    stage('Docker Build & Push') {
      steps {
        script {
          withDockerRegistry(credentialsId: 'docker') {
            sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_API_KEY} -t netflix ."
            sh "docker tag netflix sksaabiq123/netflix:latest"
            sh "docker push sksaabiq123/netflix:latest"
          }
        }
      }
    }

    stage('TRIVY Image Scan') {
      steps {
        sh 'trivy image sksaabiq123/netflix:latest > trivyimage.txt'
      }
    }

    stage('Deploy to Container') {
      steps {
        sh 'docker rm -f netflix || true'
        sh 'docker run -d --name netflix -p 8081:80 sksaabiq123/netflix:latest'
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        script {
          dir('Kubernetes') {
            withKubeConfig(credentialsId: 'k8s') {
              sh 'kubectl apply -f deployment.yml'
              sh 'kubectl apply -f service.yml'
            }
          }
        }
      }
    }

    stage('OWASP ZAP Scan (Kubernetes)') {
      steps {
        script {
          // allow container to write report
          sh 'chmod -R 777 .'

          sh '''
          docker run --rm \
            -u 0 \
            -v $(pwd):/zap/wrk \
            ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
            -t http://aeb1610325e684b8db05e9ded130ac34-7558949.ap-south-1.elb.amazonaws.com \
            -r zap_k8s_report.html \
            -c zap-rules.conf \
            -I
          '''
        }
      }
    }
  }

  post {
    always {
      emailext(
        attachLog: true,
        subject: "'${currentBuild.result}': ${env.JOB_NAME} [${env.BUILD_NUMBER}]",
        body: """Project: ${env.JOB_NAME}<br/>
Build Number: ${env.BUILD_NUMBER}<br/>
URL: ${env.BUILD_URL}<br/>""",
        to: 'saabiqcs@gmail.com',
        attachmentsPattern: 'trivyfs.txt, trivyimage.txt, zap_k8s_report.html'
      )
    }
  }
}
```

## Repository Structure

```text
.
├── Jenkinsfile
├── EKS Template/
├── Dockerfile
├── zap-rules.conf
├── Kubernetes/
│   ├── deployment.yml
│   └── service.yml
├── src/
├── public/
└── README.md
```

## OWASP ZAP Rules (Policy-Based)

Custom ZAP rules ensure:

- FAIL on high-risk vulnerabilities
- WARNINGS are reported but do not block delivery

Example:

```
40012  FAIL   SQL Injection
10020  IGNORE Missing Anti-clickjacking Header
```

## Automated Notifications

After every pipeline run:

- Build status email is sent
- Attached reports:
  - trivyfs.txt
  - trivyimage.txt
  - zap_k8s_report.html

## Deployment

- Application is deployed to AWS EKS
- Exposed via Kubernetes LoadBalancer
- OWASP ZAP scans the live, publicly reachable service

## Key Takeaways

- End-to-end DevSecOps flow with security gates
- Policy-driven vulnerability management
- Kubernetes + AWS EKS deployment with live DAST
- OWASP Top 10 awareness and tooling alignment
- Production-style Jenkins pipeline with audit-friendly reports

## Future Improvements

- Authenticated OWASP ZAP scans
- Security dashboards (Grafana)
- Canary or blue-green deployments
- Automated rollback on security failure
- HTTPS via Ingress + TLS

## Author

Saabiq
DevSecOps | AWS | Kubernetes | Jenkins | Security

Reach out via GitHub or LinkedIn.
