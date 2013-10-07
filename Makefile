all:
	browserify -t coffeeify -t browserify-jade chat/scripts/main.coffee -o chat/scripts/bundle.js
