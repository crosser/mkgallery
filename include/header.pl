# this gets `eval`-ed and must return a string to be included in the
# index html page at the top.

# The following variables are documented:
# $_{-version}		SVN release of the running script
# $_{-depth}		subdir depth relative to the "top" with .gallery2
# $_{-title}		title of the current subdir (.title contents)
# $_{-path}		path from the dir that contains .gallery2

"<h1 class=\"title\">$_{-title}</h1>".
($_{-depth}?
	"<div class=\"linkup\"><a href=\"../index.html\">UP</a></div>":
	"<div class=\"linkup\"><a href=\"/\">HOME</a></div>")
