#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
EVIDENCE_TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/evidence/templates"

export SERVICE_NAME="${SERVICE_NAME:-$(echo ${APPLICATION_KEY:-bookverse-service} | sed 's/bookverse-//')}"
export PROJECT_KEY="${PROJECT_KEY:-bookverse}"
export APPLICATION_KEY="${APPLICATION_KEY:-bookverse-$SERVICE_NAME}"
export BUILD_NAME="${BUILD_NAME:-${APPLICATION_KEY}_CI_build}"
export BUILD_NUMBER="${BUILD_NUMBER:-1}"
export APP_VERSION="${APP_VERSION:-1.0.0}"
export COVERAGE_PERCENT="${COVERAGE_PERCENT:-85.0}"

export GITHUB_SHA="${GITHUB_SHA:-unknown}"
export GITHUB_REF_NAME="${GITHUB_REF_NAME:-main}"
export GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-bookverse/service}"

echo "📋 Evidence Library: Auto-configured environment variables"
echo "  SERVICE_NAME: $SERVICE_NAME"
echo "  APPLICATION_KEY: $APPLICATION_KEY"
echo "  PROJECT_KEY: $PROJECT_KEY"
echo "  BUILD_NAME: $BUILD_NAME"
echo "  BUILD_NUMBER: $BUILD_NUMBER"
echo "  APP_VERSION: $APP_VERSION"

emit_json() {
  local out_file="${1:-}"; shift
  local content="$*"
  printf "%b\n" "$content" > "$out_file"
}

evd_create() {
  local predicate_file="${1:-}"; local predicate_type="${2:-}"; local markdown_file="${3:-}"
  local md_args=()
  if [[ -n "$markdown_file" ]]; then md_args+=(--markdown "$markdown_file"); fi
  
  if [[ "${ATTACH_TO_PACKAGE:-}" == "true" ]]; then
    local url_args=()
    if [[ -n "${JFROG_URL:-${JF_URL:-}}" ]]; then
      url_args+=(--url "${JFROG_URL:-${JF_URL:-}}")
    fi
    
    local package_repo_name
    if [[ "${PACKAGE_NAME:-}" =~ \.(tar\.gz|zip|jar|war|tgz)$ ]] || [[ "${PACKAGE_NAME:-}" =~ ^(config|resources)$ ]]; then
      package_repo_name="${PROJECT_KEY}-${SERVICE_NAME}-internal-generic-nonprod-local"
    else
      package_repo_name="${PROJECT_KEY}-${SERVICE_NAME}-internal-docker-nonprod-local"
    fi
    if ! jf evd create-evidence \
      --predicate "$predicate_file" \
      "${md_args[@]}" \
      --predicate-type "$predicate_type" \
      --package-name "${PACKAGE_NAME}" \
      --package-version "${PACKAGE_VERSION}" \
      --package-repo-name "$package_repo_name" \
      --project "${PROJECT_KEY}" \
      --provider-id github-actions \
      --key "${EVIDENCE_PRIVATE_KEY:-}" \
      --key-alias "${EVIDENCE_KEY_ALIAS:-${EVIDENCE_KEY_ALIAS_VAR:-}}"; then
      echo "❌ Failed to attach evidence to package ${PACKAGE_NAME}:${PACKAGE_VERSION} in $package_repo_name" >&2
      echo "🔍 Check EVIDENCE_PRIVATE_KEY and EVIDENCE_KEY_ALIAS configuration" >&2
      return 1
    fi
  elif [[ "${ATTACH_TO_BUILD:-}" == "true" ]]; then
    local url_args=()
    if [[ -n "${JFROG_URL:-${JF_URL:-}}" ]]; then
      url_args+=(--url "${JFROG_URL:-${JF_URL:-}}")
    fi
    
    if ! jf evd create-evidence \
      --predicate "$predicate_file" \
      "${md_args[@]}" \
      --predicate-type "$predicate_type" \
      --build-name "${BUILD_NAME}" \
      --build-number "${BUILD_NUMBER}" \
      --project "${PROJECT_KEY}" \
      --provider-id github-actions \
      --key "${EVIDENCE_PRIVATE_KEY:-}" \
      --key-alias "${EVIDENCE_KEY_ALIAS:-${EVIDENCE_KEY_ALIAS_VAR:-}}"; then
      echo "❌ Failed to attach evidence to build ${BUILD_NAME}:${BUILD_NUMBER}" >&2
      echo "🔍 Check EVIDENCE_PRIVATE_KEY and EVIDENCE_KEY_ALIAS configuration" >&2
      return 1
    fi
  else
    
    if ! jf evd create-evidence \
      --predicate "$predicate_file" \
      "${md_args[@]}" \
      --predicate-type "$predicate_type" \
      --application-key "${APPLICATION_KEY}" \
      --application-version "${APP_VERSION}" \
      --project "${PROJECT_KEY}" \
      --provider-id github-actions \
      --key "${EVIDENCE_PRIVATE_KEY:-}" \
      --key-alias "${EVIDENCE_KEY_ALIAS:-${EVIDENCE_KEY_ALIAS_VAR:-}}"; then
      echo "❌ Failed to attach evidence to application ${APPLICATION_KEY}:${APP_VERSION}" >&2
      echo "🔍 Check EVIDENCE_PRIVATE_KEY and EVIDENCE_KEY_ALIAS configuration" >&2
      return 1
    fi
  fi
}

