
#!/bin/bash

echo "Iniciando configuração do ambiente"

echo "Atualizando pacotes..."

if ! sudo apt update || ! sudo apt upgrade -y; then
    echo "Erro ao atualizar os pacotes."
    exit 1
fi

echo "Pacotes atualizados com sucesso!"

if command -v docker >/dev/null 2>&1; then
    echo "Docker já está instalado:"
    docker --version
else
    echo "Instalando o Docker..."
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    echo "Docker instalado com sucesso!"
fi

if ! sudo docker compose version >/dev/null 2>&1; then
    echo "Instalando Docker Compose..."
    sudo apt install -y docker-compose-v2
fi

mkdir -p "$HOME/low-latency"
cd "$HOME/low-latency"

if [ ! -d "Banco-de-dados" ]; then
    echo "Baixando os arquivos do banco..."
    git clone https://github.com/LowLatencyOrg/Banco-de-dados.git
fi

if ! sudo docker network inspect lowlatency-net >/dev/null 2>&1; then
    echo "Criando rede Docker..."
    sudo docker network create lowlatency-net
fi

read -r -s -p "Digite a senha do MySQL root: " senha
echo

if [ -z "$senha" ]; then
    echo "A senha não pode ficar vazia."
    exit 1
fi

sudo mkdir -p /dados/mysql
echo "Criando container MySQL..."

sudo docker run -d \
    --name lowlatency-banco \
    --network lowlatency-net \
    --restart unless-stopped \
    -e MYSQL_ROOT_PASSWORD="$senha" \
    -v /dados/mysql:/var/lib/mysql \
    -v "$HOME/low-latency/Banco-de-dados/script-low-latency.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
    mysql:latest

echo "Container MySQL iniciado."

sleep 5

sudo docker exec lowlatency-banco mysql -u root -p"$senha" -e "
CREATE USER IF NOT EXISTS 'dba_user'@'%' IDENTIFIED BY '12345';
GRANT ALL PRIVILEGES ON lowLatency.* TO 'dba_user'@'%';
FLUSH PRIVILEGES;
"

unset senha

echo "Usuário do site configurado!"

read -r -p "Deseja executar o site/API? [s/n]: " resposta

if [[ "$resposta" =~ ^[sS]$ ]]; then

    if [ ! -d "$HOME/low-latency/Site-Grupo03" ]; then
        echo "Baixando os arquivos da API..."
        git clone https://github.com/LowLatencyOrg/Site-Grupo03.git \
            "$HOME/low-latency/Site-Grupo03"
    fi

    cd "$HOME/low-latency/Site-Grupo03"

    echo "Criando Dockerfile..."

    cat > Dockerfile <<'DOCKERFILE_EOF'
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3333
CMD ["npm", "start"]
DOCKERFILE_EOF

    echo "Construindo imagem da API..."

    sudo docker build -t low-latency-imagem .

    echo "Iniciando container da API..."

    sudo docker run -d \
    --name lowlatency-api \
    --network lowlatency-net \
    --restart unless-stopped \
    --env-file .env.dev \
    -p 3333:3333 \
    low-latency-imagem

    echo "API iniciada."
    echo "Teste usando http://IP-PUBLICO-DA-EC2:3333"

else
    echo "Inicialização da API cancelada."
fi

echo "Configuração concluída."
