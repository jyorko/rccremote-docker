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
        #monitor_and_restart
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
        echo "rootCA.pem found. Injecting into rcc-profile-ssl-cabundle.yaml..."

        # Export the content of rootCA.pem as an environment variable
        export ROOT_CA_CONTENT=$(cat /etc/certs/rootCA.pem)

        # Use envsubst to replace placeholders in the template with actual content
        envsubst '$ROOT_CA_CONTENT' </etc/rcc-profiles.d/rcc-profile-ssl-cabundle.yaml.template >/rcc-profile.yaml

        # indent any line after "ca-bundle" with two spaces
        sed -i '/ca-bundle/!b;n;:a;s/^/  /;n;ba' /rcc-profile.yaml

        import_and_switch_rcc_profile ssl-cabundle
    else
        cp /etc/rcc-profiles.d/rcc-profile-ssl-noverify.yaml /rcc-profile.yaml
        import_and_switch_rcc_profile ssl-noverify
    fi

    exec tail -f /dev/null
}

import_and_switch_rcc_profile() {
    PROFILE_NAME=$1
    rcc config import -f /rcc-profile.yaml
    rcc config switch -p $PROFILE_NAME
    echo "Switched to RCC profile $PROFILE_NAME."
}

start_rccremote() {
    echo "=== MODE: rccremote"
    rcc_init
    create_and_serve_hl

}

rcc_init() {
    disable_rcc_telemetry
    echo "Enabling shared holotree..."
    rcc ht shared -e && rcc ht init
}

create_rcc_hololibs() {
    echo "--- Creating the hololibs..."
    find /robots -type f -name "robot.yaml" | while read -r robot_yaml; do
        dir=$(dirname "$robot_yaml")
        # Check if conda.yaml exists in the same directory
        if [ -f "$dir/conda.yaml" ]; then
            echo "  + Creating hololib for robot: $dir"
            rcc ht vars --timeline -r "$robot_yaml"
        else
            echo "  - Skipping $dir: conda.yaml not found."
        fi
    done
    echo "--- Hololib creation finished."
}

create_and_serve_hl() {
    create_rcc_hololibs
    echo "Starting rccremote..."
    rccremote -hostname 0.0.0.0 -debug -trace
    # TODO: does not work
    #rccremote -hostname 0.0.0.0 -debug -trace & # Run in the background
    #RCCREMOTE_PID=$!                            # Capture the PID of rccremote
    #echo "rccremote started with PID: $RCCREMOTE_PID"
}

monitor_and_restart() {
    echo "--- Monitoring '/robots' for changes..."
    while true; do
        inotifywait -r -e modify,create,delete /robots
        echo "!   Change detected in /robots. Restarting rccremote..."
        if [ -n "$RCCREMOTE_PID" ]; then
            kill "$RCCREMOTE_PID"
            wait "$RCCREMOTE_PID" 2>/dev/null
            echo "Stopped rccremote (PID: $RCCREMOTE_PID)"
        fi
        create_and_serve_hl
    done
}

main "$@"