generate_random_values() {
  export SCAN_ID=$(cat /proc/sys/kernel/random/uuid)
  export TEST_RUN_ID=$(cat /proc/sys/kernel/random/uuid)
  export COLLECTION_ID=$(cat /proc/sys/kernel/random/uuid)
  export ENGAGEMENT_ID=$(cat /proc/sys/kernel/random/uuid)
  export RELEASE_ID="REL-$((10000 + RANDOM % 90000))"
  export CHANGE_ID="CHG$((3000000 + RANDOM % 1000000))"
  
  export HIGH_FINDINGS=$((RANDOM % 3))
  export MEDIUM_FINDINGS=$((2 + RANDOM % 5))
  export LOW_FINDINGS=$((8 + RANDOM % 7))
  export TOTAL_VULNERABILITIES=$((HIGH_FINDINGS + MEDIUM_FINDINGS + LOW_FINDINGS))
  
  export TOTAL_TESTS=$((20 + RANDOM % 30))
  export PASSED_TESTS=$((TOTAL_TESTS - RANDOM % 3))
  export TEST_DURATION=$((30 + RANDOM % 120))
  export TOTAL_ASSERTIONS=$((100 + RANDOM % 31))
  export PASSED_ASSERTIONS=$((TOTAL_ASSERTIONS - RANDOM % 5))
  export COLLECTIONS_EXECUTED=$((3 + RANDOM % 5))
  export COLLECTIONS_PASSED=$COLLECTIONS_EXECUTED
  
  export URLS_SCANNED=$((50 + RANDOM % 100))
  export SCAN_DURATION=$((300 + RANDOM % 600))
  export FILES_SCANNED=$((25 + RANDOM % 50))
  export POLICIES_EVALUATED=$((15 + RANDOM % 20))
  export COMPLIANCE_SCORE=$((85 + RANDOM % 15))
  
  export TESTERS_COUNT=$((2 + RANDOM % 4))
  export REMEDIATION_RATE=$((90 + RANDOM % 10))
  
  export TICKET_COUNT=$((5 + RANDOM % 15))
  export RESOLVED_ISSUES=$((TICKET_COUNT - RANDOM % 3))
  export APPROVED_BY="manager-$((RANDOM % 5 + 1))"
  
  export SONAR_PROJECT_KEY="${SERVICE_NAME:-bookverse-service}"
  export DUPLICATION_PERCENT="$(echo "scale=1; $(( RANDOM % 20 )) / 10" | bc)"
  export CODE_SMELLS=$((RANDOM % 10))
  export BUGS=$((RANDOM % 3))
  export VULNERABILITIES=$((RANDOM % 2))
  
  export FILE_COUNT=$((5 + RANDOM % 15))
  export BUNDLE_TYPE="configuration"
  
  export NOW_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  export REPLICAS_DESIRED=$((2 + RANDOM % 4))
  export REPLICAS_READY=$REPLICAS_DESIRED
  export REVISION="${GITHUB_SHA:0:8}"
  export DEPLOYED_AT="${NOW_TS}"
  export APPROVED_AT="${NOW_TS}"
}

