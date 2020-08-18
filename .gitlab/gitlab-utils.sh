# Helper functions for CI

# Prepare directories:
# * download - expected to be cached
# * bin - executables on path
tests_prepare_tools() {
	mkdir -p download bin
	PATH="$(readlink -f bin):$PATH"
}

# Fetch a binary and cache it
tests_fetch_binary() {
	local name="$1"
	local key="$2"
	local url="$3"
	[ -e download/"$key" ] || { curl -sSfL "$url" > download/"$key" && chmod +x download/"$key" ; }
	ln -s ../download/"$key" bin/"$name"
}
