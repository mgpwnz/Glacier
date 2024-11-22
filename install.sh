#!/bin/bash

# Default variables
function="install"

# Options
option_value() { echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
    case "$1" in
    -in|--install)
        function="install"
        shift
        ;;
    -up|--update)
        function="update"
        shift
        ;;
    -un|--uninstall)
        function="uninstall"
        shift
        ;;
    *|--)
        break
        ;;
    esac
done

install() {
    # Docker installation
    sudo apt install docker.io -y &>/dev/null
    cd $HOME

    # Create directory and config
    if [ ! -d "$HOME/glacier-verifier" ]; then
        mkdir "$HOME/glacier-verifier"
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
    tee "$HOME/glacier-verifier/docker-compose.yml" > /dev/null <<EOF
version: "3.7"
services:
  glacier-verifier:
    image: docker.io/glaciernetwork/glacier-verifier:v0.0.1
    restart: always
    environment:
      - PRIVATE_KEY=$PRIVATE_KEY
networks:
  default:
    driver: bridge
EOF

    # Run container
    docker compose -f "$HOME/glacier-verifier/docker-compose.yml" up -d
}

update() {
    docker compose -f "$HOME/glacier-verifier/docker-compose.yml" down
    docker compose -f "$HOME/glacier-verifier/docker-compose.yml" pull
    docker compose -f "$HOME/glacier-verifier/docker-compose.yml" up -d
    docker logs -f glacier-verifier
}

uninstall() {
    if [ ! -d "$HOME/glacier-verifier" ]; then
        echo "Directory not found"
        exit 1
    fi

    read -r -p "Wipe all DATA? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            docker-compose -f "$HOME/glacier-verifier/docker-compose.yml" down -v
            rm -rf "$HOME/glacier-verifier"
            echo "Data wiped"
            ;;
        *)
            echo "Canceled"
            exit 0
            ;;
    esac
}

# Actions
sudo apt install wget -y &>/dev/null
cd
$function