process_template() {
  local template_file="$1"
  local output_file="$2"
  
  if [[ ! -f "$template_file" ]]; then
    echo "❌ Template not found: $template_file" >&2
    return 1
  fi
  
  envsubst < "$template_file" > "$output_file"
  echo "✅ Generated evidence: $output_file"
}

attach_package_pytest_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  echo "📊 Generating pytest evidence for package: $package_name"
  generate_random_values
  
  export PACKAGE_NAME="$package_name"
  export PACKAGE_VERSION="$package_version"
  export ATTACH_TO_PACKAGE="true"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/package/docker/pytest-results.json.template"
  process_template "$template_file" "pytest-results.json"
  
  printf "# PyTest Results\n\nTest results for %s package.\n" "$package_name" > pytest-results.md
  printf "📋 Creating pytest evidence...\n"
  evd_create pytest-results.json "https://pytest.org/evidence/results/v1" pytest-results.md
}

attach_package_sast_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  echo "🔒 Generating SAST evidence for package: $package_name"
  generate_random_values
  
  export PACKAGE_NAME="$package_name"
  export PACKAGE_VERSION="$package_version"
  export ATTACH_TO_PACKAGE="true"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/package/docker/sast-scan.json.template"
  process_template "$template_file" "sast-scan.json"
  
  printf "# SAST Scan\n\nStatic analysis results for %s package.\n" "$package_name" > sast-scan.md
  printf "📋 Creating SAST evidence...\n"
  evd_create sast-scan.json "https://checkmarx.com/evidence/sast/v1.1" sast-scan.md
}

attach_package_config_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  echo "📦 Generating config bundle evidence for package: $package_name"
  generate_random_values
  
  export PACKAGE_NAME="$package_name"
  export PACKAGE_VERSION="$package_version"
  export ATTACH_TO_PACKAGE="true"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/package/generic/config-bundle.json.template"
  process_template "$template_file" "config-bundle.json"
  
  printf "# Config Bundle\n\nConfiguration verification for %s package.\n" "$package_name" > config-bundle.md
  printf "📋 Creating config bundle evidence...\n"
  evd_create config-bundle.json "https://in-toto.io/Statement/v0.1" config-bundle.md
}

attach_build_fossa_evidence() {
  echo "📋 Generating FOSSA license evidence for build"
  generate_random_values
  
  export ATTACH_TO_BUILD="true"
  export ATTACH_TO_PACKAGE="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/build/fossa-license-scan.json.template"
  process_template "$template_file" "fossa-license-scan.json"
  
  printf "# FOSSA License Scan\n\nLicense compliance scan for build %s.\n" "$BUILD_NAME" > fossa-license-scan.md
  printf "📋 Creating FOSSA license evidence...\n"
  evd_create fossa-license-scan.json "https://fossa.com/evidence/license-scan/v2.1" fossa-license-scan.md
}

attach_build_sonar_evidence() {
  echo "📊 Generating SonarQube evidence for build"
  generate_random_values
  
  export ATTACH_TO_BUILD="true"
  export ATTACH_TO_PACKAGE="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/build/sonar-quality-gate.json.template"
  process_template "$template_file" "sonar-quality-gate.json"
  
  printf "# SonarQube Quality Gate\n\nCode quality analysis for build %s.\n" "$BUILD_NAME" > sonar-quality-gate.md
  echo "🔍 DEBUG: Created markdown file at: $(pwd)/sonar-quality-gate.md"
  echo "🔍 DEBUG: File exists: $(ls -la sonar-quality-gate.md 2>/dev/null || echo 'NOT FOUND')"
  printf "📋 Creating SonarQube evidence...\n"
  evd_create sonar-quality-gate.json "https://sonarsource.com/evidence/quality-gate/v1" sonar-quality-gate.md
}

