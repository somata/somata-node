build:
	# Compile .coffee to .js
	coffee -o lib -c src

	# Ugly hack to prepend shebang line
	cp lib/repl.js lib/repl.js.tmp
	echo "#!/usr/bin/env node" > lib/repl.js.tmp
	cat lib/repl.js >> lib/repl.js.tmp
	mv lib/repl.js.tmp lib/repl.js

