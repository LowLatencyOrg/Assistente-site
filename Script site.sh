
#!/bin/bash

set -e

echo "========================================"
echo " Instalacao da API - Low Latency"
echo "========================================"

echo "Verificando o Docker..."

if ! command -v docker >/dev/null 2>&1; then
    echo "ERRO: Docker nao esta instalado."
    exit 1
fi

echo "Docker encontrado!"

echo "Verificando a rede Docker..."

if ! sudo docker network inspect lowlatency-net >/dev/null 2>&1; then
    echo "ERRO: A rede lowlatency-net nao existe."
    echo "Crie a rede antes de continuar."
    exit 1
fi

echo "Rede lowlatency-net encontrada!"

echo "Verificando o banco de dados..."

if ! sudo docker inspect -f '{{.State.Running}}' lowlatency-banco 2>/dev/null | grep -q true; then
    echo "ERRO: O container lowlatency-banco nao esta em execucao."
    exit 1
fi

echo "Banco de dados em execucao!"

mkdir -p "$HOME/low-latency"
cd "$HOME/low-latency"

# 5. Baixar ou atualizar o repositorio
REPO_URL="https://github.com/LowLatencyOrg/Site-Grupo03.git"

if [ -d "Site-Grupo03/.git" ]; then
    echo "Repositorio encontrado."
    cd Site-Grupo03

    echo "Verificando atualizacoes..."
    git pull --ff-only
else
    if [ -d "Site-Grupo03" ]; then
        echo "ERRO: A pasta Site-Grupo03 existe, mas nao e um repositorio Git."
        echo "Verifique a pasta antes de continuar."
        exit 1
    fi

    echo "Baixando os arquivos da API..."
    git clone "$REPO_URL" Site-Grupo03
    cd Site-Grupo03
fi

if [ ! -f "package.json" ]; then
    echo "ERRO: package.json nao encontrado."
    echo "Verifique se este repositorio contem a API Node.js."
    exit 1
fi

if [ ! -f "package-lock.json" ]; then
    echo "AVISO: package-lock.json nao encontrado."
    echo "A instalacao das dependencias pode nao ser reproduzivel."
fi

echo "Arquivos do projeto encontrados."

if [ ! -f "Dockerfile" ]; then
    echo "ERRO: Dockerfile nao encontrado."
    echo "Confira a configuracao da aplicacao antes de criar um."
    exit 1
fi

echo "Construindo a imagem Docker..."

sudo docker build -t low-latency-imagem .

# 9. Evitar iniciar um segundo container com o mesmo nome
if sudo docker container inspect low-latency-api >/dev/null 2>&1; then
    echo "O container low-latency-api ja existe."
    echo "Ele nao sera removido automaticamente."
    echo "Verifique-o antes de executar novamente."
    exit 1
fi

echo "Iniciando a API..."

sudo docker run -d \
    --name low-latency-api \
    --network lowlatency-net \
    --restart unless-stopped \
    -p 3333:3333 \
    low-latency-imagem

echo "========================================"
echo " API iniciada!"
echo "========================================"

echo "Verificando o estado do container..."
sudo docker ps --filter "name=low-latency-api"

echo ""
echo "Para consultar os logs:"
echo "sudo docker logs -f low-latency-api"