attach_application_slsa_evidence() {
  echo "🔐 Generating SLSA provenance evidence for application"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/unassigned/slsa-provenance.json.template"                                                            
  process_template "$template_file" "slsa-provenance.json"
  
  printf "# SLSA Provenance\n\nSupply chain provenance for %s v%s.\n" "$APPLICATION_KEY" "$APP_VERSION" > slsa-provenance.md
  printf "📋 Creating SLSA provenance evidence...\n"
  evd_create slsa-provenance.json "https://slsa.dev/provenance/v1" slsa-provenance.md                                                                           
}

attach_application_jira_evidence() {
  echo "📋 Generating Jira release evidence for application"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/unassigned/jira-release.json.template"
  process_template "$template_file" "jira-release.json"
  
  printf "# Jira Release\n\nRelease tracking for %s v%s.\n" "$APPLICATION_KEY" "$APP_VERSION" > jira-release.md
  printf "📋 Creating JIRA release evidence...\n"
  evd_create jira-release.json "https://atlassian.com/evidence/jira/v1" jira-release.md
}

attach_application_smoke_evidence() {
  echo "💨 Generating smoke test evidence for DEV stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/dev/smoke-tests.json.template"
  process_template "$template_file" "smoke-tests.json"
  
  printf "# Smoke Tests\n\nDEV environment smoke tests for %s v%s.\n" "$APPLICATION_KEY" "$APP_VERSION" > smoke-tests.md
  printf "📋 Creating smoke test evidence...\n"
  evd_create smoke-tests.json "https://testing.io/evidence/smoke-tests/v1" smoke-tests.md
}

attach_application_dast_evidence() {
  echo "🔍 Generating DAST evidence for QA stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/qa/dast-scan.json.template"
  process_template "$template_file" "dast-scan.json"
  
  printf "# DAST Scan\n\nDynamic security testing for %s v%s in QA.\n" "$APPLICATION_KEY" "$APP_VERSION" > dast-scan.md
  printf "📋 Creating DAST evidence...\n"
  evd_create dast-scan.json "https://invicti.com/evidence/dast/v3" dast-scan.md
}

attach_application_api_evidence() {
  echo "🔌 Generating API test evidence for QA stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/qa/api-tests.json.template"
  process_template "$template_file" "api-tests.json"
  
  printf "# API Tests\n\nAPI integration tests for %s v%s in QA.\n" "$APPLICATION_KEY" "$APP_VERSION" > api-tests.md
  printf "📋 Creating API test evidence...\n"
  evd_create api-tests.json "https://postman.com/evidence/collection/v2.2" api-tests.md
}

attach_application_iac_evidence() {
  echo "🏗️ Generating IaC scan evidence for STAGING stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/staging/iac-scan.json.template"
  process_template "$template_file" "iac-scan.json"
  
  printf "# IaC Scan\n\nInfrastructure security scan for %s v%s in STAGING.\n" "$APPLICATION_KEY" "$APP_VERSION" > iac-scan.md
  printf "📋 Creating IaC scan evidence...\n"
  evd_create iac-scan.json "https://snyk.io/evidence/iac/v1" iac-scan.md
}

attach_application_pentest_evidence() {
  echo "🛡️ Generating pentest evidence for STAGING stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/staging/pentest.json.template"
  process_template "$template_file" "pentest.json"
  
  printf "# Penetration Test\n\nSecurity testing for %s v%s in STAGING.\n" "$APPLICATION_KEY" "$APP_VERSION" > pentest.md
  printf "📋 Creating pentest evidence...\n"
  evd_create pentest.json "https://cobalt.io/evidence/pentest/v1" pentest.md
}

