#!/usr/bin/env bash


__bv__trim_base() {
  local base="${JFROG_URL:-}"
  base="${base%/}"
  printf "%s" "$base"
}


__api_stage_for() {
  local d="${1:-}"
  local p="${PROJECT_KEY:-}"
  if [[ -z "$d" || "$d" == "UNASSIGNED" ]]; then
    printf "\n"
    return 0
  fi
  if [[ "$d" == "PROD" ]]; then
    printf "%s\n" "PROD"
    return 0
  fi
  if [[ -n "$p" && "$d" == "$p-"* ]]; then printf "%s\n" "$d"; return 0; fi
  if [[ -n "$p" ]]; then printf "%s\n" "$p-$d"; else printf "%s\n" "$d"; fi
}

__persist_env() {
  local k="$1"; shift
  local v="$*"
  export "$k"="$v"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    printf "%s=%s\n" "$k" "$v" >> "$GITHUB_ENV"
  fi
}

fetch_summary() {
  local base="$(__bv__trim_base)"
  local app="${APPLICATION_KEY:-}"
  local ver="${APP_VERSION:-}"
  local tok="${JF_OIDC_TOKEN:-}"
  local url
  url="$base/apptrust/api/v1/applications/$app/versions/$ver/content"

  if [[ -z "$base" || -z "$app" || -z "$ver" || -z "$tok" ]]; then
    return 0
  fi

  local tmp; tmp="$(mktemp)"
  local code
  code=$(curl -sS -L -o "$tmp" -w "%{http_code}" \
    -H "Authorization: Bearer ${tok}" -H "Accept: application/json" \
    "$url" 2>/dev/null || echo 000)

  if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
    local curr rel
    curr=$(jq -r '.current_stage // empty' <"$tmp" 2>/dev/null || true)
    rel=$(jq -r '.release_status // empty' <"$tmp" 2>/dev/null || true)
    rm -f "$tmp"
    if [[ -n "$curr" ]]; then __persist_env CURRENT_STAGE "$curr"; fi
    if [[ -n "$rel" ]]; then __persist_env RELEASE_STATUS "$rel"; fi
    return 0
  fi
  rm -f "$tmp" || true
  return 0
}

