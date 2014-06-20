#!/bin/sh

# Compile .coffee to .js
coffee -o lib -c src

# Ugly hack to prepend shebang line
cp lib/registry.js lib/registry.js.tmp
echo "#!/usr/bin/env node" > lib/registry.js.tmp
cat lib/registry.js >> lib/registry.js.tmp
mv lib/registry.js.tmp lib/registry.js

