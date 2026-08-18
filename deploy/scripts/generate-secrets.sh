#!/bin/bash
# generate-secrets.sh
# Populates missing secret values in the .env file for SimpleBudget self-hosting.
# Usage: ./deploy/scripts/generate-secrets.sh
# Run from the directory containing the .env file.

set -euo pipefail

# --- Dependency Validation ---

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: missing dependency: $1" >&2
    echo "Please install '$1' and try again." >&2
    exit 1
  fi
}

check_dependency openssl
check_dependency base64

# --- .env File Check ---

if [ ! -f ".env" ]; then
  echo "Error: .env file not found in the current directory." >&2
  echo "Copy deploy/.env.example to .env first: cp deploy/.env.example .env" >&2
  exit 1
fi

# --- Helper Functions ---

# Read a value from .env (returns empty string if key is missing or empty)
# Uses tail -1 to get the last occurrence in case of duplicates
get_env_value() {
  local key="$1"
  local value
  value=$(grep -E "^${key}=" .env 2>/dev/null | tail -1 | cut -d'=' -f2-)
  echo "$value"
}

# Set a value in .env (updates existing key or appends)
set_env_value() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" .env 2>/dev/null; then
    # Use awk to safely handle values with special characters
    awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k{print k "=" v; next} {print}' .env > .env.tmp && mv .env.tmp .env
  else
    echo "${key}=${value}" >> .env
  fi
}

# Generate a 32-char cryptographically random alphanumeric string
generate_random_password() {
  openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 32
}

# Base64url encode (no padding)
base64url_encode() {
  base64 -w 0 | tr '+/' '-_' | tr -d '='
}

# Generate a JWT signed with HS256
# Args: $1 = JSON payload, $2 = secret
generate_jwt() {
  local payload="$1"
  local secret="$2"

  local header='{"alg":"HS256","typ":"JWT"}'

  local header_b64
  header_b64=$(printf '%s' "$header" | base64url_encode)

  local payload_b64
  payload_b64=$(printf '%s' "$payload" | base64url_encode)

  local unsigned="${header_b64}.${payload_b64}"

  local signature
  signature=$(printf '%s' "$unsigned" | openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)

  echo "${unsigned}.${signature}"
}

# --- Secret Generation ---

declare -a generated_keys=()
declare -a existing_keys=()

# Generate POSTGRES_PASSWORD
current_value=$(get_env_value "POSTGRES_PASSWORD")
if [ -z "$current_value" ]; then
  new_value=$(generate_random_password)
  set_env_value "POSTGRES_PASSWORD" "$new_value"
  generated_keys+=("POSTGRES_PASSWORD")
else
  existing_keys+=("POSTGRES_PASSWORD")
fi

# Generate JWT_SECRET
current_value=$(get_env_value "JWT_SECRET")
if [ -z "$current_value" ]; then
  new_value=$(generate_random_password)
  set_env_value "JWT_SECRET" "$new_value"
  generated_keys+=("JWT_SECRET")
else
  existing_keys+=("JWT_SECRET")
fi

# Generate DASHBOARD_PASSWORD
current_value=$(get_env_value "DASHBOARD_PASSWORD")
if [ -z "$current_value" ]; then
  new_value=$(generate_random_password)
  set_env_value "DASHBOARD_PASSWORD" "$new_value"
  generated_keys+=("DASHBOARD_PASSWORD")
else
  existing_keys+=("DASHBOARD_PASSWORD")
fi

# Read JWT_SECRET for JWT generation (may have just been generated)
jwt_secret=$(get_env_value "JWT_SECRET")

# Compute timestamps
now=$(date +%s)
ten_years=$((now + 10 * 365 * 24 * 60 * 60))

# Generate ANON_KEY
current_value=$(get_env_value "ANON_KEY")
if [ -z "$current_value" ]; then
  payload="{\"role\":\"anon\",\"iss\":\"supabase\",\"iat\":${now},\"exp\":${ten_years}}"
  new_value=$(generate_jwt "$payload" "$jwt_secret")
  set_env_value "ANON_KEY" "$new_value"
  generated_keys+=("ANON_KEY")
else
  existing_keys+=("ANON_KEY")
fi

# Generate SERVICE_ROLE_KEY
current_value=$(get_env_value "SERVICE_ROLE_KEY")
if [ -z "$current_value" ]; then
  payload="{\"role\":\"service_role\",\"iss\":\"supabase\",\"iat\":${now},\"exp\":${ten_years}}"
  new_value=$(generate_jwt "$payload" "$jwt_secret")
  set_env_value "SERVICE_ROLE_KEY" "$new_value"
  generated_keys+=("SERVICE_ROLE_KEY")
else
  existing_keys+=("SERVICE_ROLE_KEY")
fi

# Generate VAPID key pair (ECDSA P-256, base64url-encoded)
current_pub=$(get_env_value "VAPID_PUBLIC_KEY")
current_priv=$(get_env_value "VAPID_PRIVATE_KEY")
if [ -z "$current_pub" ] || [ -z "$current_priv" ]; then
  # Generate a P-256 EC key pair using openssl
  vapid_privkey_pem=$(openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null)

  # Extract the 32-byte raw private key (d parameter) as base64url
  # In the EC PRIVATE KEY DER format, the raw key starts at byte offset 7
  vapid_private=$(printf '%s' "$vapid_privkey_pem" | openssl ec -outform DER 2>/dev/null | dd bs=1 skip=7 count=32 2>/dev/null | base64url_encode)

  # Extract the 65-byte uncompressed public key (last 65 bytes of the SubjectPublicKeyInfo DER)
  vapid_public=$(printf '%s' "$vapid_privkey_pem" | openssl ec -pubout -outform DER 2>/dev/null | tail -c 65 | base64url_encode)

  set_env_value "VAPID_PUBLIC_KEY" "$vapid_public"
  set_env_value "VAPID_PRIVATE_KEY" "$vapid_private"
  generated_keys+=("VAPID_PUBLIC_KEY" "VAPID_PRIVATE_KEY")
else
  existing_keys+=("VAPID_PUBLIC_KEY" "VAPID_PRIVATE_KEY")
fi

# --- Summary ---

echo "=== Secret Generation Summary ==="
echo ""

if [ ${#generated_keys[@]} -gt 0 ]; then
  echo "Generated (new):"
  for key in "${generated_keys[@]}"; do
    echo "  ✓ $key"
  done
else
  echo "Generated (new): none"
fi

echo ""

if [ ${#existing_keys[@]} -gt 0 ]; then
  echo "Preserved (existing):"
  for key in "${existing_keys[@]}"; do
    echo "  • $key"
  done
else
  echo "Preserved (existing): none"
fi

echo ""
echo "Done. All secrets are configured in .env"
