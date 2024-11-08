#!/bin/sh

if [ -z "$1" ]; then
    echo "Please provide the mode as an argument: rcc or rccremote."
    exit 1
fi

main() {
    # Check if the mode is rcc or rccremote
    if [ "$1" = "rcc" ]; then
        configure_rcc_client
    elif [ "$1" = "rccremote" ]; then
        start_rccremote
    else
        echo "Invalid mode. Please provide either rcc or rccremote."
        exec tail -f /dev/null
    fi
}

disable_rcc_telemetry() {
    # Disable telemetry
    echo "Disabling telemetry..."
    rcc config identity -t
}

configure_rcc_client() {
    echo "=== MODE: rcc"
    disable_rcc_telemetry
    if [ -f /etc/certs/rootCA.pem ]; then
        echo "rootCA.pem found. Injecting into rcc-profile-cabundle.yaml..."

        # Export the content of rootCA.pem as an environment variable
        export ROOT_CA_CONTENT=$(cat /etc/certs/rootCA.pem)

        # Use envsubst to replace placeholders in the template with actual content
        envsubst '$ROOT_CA_CONTENT' </rcc-profile-cabundle.yaml.template >/rcc-profile-cabundle.yaml

        # indent any line after "ca-bundle" with two spaces
        sed -i '/ca-bundle/!b;n;:a;s/^/  /;n;ba' rcc-profile-cabundle.yaml

        # Run rcc commands to import and switch to the new configuration profile
        rcc config import -f /rcc-profile-cabundle.yaml
        rcc config switch -p rccremote-cabundle
        echo "rcc configuration profile switched to rccremote-cabundle."
    else
        echo "rootCA.pem not found in /etc/certs. Skipping configuration profile setup."
    fi

    exec tail -f /dev/null
}

start_rccremote() {
    echo "=== MODE: rccremote"
    disable_rcc_telemetry
    echo "Enabling shared holotree..."
    rcc ht shared -e && rcc ht init
    echo "Starting rccremote..."
    rccremote -hostname 0.0.0.0 -debug -trace
}

main "$@"
