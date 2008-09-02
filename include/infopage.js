/*
        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.1) http://www.mootools.net/
*/

function process_infopage() {
	parsedurl = parseUrl(document.URL)
	if (parsedurl['query'] == 'conceal'){
		$$('.conceal').each(function(el){
			el.setStyle('display', 'none');
		})
	}
}

/* Initialization */
window.addEvent('domready',process_infopage);