attach_application_change_evidence() {
  echo "📋 Generating change approval evidence for STAGING stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/staging/change-approval.json.template"
  process_template "$template_file" "change-approval.json"
  
  printf "# Change Approval\n\nChange management approval for %s v%s promotion to PROD.\n" "$APPLICATION_KEY" "$APP_VERSION" > change-approval.md
  printf "📋 Creating change approval evidence...\n"
  evd_create change-approval.json "https://servicenow.com/evidence/release/v1" change-approval.md
}

attach_application_deployment_evidence() {
  echo "🚀 Generating deployment verification evidence for PROD stage"
  generate_random_values
  
  export ATTACH_TO_PACKAGE="false"
  export ATTACH_TO_BUILD="false"
  
  local template_file="$EVIDENCE_TEMPLATES_DIR/application/prod/deployment-verification.json.template"
  process_template "$template_file" "deployment-verification.json"
  
  printf "# Deployment Verification\n\nProduction deployment verification for %s v%s.\n" "$APPLICATION_KEY" "$APP_VERSION" > deployment-verification.md
  printf "📋 Creating deployment verification evidence...\n"
  evd_create deployment-verification.json "https://argocd.io/evidence/deployment/v1" deployment-verification.md
}

attach_docker_package_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  echo "🐳 Attaching Docker package evidence for: $package_name"
  attach_package_pytest_evidence "$package_name" "$package_version"
  attach_package_sast_evidence "$package_name" "$package_version"
}

attach_generic_package_evidence() {
  local package_name="${1:-$PACKAGE_NAME}"
  local package_version="${2:-$PACKAGE_VERSION}"
  
  echo "📦 Attaching generic package evidence for: $package_name"
  attach_package_config_evidence "$package_name" "$package_version"
}

attach_build_evidence() {
  echo "🏗️ Attaching build evidence"
  attach_build_fossa_evidence
  attach_build_sonar_evidence
}

attach_application_unassigned_evidence() {
  echo "📋 Attaching UNASSIGNED stage evidence"
  attach_application_slsa_evidence
  attach_application_jira_evidence
}

attach_application_dev_evidence() {
  echo "🧪 Attaching DEV stage evidence"
  attach_application_smoke_evidence
}

attach_application_qa_evidence() {
  echo "🔍 Attaching QA stage evidence"
  attach_application_dast_evidence
  attach_application_api_evidence
}

attach_application_staging_evidence() {
  echo "🏗️ Attaching STAGING stage evidence"
  attach_application_iac_evidence
  attach_application_pentest_evidence
  attach_application_change_evidence
}

attach_application_prod_evidence() {
  echo "🚀 Attaching PROD stage evidence"
  attach_application_deployment_evidence
}

attach_evidence_for_stage() {
  local stage_name="${1:-}"
  case "$stage_name" in
    UNASSIGNED)
      attach_application_unassigned_evidence ;;
    DEV)
      attach_application_dev_evidence ;;
    QA)
      attach_application_qa_evidence ;;
    STAGING)
      attach_application_staging_evidence ;;
    PROD)
      attach_application_prod_evidence ;;
    BUILD)
      attach_build_evidence ;;
    *)
      echo "ℹ️ No evidence rule for stage '$stage_name'" ;;
  esac
}

setup_promotion_environment() {
  if ! command -v advance_one_step &> /dev/null; then
    local shared_promote_lib="$(dirname "$SCRIPT_DIR")/scripts/promote-lib.sh"
    if [[ -f "$shared_promote_lib" ]]; then
      source "$shared_promote_lib"
      echo "✅ Loaded shared promotion library: $shared_promote_lib"
    else
      echo "❌ Shared promotion library not found at: $shared_promote_lib" >&2
      return 1
    fi
  fi
  
  echo "✅ Promotion environment configured"
}

echo "✅ BookVerse Evidence Library loaded"
