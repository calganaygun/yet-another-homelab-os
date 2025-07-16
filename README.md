# yet-another-homelab-os (yethos)

`yethos` is a collection of scripts to automatically set up a homelab environment on a fresh Linux machine.

## Features

- Automated Docker and Docker Compose installation.
- Traefik reverse proxy with automatic service discovery.
- Secure tunneling with `cloudflared`.
- Authentication with TinyAuth, integrated with Traefik.

## One-Click Deployment

To get started on a fresh Linux machine, you can use the one-click deployment script. This will handle installing dependencies, cloning the repository, and starting the interactive setup process.

```bash
curl -sSL https://raw.githubusercontent.com/calganaygun/yet-another-homelab-os/main/deploy.sh | bash
```

The script will guide you through the rest of the setup.

## Manual Installation

If you prefer to install manually, you can clone the repository and run the installation script yourself:

```bash
git clone https://github.com/calganaygun/yet-another-homelab-os.git
cd yet-another-homelab-os
bash install.sh
```

## Management CLI (`yethos-cli.sh`)

A powerful helper script, `yethos-cli.sh`, is provided to manage your entire homelab stack.

### Usage
```bash
./yethos-cli.sh <command> [options]
```

### Commands

-   **`tinyauth <args...>`**: Run commands directly in the TinyAuth container. This is your gateway to the TinyAuth CLI for managing users, TOTP, etc.
    ```bash
    # Create a new user interactively
    ./yethos-cli.sh tinyauth user create --interactive

    # Generate a TOTP secret for an existing user
    ./yethos-cli.sh tinyauth totp generate --interactive
    ```

-   **`logs <service>`**: View the real-time logs for any running service.
    ```bash
    # Tail the logs for Traefik
    ./yethos-cli.sh logs traefik
    ```

-   **`restart <service>`**: Restart a specific service.
    ```bash
    # Restart the TinyAuth container
    ./yethos-cli.sh restart tinyauth
    ```

-   **`exec <service> <command>`**: Execute a command inside a running container.
    ```bash
    # Get a shell inside the Traefik container
    ./yethos-cli.sh exec traefik sh
    ```

-   **`help`**: Display the help message with all available commands.

## Adding Your Own Services

An example file `docker-compose.whoami-example.yml` is provided to show how to add your own services and protect them with TinyAuth.

To add a new service:
1.  Create a new `docker-compose.service.yml` file or edit the example.
2.  Define your service and add the required Traefik and TinyAuth labels.
3.  Deploy your service alongside the core stack:
    ```bash
    docker-compose -f docker-compose.yml -f docker-compose.whoami-example.yml up -d
    ```
