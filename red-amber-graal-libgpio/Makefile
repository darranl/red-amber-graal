.DEFAULT_GOAL := help

.PHONY: help setup-libs gen-cap-cache gen-ffm-bindings deploy deploy-native \
        run run-native debug run-local run-local-native

help:
	@printf "\nUsage: make <target>\n"
	@printf "\nSetup (one-time):\n"
	@printf "  %-20s %s\n" "setup-libs"       "Symlink aarch64 static libs from Pi into local GraalVM CE"
	@printf "  %-20s %s\n" "gen-cap-cache"    "Generate CAP cache on Pi and fetch result back"
	@printf "  %-20s %s\n" "gen-ffm-bindings" "Generate FFM Java bindings for libgpiod via jextract"
	@printf "\nDeploy:\n"
	@printf "  %-20s %s\n" "deploy"           "Build JVM JAR and deploy to Pi"
	@printf "  %-20s %s\n" "deploy-native"    "Build aarch64 native binary and deploy to Pi"
	@printf "\nRun:\n"
	@printf "  %-20s %s\n" "run"              "Run JVM version on Pi via SSH"
	@printf "  %-20s %s\n" "run-native"       "Run native binary on Pi via SSH"
	@printf "  %-20s %s\n" "debug"            "Run JVM version on Pi with JDWP debugging (port 5005)"
	@printf "  %-20s %s\n" "run-local"        "Run JVM JAR locally"
	@printf "  %-20s %s\n" "run-local-native" "Run native binary locally"
	@printf "\n"

setup-libs:
	./scripts/setup/setup-aarch64-libs.sh

gen-cap-cache:
	./scripts/setup/generate-cap-cache.sh

gen-ffm-bindings:
	./scripts/setup/generate-ffm-bindings.sh

deploy:
	./scripts/deploy/deploy-pi.sh

deploy-native:
	./scripts/deploy/deploy-pi-native.sh

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
