FROM python:3.11-slim AS base
WORKDIR /app

# Python deps
RUN pip install --no-cache-dir pytest pytest-bdd mysql-connector-python
# Kubectl pour manipuler les pods MySQL
# Kubectl pour manipuler les pods MySQL
# Installer curl et kubectl
ENV KUBECTL_VERSION=v1.31.1


RUN apt-get update && apt-get install -y curl ca-certificates && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y golang npm && rm -rf /var/lib/apt/lists/*

# Go deps
# Go deps
RUN go install github.com/cucumber/godog/cmd/godog@latest \
    && go mod init tmp && go get github.com/go-sql-driver/mysql@latest && go mod tidy
# Node deps
RUN npm install -g cucumber mysql2

# Copier les tests
COPY bdd-tests/features/ /bdd/features/
COPY bdd-tests/python/   /bdd/python/
COPY bdd-tests/go/       /bdd/go/
COPY bdd-tests/node/     /bdd/node/
CMD ["pytest", "-q", "/bdd/python/test_mysql_persistence.py"]
