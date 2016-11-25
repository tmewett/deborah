local_install() {
	return sudo dpkg -i "$@"
}

check_deps() {
	(( $# > 0 )) || return 0

	# A HORRENDOUS hack to maintain check_deps' original API
	local f=$(mktemp)
	echo "$*" | sed 's/ /\n/g' | sort >f
	local query=$(dpkg-query -Wf '${Package}\n' "$@" | sort)
	local missing=$(echo "$query" | comm -23 f -)
	rm $f

	printf "%s\n" "$missing"
}

deps_install() {
	sudo apt-get install "$@"
	local ret=$?
	sudo apt-mark auto "$@"
	return $ret
}

build_package() {
	mkdir DEBIAN
	write_control > DEBIAN/control

	dpkg-deb -b . ../..
}

write_control() {
	local size="$(du -sk --apparent-size)"
	size="${size%%[^0-9]*}"

	msg2 "$(gettext "Generating %s file...")" "Debian control"

	printf "Package: %s\n" "$pkgname"
	printf "Version: %s\n" "$fullver"

	case $pkgarch in
		x86_64) pkgarch=amd64 ;;
		i686) pkgarch=i386 ;;
		*) pkgarch=all ;;
	esac

	printf "Description: %s\n" "$pkgdesc"
	printf "Homepage: %s\n" "$url"
	printf "Maintainer: %s\n" "$packager"
	printf "Installed-Size: %s\n" "$size"
	printf "Architecture: %s\n" "$pkgarch"

	if [[ -n $depends ]]; then
		printf "Depends: "
		echo "${depends[*]}" | sed 's/ /, /g'
	fi
}

