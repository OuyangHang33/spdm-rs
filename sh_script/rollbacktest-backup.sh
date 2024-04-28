#!/bin/bash

set -euo pipefail

export RUST_MIN_STACK=10485760
RUSTFLAGS=${RUSTFLAGS:-}

usage() {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
  -e EMU test
  -r Rust test
  -a Run all roll back test
  -h Show help info
EOM
}

trap cleanup exit

echo_command() {
    set -x
    "$@"
    set +x
}

cleanup() {
    kill -9 $(ps aux | grep spdm-responder | grep emu | awk '{print $2}') || true
    kill -9 $(ps aux | grep spdm_responder_emu | grep emu | awk '{print $2}') || true
}

RUN_REQUESTER_FEATURES=${RUN_REQUESTER_FEATURES:-spdm-ring,hashed-transcript-data,async-executor}
RUN_RESPONDER_FEATURES=${RUN_RESPONDER_FEATURES:-spdm-ring,hashed-transcript-data,async-executor}
RUN_REQUESTER_MUTAUTH_FEATURES="${RUN_REQUESTER_FEATURES},mut-auth"
RUN_RESPONDER_MUTAUTH_FEATURES="${RUN_RESPONDER_FEATURES},mut-auth"
RUN_RESPONDER_MANDATORY_MUTAUTH_FEATURES="${RUN_RESPONDER_FEATURES},mandatory-mut-auth"

run_with_spdm_emu_req_rust_rsp() {
    echo "Running spdm-rs responder to test spdm-emu requester..."
    
    echo_command cargo run -p spdm-responder-emu-rollback --no-default-features --features="$RUN_RESPONDER_FEATURES" &
    sleep 5
    pushd test_key
    chmod +x ./spdm_requester_emu
    echo_command  ./spdm_requester_emu --trans PCI_DOE --exe_conn DIGEST,CERT,CHAL,MEAS --exe_session KEY_EX,PSK,KEY_UPDATE,HEARTBEAT,MEAS,DIGEST,CERT
    cleanup
    popd
}

run_with_spdm_emu_rsp_rust_req() {
    echo "Running spdm-rs requester to test spdm-emu responder..."
    pushd test_key
    chmod +x ./spdm_responder_emu
    echo_command  ./spdm_responder_emu --trans PCI_DOE &
    popd
    sleep 5
    echo_command cargo run -p spdm-requester-emu-rollback --no-default-features --features="$RUN_REQUESTER_FEATURES"
    cleanup    
    popd
}

run_rust_spdm_emu_test_req() {
    echo "Running spdm-rs responder to test spdm-rs requester..."
    echo_command cargo run -p spdm-responder-emu-rollback --no-default-features --features="$RUN_RESPONDER_FEATURES" &
    sleep 5
    echo_command cargo run -p spdm-requester-emu --no-default-features --features="$RUN_REQUESTER_FEATURES"
    cleanup
}

run_rust_spdm_emu_test_rsp() {
    echo "Running spdm-rs requester to test spdm-rs responder..."
    echo_command cargo run -p spdm-responder-emu --no-default-features --features="$RUN_RESPONDER_FEATURES" &
    sleep 5
    echo_command cargo run -p spdm-requester-emu-rollback --no-default-features --features="$RUN_REQUESTER_FEATURES"
    cleanup
}


EMU_OPTION=false
RUST_OPTION=false
ALL_OPTION=false


process_args() {
    while getopts ":era:h" option; do
        case "${option}" in
            e)
                EMU_OPTION=true
            ;;
            r)
                RUST_OPTION=true
            ;;
            a)
                ALL_OPTION=true
            ;;
            h)
                usage
                exit 0
            ;;
            *)
                echo "Invalid option '-$OPTARG'"
                usage
                exit 1
            ;;
        esac
    done
}


main() {
    if [[ ${EMU_OPTION} == true ]]; then
        run_with_spdm_emu_req_rust_rsp
        run_with_spdm_emu_rsp_rust_req
    fi
    if [[ ${RUST_OPTION} == true ]]; then
        run_rust_spdm_emu_test_req
        run_rust_spdm_emu_test_rsp
    fi
    if [[ ${ALL_OPTION} == true ]]; then
        run_with_spdm_emu_req_rust_rsp
        run_with_spdm_emu_rsp_rust_req
        run_rust_spdm_emu_test_req
        run_rust_spdm_emu_test_rsp
    fi
}

process_args "$@"
main