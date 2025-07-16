#!/bin/bash
set -e

# --- Helper Functions ---
info() {
    echo -e "\033[0;32m[INFO] ${1}\033[0m"
}

error() {
    echo -e "\033[0;31m[ERROR] ${1}\033[0m"
    exit 1
}

usage() {
    echo "yethos-cli: A tool for managing your yethos environment."
    echo ""
    echo "Usage: ./yethos-cli.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  tinyauth <args...>    Run a command in the TinyAuth container."
    echo "                        Example: ./yethos-cli.sh tinyauth user create --interactive"
    echo ""
    echo "  logs <service>        View logs for a specific service (e.g., traefik, tinyauth)."
    echo "                        Example: ./yethos-cli.sh logs traefik"
    echo ""
    echo "  restart <service>     Restart a specific service."
    echo "                        Example: ./yethos-cli.sh restart tinyauth"
    echo ""
    echo "  exec <service> <cmd>  Execute a command inside a running container."
    echo "                        Example: ./yethos-cli.sh exec traefik ls -l /"
    echo ""
    echo "  help                  Show this help message."
    echo ""
}

# --- Main Logic ---
main() {
    if ! [ -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found. Please run this script from the root of your yethos project."
    fi

    local command="$1"
    shift || { usage; exit 1; }

    case "$command" in
        tinyauth)
            info "Running TinyAuth command: ${*}"
            docker compose run --rm tinyauth "$@"
            ;;
        logs)
            local service="$1"
            shift || { error "Service name required for 'logs' command."; usage; exit 1; }
            info "Tailing logs for '$service'..."
            docker compose logs -f "$service"
            ;;
        restart)
            local service="$1"
            shift || { error "Service name required for 'restart' command."; usage; exit 1; }
            info "Restarting '$service'..."
            docker compose restart "$service"
            info "'$service' restarted."
            ;;
        exec)
            local service="$1"
            shift || { error "Service name required for 'exec' command."; usage; exit 1; }
            if [ -z "$1" ]; then
                error "Command required for 'exec'."
                usage
                exit 1
            fi
            info "Executing command in '$service': ${*}"
            docker compose exec "$service" "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
