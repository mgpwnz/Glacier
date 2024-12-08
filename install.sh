#!/bin/bash

# Default action
action="install"

# Define version
version="v0.0.3"

# Parse options
option_value() { echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
    case "$1" in
    -in|--install)
        action="install"
        shift
        ;;
    -up|--update)
        action="update"
        shift
        ;;
    -un|--uninstall)
        action="uninstall"
        shift
        ;;
    *|--)
        break
        ;;
    esac
done

install() {
    # Install Docker
    sudo apt update -y &>/dev/null
    sudo apt install docker.io -y &>/dev/null
    sudo usermod -aG docker $USER

    cd $HOME

    # Create directory
    if [ ! -d "$HOME/glacier" ]; then
        mkdir "$HOME/glacier"
    fi
    sleep 1

    # Prompt for private key
    function check_empty {
        local varname=$1
        while [ -z "${!varname}" ]; do
            read -p "$2" input
            if [ -n "$input" ]; then
                eval $varname=\"$input\"
            else
                echo "The value cannot be empty. Please try again."
            fi
        done
    }

    while true; do
        PRIVATE_KEY=""
        check_empty PRIVATE_KEY "Enter your PRIVATE_KEY: "
        echo "You have entered PRIVATE_KEY: $PRIVATE_KEY"
        read -p "Is this correct? (yes/no): " CONFIRM
        CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
        if [ "$CONFIRM" == "yes" ] || [ "$CONFIRM" == "y" ]; then
            break
        fi
    done

    echo "All data is confirmed. Proceeding..."

    # Create Docker Compose file
    tee "$HOME/glacier/docker-compose.yml" > /dev/null <<EOF
version: "3.7"
services:
  glacier-verifier:
    container_name: glacier-verifier
    image: docker.io/glaciernetwork/glacier-verifier:$version
    restart: always
    environment:
      - PRIVATE_KEY=$PRIVATE_KEY
networks:
  default:
    driver: bridge
EOF

    # Run container
    docker compose -f "$HOME/glacier/docker-compose.yml" up -d
}

update() {
    # Stop and update container
    docker compose -f "$HOME/glacier/docker-compose.yml" down
    sed -i "s|image: docker.io/glaciernetwork/glacier-verifier:.*|image: docker.io/glaciernetwork/glacier-verifier:$version|g" "$HOME/glacier/docker-compose.yml"
    docker compose -f "$HOME/glacier/docker-compose.yml" pull
    docker compose -f "$HOME/glacier/docker-compose.yml" up -d
    docker logs -f glacier-verifier
}

uninstall() {
    if [ ! -d "$HOME/glacier" ]; then
        echo "Directory not found"
        exit 0
    fi

    read -r -p "Wipe all DATA? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            docker compose -f "$HOME/glacier/docker-compose.yml" down -v
            rm -rf "$HOME/glacier"
            echo "Data wiped"
            ;;
        *)
            echo "Canceled"
            exit 0
            ;;
    esac
}

# Ensure wget is installed
sudo apt install wget -y &>/dev/null
cd
$action
