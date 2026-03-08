.DEFAULT_GOAL := help

.PHONY: help setup-libs setup-podman gen-native-config \
        deploy deploy-native deploy-native-pi deploy-native-podman \
        run run-native debug run-local run-local-native

help:
	@printf "\nUsage: make <target>\n"
	@printf "\nSetup (one-time):\n"
	@printf "  %-24s %s\n" "setup-libs"           "Symlink aarch64 static libs from Pi into local GraalVM CE"
	@printf "  %-24s %s\n" "setup-podman"         "Install QEMU packages for arm64 Podman containers (Arch Linux)"
	@printf "  %-24s %s\n" "gen-native-config"    "Run native-image-agent on Pi to generate reachability-metadata.json"
	@printf "\nDeploy:\n"
	@printf "  %-24s %s\n" "deploy"               "Build shaded JAR and deploy to Pi"
	@printf "  %-24s %s\n" "deploy-native"        "Build aarch64 native binary (Maven cross-compile) and deploy to Pi"
	@printf "  %-24s %s\n" "deploy-native-pi"     "Build aarch64 native binary on BlackRaspberry and install in place"
	@printf "  %-24s %s\n" "deploy-native-podman" "Build aarch64 native binary (Podman/QEMU arm64) and deploy to Pi"
	@printf "\nRun:\n"
	@printf "  %-24s %s\n" "run"              "Run JVM version on Pi via SSH"
	@printf "  %-24s %s\n" "run-native"       "Run native binary on Pi via SSH"
	@printf "  %-24s %s\n" "debug"            "Run JVM version on Pi with JDWP debugging (port 5005)"
	@printf "  %-24s %s\n" "run-local"        "Run JVM JAR locally"
	@printf "  %-24s %s\n" "run-local-native" "Run native binary locally"
	@printf "\n"

setup-libs:
	./scripts/setup/setup-aarch64-libs.sh

setup-podman:
	./scripts/setup/setup-podman.sh

gen-native-config:
	./scripts/setup/generate-native-agent-config.sh

deploy:
	./scripts/deploy/deploy-pi.sh

deploy-native:
	./scripts/deploy/deploy-pi-native.sh

deploy-native-pi:
	./scripts/deploy/deploy-pi-native-on-pi.sh

deploy-native-podman:
	./scripts/deploy/deploy-pi-native-podman.sh

run:
	./scripts/run/run-on-pi.sh

run-native:
	./scripts/run/run-on-pi-native.sh

debug:
	./scripts/run/debug-on-pi.sh

run-local:
	./scripts/run/run-local.sh

run-local-native:
	./scripts/run/run-local-native.sh
