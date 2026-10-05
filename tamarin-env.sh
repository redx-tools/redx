# Resolve the patched Tamarin binaries (see vendors/patches/) built under
# vendors/<variant>/out/. Sourced by ./redx and ./regtest. Override either
# REDX_TAMARIN / REDX_TAMARIN_UNCHAINED to point at a different binary.
_redx_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export REDX_TAMARIN="${REDX_TAMARIN:-$_redx_dir/vendors/tamarin-prover/out/tamarin-prover}"
export REDX_TAMARIN_UNCHAINED="${REDX_TAMARIN_UNCHAINED:-$_redx_dir/vendors/tamarin-unchained/out/tamarin-prover}"
unset _redx_dir
