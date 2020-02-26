#!/bin/bash

src="$PIRAEUS_OPERATOR"
image="$IMAGE"

[ -n "$src" ] || exit 1
[ -n "$image" ] || exit 2

op=linstor-operator

rm -rf $op
mkdir $op

cp -a build $op/
cp -a "$src/cmd" "$src/go.mod" "$src/go.sum" "$src/pkg" "$src/version" $op/
cp "$src/build/bin/user_setup" $op/build/bin/

pushd $op
operator-sdk build $image
popd
