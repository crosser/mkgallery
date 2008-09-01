/*
	$Id$

        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.2) http://www.mootools.net/
	Uses multibox http://www.phatfusion.net/multibox/
	Inspired by slideshow http://www.phatfusion.net/slideshow/
*/

/*
	Use slideshow classes with the index generated by mkgallery.pl
*/

/* Initialize everything, to be called on domready */
function init_gallery() {

	/* List of lists of img variations. Each image variation is
	 * a three-element array: [width, height, url]. Index of the
	 * outer array is the global ID.
	 *
	 * [
	 *  [ id, title, [
	 *                [ width, height, url ]
	 *                ...
	 *               ]
	 *   ...
	 *  ]
	 *  ...
	 * ]
	*/
	var vimgs=[];

	/* resolve string ID to index No which is the index in vimgs[] array */
	var rimgs=[];

	/* Populate images list */

	$$('div.varimages').each(function(el,i){
		rimgs[el.id] = i;
		vimgs[i] = [el.id, el.title, []];
		el.getElements('a').each(function(ael,j){
			dim = /(\d+)[^\d](\d+)/.exec(ael.text);
			w = dim[1];
			h = dim[2];
			vimgs[i][2][j]=[w,h,ael.href];
		});
	});

			/* debugging output
	var msg='loaded '+vimgs.length+' image descriptions:';
	vimgs.each(function(vimg,i){
		msg+='\nid='+i+' ('+vimg[0]+') title='+vimg[1];
		vimg[2].each(function(vv,i){
			msg+='\n     w='+vv[0]+' h='+vv[1]+' url='+vv[2];
		});
	});
	alert(msg);
			/* end debugging output */

	/* Initialize objects */

	var ovlparams = {};
	ovl = new overlay(ovlparams);

	var iboxparams = {
		overlay: ovl,
		showNumbers: false,
		showControls: true,
		openFromLink: false,
		movieWidth: 640,
		movieHeight: 480,
		descClassName: 'infoBoxDesc',
	};
	ibox = new multiBox('infoBox', iboxparams);

	var winparms = {
		tohide: 'indexContainer',
	};
	var showwin = new showWindow('slideshowContainer',winparms);

	var ctlparams = {
	};
	var ctl = new Controls('slideshowControls','slideshowContainer',
				ctlparams);

	var showparms = {
		cbStart: function(){ showwin.show(); },
		cbExit: function(){ showwin.hide(); },
	};
	var show = new Show(vimgs,showwin,ctl,showparms);

	/* Update HTML */

	$$('.conceal').each(function(el){
		el.setStyle('display', 'none');
	});
	$$('a.infoBox').each(function(el){
		var url=el.get('href');
		el.set('href',url+'?conceal');
	});

	$$('a.showStart').each(function(el){
		el.addEvent('click',
				show.start.bind(show,[rimgs[el.get('id')],1]));
	});
	$$('a.showImage').each(function(el){
		el.addEvent('click',
				show.start.bind(show,[rimgs[el.get('id')],0]));
	});

	/* Determine if we need to go directly into show mode */

	parsedurl = parseUrl(document.URL);
	/* alert('Anchor: '+parsedurl['anchor']+'\nURL: '+document.URL); */
	if ($chk(parsedurl['anchor'])){
		show.start(rimgs[parsedurl['anchor']],0);
	}
}

/* Initialization */
window.addEvent('domready',init_gallery);

