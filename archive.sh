#!/bin/sh

set -e

dir="$(cd "$(dirname "$0")" && pwd)"

archive_name="$1"
output_dir="${dir}/pack"

os="$RUNNER_OS"
if [ -z "$os" ]; then
  case "$(uname -s)" in
    Linux)
      os="Linux"
      ;;
    Darwin)
      os="macOS"
      ;;
    *)
      echo "Unknown OS type"
      exit 1
  esac
fi

if [ -z "$archive_name" ]; then
  if [ -n "$RUNNER_ARCH" ]; then
    arch="$(echo $RUNNER_ARCH | tr '[:upper:]' '[:lower:]')"
  else
    case "$(uname -m)" in
      x86_64)
        arch="x64"
        ;;
      x86|i386|i686)
        arch="x86"
        ;;
      arm64|aarch64)
        arch="arm64"
        ;;
      arm*)
        arch="arm"
        ;;
    esac
  fi

  archive="v8_${os}_${arch}.tar.xz"
else
  archive="${archive_name}.tar.xz"
fi

mkdir "$output_dir" || true

# cp -r "${dir}/v8/include" \
#   "${dir}/v8/out/release/obj/libv8_monolith.a" \
#   "${dir}/gn-args_${os}.txt" \
#   "$output_dir"

# Fail instead of shipping a bogus archive when the build did not produce V8.
test -f "${dir}/v8/out/release/d8" || { echo "d8 is missing from the build output"; exit 1; }
ls "${dir}/v8/out/release"/libv8.* >/dev/null 2>&1 || { echo "libv8 is missing from the build output"; exit 1; }

cp -vRP "${dir}/v8/out/release" "$output_dir"
rm -rf "${output_dir}/gen"
rm -rf "${output_dir}/obj"

# Compress with all cores: tar -J is single-threaded (and macOS bsdtar ignores XZ_OPT),
# which cost ~45 minutes per macOS job. A tar cut short by an error is caught by the listing below.
if command -v xz >/dev/null 2>&1; then
  tar -cf - -C "$output_dir" . | xz -T0 -c > "${dir}/${archive}"
else
  tar -Jcf "${dir}/${archive}" -C "$output_dir" .
fi
tar -Jtf "${dir}/${archive}" > "${dir}/${archive}.list"
grep -Eq "(^|/)libv8\.(so|dylib)$" "${dir}/${archive}.list" || { echo "archive does not contain libv8"; exit 1; }
rm -f "${dir}/${archive}.list"

ls -lh "${dir}/${archive}"
