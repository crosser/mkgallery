/*
        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.1) http://www.mootools.net/
	Uses slideshow http://www.phatfusion.net/slideshow/
*/

function showIbox(iboxid) {
 var ibox = document.getElementById(iboxid);
 var bwidth = 400;
 var bheight = 300;

 var wwidth = window.getWidth();
 var wheight = window.getHeight();

 ibox.style.top = window.getScrollTop() + ((wheight - bheight) / 2) + 'px';
 ibox.style.left = ((wwidth - bwidth) / 2) + "px";
 ibox.style.width = bwidth + "px";
 ibox.style.height = bheight + "px";
 // alert('wwidth='+wwidth+'; bwidth='+bwidth+'; wheight='+wheight+'; bheight='+bheight);
 ibox.zIndex = '0';
 ibox.style.display = 'block';
 return false;
}
function HideIbox(iboxid) {
 var ibox = document.getElementById(iboxid);
 ibox.zIndex = '1000';
 ibox.style.display = 'none';
 return false;
}

/*
	Slideshow
*/

var ShowWindow = new Class({

	getOptions: function(){
		return {
			zIndex: 2,
			container: document.body,
			onClick: Class.empty
		};
	},

	initialize: function(div,options){
		this.setOptions(this.getOptions(), options);

		this.options.container = $(this.options.container);

		this.div = $(div);
		this.div.setStyles({
			position: 'absolute',
			left: '0px',
			top: '0px',
			width: '100%',
			zIndex: this.options.zIndex,
			overflow: 'hidden',
			display: 'none'
		});
		this.div.addEvent('click', function(){
			this.options.onClick();
		}.bind(this));

		this.position();

		window.addEvent('resize', this.position.bind(this));
		window.addEvent('scroll', this.position.bind(this));
	},

	position: function(){
		if(this.options.container == document.body){
			var h = window.getHeight()+'px';
			var s = window.getScrollTop()+'px';
			this.div.setStyles({top: s, height: h});
		}else{
			var myCoords = this.options.container.getCoordinates();
			this.div.setStyles({
				top: myCoords.top+'px',
				height: myCoords.height+'px',
				left: myCoords.left+'px',
				width: myCoords.width+'px'
			});
		}
	},

	show: function(){
		this.div.setStyles({display: 'block'});
	},

	hide: function(){
		this.div.setStyles({display: 'none'});
	}
});
ShowWindow.implement(new Options);

/* Make overlay window and start slideshow */
function run_slideshow(startid) {
 showwin.show();
 show.stop();
 if (startid < 0) {
  show.play(0);
 } else {
  show.play(startid);
  show.stop();
 }
 return false;
}

/* Stop slideshow and return to index page */
function stop_slideshow() {
 show.stop();
 showwin.hide();
 return false;
}

/* List of lists of img variations. Each image variation is a three-element  */
/* array: [width, height, url]. Index of the outer array is the global ID.   */
var vimgs=[]
/*
 * [
 *  [
 *   [width, height, url]
 *   ...
 *  ]
 *  ...
 * ]
*/
/* Initialize everything, to be called on domready */
function init_gallery() {
 $$('.'+'varimages').each(function(el){
  vimgs[el.id]=[]
  el.getElements('a').each(function(ael,i){
   dim = /(\d+)[^\d](\d+)/.exec(ael.text)
   w = dim[1]
   h = dim[2]
   vimgs[id][i]=[w,h,ael.href]
  })
 })
   /* debugging output
 var msg='loaded '+vimgs.length+' image descriptions:'
 vimgs.each(function(vimg,i){
  msg+='\nid='+i
  vimg.each(function(vimg,i){
   msg+='\n     w='+vimg[0]+' h='+vimg[1]+' url='+vimg[2]
  })
 })
 alert(msg)
   /* end debugging output */

 var winparms = {}
 showwin = new ShowWindow('slideshowWindow',winparms)

 var showparms = {
  wait: 3000,
  effect: 'fade',
  duration: 1000,
  loop: true, 
  thumbnails: true,
  onClick: function(i){alert(i)}
 }
 show = new SlideShow('slideshowContainer','slideshowThumbnail',showparms)

 parsedurl = parseUrl(document.URL)
 // alert('Anchor: '+parsedurl['anchor']+'\nURL: '+document.URL)
 if ($chk(parsedurl['anchor'])){
  run_slideshow(parsedurl['anchor'])
 }
}

/* Initialization */
window.addEvent('domready',init_gallery)