__compute_next_display_stage() {
  local curr_disp stages next=""
  curr_disp="$(display_stage_for "${CURRENT_STAGE:-}")"
  stages=( )
  stages=(${STAGES_STR:-})
  if [[ -z "$curr_disp" || "$curr_disp" == "UNASSIGNED" ]]; then
    next="${stages[0]:-}"
  else
    local i
    for ((i=0; i<${#stages[@]}; i++)); do
      if [[ "${stages[$i]}" == "$curr_disp" ]]; then
        if (( i+1 < ${#stages[@]} )); then
          next="${stages[i+1]}"
        fi
        break
      fi
    done
  fi
  printf "%s\n" "$next"
}

advance_one_step() {
  fetch_summary || true

  local next_disp; next_disp="$(__compute_next_display_stage)"
  if [[ -z "$next_disp" ]]; then
    return 0
  fi

  local base app ver tok mode
  base="$(__bv__trim_base)"
  app="${APPLICATION_KEY:-}"
  ver="${APP_VERSION:-}"
  tok="${JF_OIDC_TOKEN:-}"
  mode="promote"

  if [[ "${ALLOW_RELEASE:-false}" == "true" && "$next_disp" == "${FINAL_STAGE:-}" ]]; then
    mode="release"
  fi

  if [[ -n "$base" && -n "$app" && -n "$ver" && -n "$tok" ]]; then
    if [[ "$mode" == "promote" ]]; then
      echo "🚀 Promoting to ${next_disp} via AppTrust"
      if promote_to_stage "$next_disp"; then
        echo "✅ Promotion to ${next_disp} successful"
        return 0
      else
        echo "❌ Promotion to ${next_disp} failed - see above for details" >&2
        return 1
      fi
    else
      echo "🚀 Releasing to ${next_disp} via AppTrust"
      if release_version; then
        echo "✅ Release to ${next_disp} successful"
        return 0
      else
        echo "❌ Release to ${next_disp} failed - see above for details" >&2
        return 1
      fi
    fi
  else
    echo "❌ Missing required parameters for AppTrust API call" >&2
    echo "   base='$base' app='$app' ver='$ver' tok='${tok:+[SET]}'" >&2
    return 1
  fi
}

#!/usr/bin/env bash
set -euo pipefail


print_request_info() {
  local method="$1"; local url="$2"; local body="${3:-}"
  echo "---- HTTP Request ----"
  echo "Method: ${method}"
  echo "URL: ${url}"
  echo "Headers: Authorization: Bearer ***REDACTED***, Accept: application/json"
  if [[ "$method" == "POST" && -n "$body" ]]; then
    echo "Body: ${body}"
  fi
  echo "---------------------"
}

api_stage_for() {
  local s="${1:-}"
  if [[ "$s" == "PROD" ]]; then
    echo "PROD"
  elif [[ "$s" == "${PROJECT_KEY:-}-"* ]]; then
    echo "$s"
  else
    echo "${PROJECT_KEY:-}-$s"
  fi
}

display_stage_for() {
  local s="${1:-}"
  if [[ "$s" == "PROD" || "$s" == "${PROJECT_KEY:-}-PROD" ]]; then
    echo "PROD"
  elif [[ "$s" == "${PROJECT_KEY:-}-"* ]]; then
    echo "${s#${PROJECT_KEY:-}-}"
  else
    echo "$s"
  fi
}

fetch_summary() {
  local body url code
  body=$(mktemp)
  url="${JFROG_URL}/apptrust/api/v1/applications/${APPLICATION_KEY}/versions/${APP_VERSION}/content"
  code=$(curl -sS -L -o "$body" -w "%{http_code}" \
    -H "Authorization: Bearer ${JF_OIDC_TOKEN}" \
    -H "Accept: application/json" \
    "$url" || echo 000)
  if [[ "$code" -ge 200 && "$code" -lt 300 ]] && jq -e . >/dev/null 2>&1 < "$body"; then
    CURRENT_STAGE=$(jq -r '.current_stage // empty' "$body" 2>/dev/null || echo "")
    RELEASE_STATUS=$(jq -r '.release_status // empty' "$body" 2>/dev/null || echo "")
  else
    echo "❌ Failed to fetch version summary" >&2
    print_request_info "GET" "$url"
    cat "$body" || true
    rm -f "$body"
    return 1
  fi
  rm -f "$body"
  echo "CURRENT_STAGE=${CURRENT_STAGE:-}" >> "$GITHUB_ENV"
  echo "RELEASE_STATUS=${RELEASE_STATUS:-}" >> "$GITHUB_ENV"
  echo "🔎 Current stage: $(display_stage_for "${CURRENT_STAGE:-UNASSIGNED}") (release_status=${RELEASE_STATUS:-unknown})"
}

apptrust_post() {
  local path="${1:-}"; local data="${2:-}"; local out_file="${3:-}"
  local url="${JFROG_URL}${path}"
  local code
  local timeout="${APPTRUST_TIMEOUT_SECONDS:-300}"
  code=$(curl -sS -L -X POST -o "$out_file" -w "%{http_code}" \
    --max-time "$timeout" \
    -H "Authorization: Bearer ${JF_OIDC_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$data" "$url" || echo 000)
  if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
    return 0
  else
    return 1
  fi
}

promote_to_stage() {
  local target_stage_display="${1:-}"
  local resp_body
  resp_body=$(mktemp)
  local api_stage
  api_stage=$(api_stage_for "$target_stage_display")
  echo "🚀 Promoting to ${target_stage_display} via AppTrust"
  # CRITICAL: async=false is REQUIRED for promotions to prevent concurrent promotion conflicts!
  # DO NOT CHANGE TO async=true - it causes "promotion already in progress" failures!
  if apptrust_post \
    "/apptrust/api/v1/applications/${APPLICATION_KEY}/versions/${APP_VERSION}/promote?async=false" \
    "{\"target_stage\": \"${api_stage}\", \"promotion_type\": \"move\"}" \
    "$resp_body"; then
    echo "HTTP OK"; cat "$resp_body" || true; echo
  else
    echo "❌ Promotion to ${target_stage_display} failed" >&2
    print_request_info "POST" "${JFROG_URL}/apptrust/api/v1/applications/${APPLICATION_KEY}/versions/${APP_VERSION}/promote?async=false" "{\"target_stage\": \"${api_stage}\", \"promotion_type\": \"move\"}"
    cat "$resp_body" || true; echo
    rm -f "$resp_body"
    return 1
  fi
  rm -f "$resp_body"
  PROMOTED_STAGES="${PROMOTED_STAGES:-}${PROMOTED_STAGES:+ }${target_stage_display}"
  echo "PROMOTED_STAGES=${PROMOTED_STAGES}" >> "$GITHUB_ENV"
  fetch_summary
}

release_version() {
  local resp_body
  resp_body=$(mktemp)
  echo "🚀 Releasing to ${FINAL_STAGE} via AppTrust Release API"
  local payload
  if [[ -n "${RELEASE_INCLUDED_REPO_KEYS:-}" ]]; then
    payload=$(printf '{"promotion_type":"move","included_repository_keys":%s}' "${RELEASE_INCLUDED_REPO_KEYS}")
  else
    local service_name
    service_name="${APPLICATION_KEY##*-}"
    
    local release_repos=()
    case "$service_name" in
      helm)
        release_repos+=(
          "${PROJECT_KEY}-${service_name}-internal-helm-release-local"
          "${PROJECT_KEY}-${service_name}-internal-generic-release-local"
        )
        ;;
      web)
        release_repos+=(
          "${PROJECT_KEY}-${service_name}-internal-npm-release-local"
          "${PROJECT_KEY}-${service_name}-internal-docker-release-local"
          "${PROJECT_KEY}-${service_name}-internal-generic-release-local"
        )
        ;;
      platform)
        release_repos+=(
          "${PROJECT_KEY}-${service_name}-public-docker-release-local"
          "${PROJECT_KEY}-${service_name}-public-python-release-local"
          "${PROJECT_KEY}-${service_name}-public-generic-release-local"
        )
        ;;
      infra)
        release_repos+=(
          "${PROJECT_KEY}-${service_name}-internal-pypi-release-local"
          "${PROJECT_KEY}-${service_name}-internal-generic-release-local"
        )
        ;;
      *)
        release_repos+=(
          "${PROJECT_KEY}-${service_name}-internal-docker-release-local"
          "${PROJECT_KEY}-${service_name}-internal-python-release-local"
          "${PROJECT_KEY}-${service_name}-internal-generic-release-local"
        )
        ;;
    esac
    
    local repos_json=""
    for repo in "${release_repos[@]}"; do
      if [[ -n "$repos_json" ]]; then
        repos_json="${repos_json},\"${repo}\""
      else
        repos_json="\"${repo}\""
      fi
    done
    payload=$(printf '{"promotion_type":"move","included_repository_keys":[%s]}' "$repos_json")
  fi
  # CRITICAL: async=false is REQUIRED for releases to prevent concurrent promotion conflicts!
  # DO NOT CHANGE TO async=true - it causes "promotion already in progress" failures!
  if apptrust_post \
    "/apptrust/api/v1/applications/${APPLICATION_KEY}/versions/${APP_VERSION}/release?async=false" \
    "$payload" \
    "$resp_body"; then
    echo "HTTP OK"; cat "$resp_body" || true; echo
  else
    echo "❌ Release to ${FINAL_STAGE} failed" >&2
    print_request_info "POST" "${JFROG_URL}/apptrust/api/v1/applications/${APPLICATION_KEY}/versions/${APP_VERSION}/release?async=false" "$payload"
    echo "❌ Response Body:"
    cat "$resp_body" || echo "(no response body available)"
    echo ""
    rm -f "$resp_body"
    return 1
  fi
  rm -f "$resp_body"
  DID_RELEASE=true
  echo "DID_RELEASE=${DID_RELEASE}" >> "$GITHUB_ENV"
  PROMOTED_STAGES="${PROMOTED_STAGES:-}${PROMOTED_STAGES:+ }${FINAL_STAGE}"
  echo "PROMOTED_STAGES=${PROMOTED_STAGES}" >> "$GITHUB_ENV"
  fetch_summary
}

emit_json() {
  local out_file="${1:-}"; shift
  local content="$*"
  printf "%b\n" "$content" > "$out_file"
}

evd_create() {
  local predicate_file="${1:-}"; local predicate_type="${2:-}"; local markdown_file="${3:-}"
  local md_args=()
  if [[ -n "$markdown_file" ]]; then md_args+=(--markdown "$markdown_file"); fi
  jf evd create-evidence \
    --predicate "$predicate_file" \
    "${md_args[@]}" \
    --predicate-type "$predicate_type" \
    --application-key "$APPLICATION_KEY" \
    --application-version "$APP_VERSION" \
    --provider-id github-actions \
    --key "${EVIDENCE_PRIVATE_KEY:-}" \
    --key-alias "${EVIDENCE_KEY_ALIAS:-${EVIDENCE_KEY_ALIAS_VAR:-}}" || true
}

attach_evidence_qa() {
  local now_ts scan_id med coll pass
  now_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  scan_id=$(cat /proc/sys/kernel/random/uuid)
  med=$((2 + RANDOM % 5))
  emit_json dast-qa.json "{\n    \"environment\": \"QA\",\n    \"scanId\": \"${scan_id}\",\n    \"status\": \"PASSED\",\n    \"findings\": { \"critical\": 0, \"high\": 0, \"medium\": ${med} },\n    \"attachStage\": \"QA\", \"gateForPromotionTo\": \"STAGING\",\n    \"timestamp\": \"${now_ts}\"\n  }"
  printf "# DAST Security Scan Report\\n\\nDAst scan completed for QA environment with medium findings: %d\\n" "$med" > dast-scan.md
  evd_create dast-qa.json "https://invicti.com/evidence/dast/v3" dast-scan.md
  coll=$(cat /proc/sys/kernel/random/uuid)
  pass=$((100 + RANDOM % 31))
  emit_json postman-qa.json "{\n    \"environment\": \"QA\",\n    \"collectionId\": \"${coll}\",\n    \"status\": \"PASSED\",\n    \"assertionsPassed\": ${pass},\n    \"assertionsFailed\": 0,\n    \"attachStage\": \"QA\", \"gateForPromotionTo\": \"STAGING\",\n    \"timestamp\": \"${now_ts}\"\n  }"
  printf "# API Testing Report\\n\\nPostman collection tests completed with %d assertions passed\\n" "$pass" > api-tests.md
  evd_create postman-qa.json "https://postman.com/evidence/collection/v2.2" api-tests.md
}

attach_evidence_staging() {
  local now_ts med_iac low_iac pent tid
  now_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  med_iac=$((1 + RANDOM % 3)); low_iac=$((8 + RANDOM % 7))
  :
  pent=$(cat /proc/sys/kernel/random/uuid)
  :
  tid=$((3000000 + RANDOM % 1000000))
  :
}

attach_evidence_prod() {
  local now_ts rev short
  now_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  rev="${GITHUB_SHA:-${GITHUB_SHA:-}}"; short=${rev:0:8}
  emit_json argocd-prod.json "{ \"tool\": \"ArgoCD\", \"status\": \"Synced\", \"revision\": \"${short}\", \"deployedAt\": \"${now_ts}\", \"attachStage\": \"PROD\" }"
  printf "# ArgoCD Deployment Report\\n\\nApplication deployed to PROD with revision: %s\\n" "$short" > argocd-deploy.md
  evd_create argocd-prod.json "https://argo.cd/ev/deploy/v1" argocd-deploy.md
}

attach_evidence_for() {
  local stage_name="${1:-}"
  case "$stage_name" in
    UNASSIGNED)
      echo "ℹ️ No evidence for UNASSIGNED" ;;
    DEV)
      echo "ℹ️ No evidence configured for DEV in demo" ;;
    QA)
      attach_evidence_qa ;;
    STAGING)
      attach_evidence_staging ;;
    PROD)
      attach_evidence_prod ;;
    *)
      echo "ℹ️ No evidence rule for stage '$stage_name'" ;;
  esac
}



