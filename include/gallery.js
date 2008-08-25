/*
        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.2) http://www.mootools.net/
	Uses slideshow http://www.phatfusion.net/slideshow/
*/

/*
	Slideshow
*/

var showWindow = new Class({

	getOptions: function(){
		return {
			embed: [],
			zIndex: 2,
			container: document.body,
			onClick: $empty,
		}
	},

	initialize: function(name,options){
		this.setOptions(this.getOptions(), options)

		this.options.container = $(this.options.container)

		this.container = new Element('div').addClass(name).
		setProperties({
			id: name,
			name: name,
		}).setStyles({
			position: 'absolute',
			left: '0px',
			top: '0px',
			width: '100%',
			zIndex: this.options.zIndex,
			overflow: 'hidden',
			display: 'none'
		}).addEvent('click', function(){
			this.options.onClick()
		}.bind(this)).injectInside(this.options.container);

		this.embedded = []
		this.options.embed.each(function(el){
			var sub = new Element('div')
			sub.addClass(el).setProperties({
				id: el,
				name: el,
			}).injectInside(this.container)
			this.embedded.push(sub)
		},this)

		this.position()

		window.addEvent('resize', this.position.bind(this))
		window.addEvent('scroll', this.position.bind(this))
	},

	position: function(){
		if(this.options.container == document.body){
			this.h = window.getHeight()
			this.s = window.getScrollTop()
		}else{
			var myCoords = this.options.container.getCoordinates()
			this.h = myCoords.height
			this.s = myCoords.top
		}
		this.container.setStyles({
			top: this.s+'px',
			height: this.h+'px'
		})
	},

	show: function(){
		this.container.setStyle('display', 'block')
	},

	hide: function(){
		this.container.setStyle('display', 'none')
	}
})
showWindow.implement(new Options)

var showControls = new Class({

	getOptions: function(){
		return {
			next: $empty,
			prev: $empty,
			stop: $empty,
			play: $empty,
			exit: $empty,
		}
	},

	initialize: function(name,options){
		this.setOptions(this.getOptions(), options)

		this.container = $(name)

		var buttons = ['prev','stop','play','next','exit','comm']
		buttons.each(function(el){
			var sub = new Element('div')
			if (el == 'comm') {
				this.comm = sub
				sub.set('text', 'this is a comment field')
			/*
			} else {
				sub.set('text', el)
			*/
			}
			if (this.options[el]) {
				sub.addEvent('click', function() {
					this.options[el]()
				}.bind(this))
			}
			sub.addClass('controlButton').setProperties({
				id: el,
				name: el,
			}).injectInside(this.container)
		},this)
	},

	settext: function(text) {
		this.comm.set(text)
	}
})
showControls.implement(new Options)

/* Make overlay window and start slideshow */
function showImage(id,doplay) {
 var i=rimgs[id][0]
 /* alert('show id='+id+' index='+i+' doplay='+doplay) */
 showwin.show()
 show.play(i)
 if (!doplay) {
  show.stop()
 }
 return false
}

/* Stop slideshow and return to index page */
function showStop() {
 show.quit()
 showwin.hide()
 /*
 var img = show.newImage.getElement('img');
 if(img) {
  alert('remove element: '+img.get('tag')+'.'+img.get('class')+
   '#'+img.get('id')+' src='+img.get('src'))
  img.dispose()
 }

 img = show.oldImage.getElement('img');
 if(img) {
  alert('remove element: '+img.get('tag')+'.'+img.get('class')+
   '#'+img.get('id')+' src='+img.get('src'))
  img.dispose()
 }

 show.imagesHolder.getElements('img').each(function(el){
  alert('remove element: '+el.get('tag')+'.'+el.get('class')+'#'+el.get('id')+
   ' src='+el.get('src'))
  el.dispose()
 })
 */
 return false
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
/* resolve string ID to index */
var rimgs=[]

/* Initialize everything, to be called on domready */
function init_gallery() {
 $$('.conceal').each(function(el){
  el.setStyle('display', 'none')
 })
 $$('a.infoBox').each(function(el){
  var url=el.get('href')
  el.set('href',url+'?conceal')
 })
 $$('a.showStart').each(function(el){
  el.addEvent('click', showImage.bind(el,[el.get('id'),1]))
 })
 $$('a.showImage').each(function(el){
  el.addEvent('click', showImage.bind(el,[el.get('id'),0]))
 })
 $$('div.varimages').each(function(el,i){
  rimgs[el.id] = [i, el.title]
  vimgs[i] = []
  el.getElements('a').each(function(ael,j){
   dim = /(\d+)[^\d](\d+)/.exec(ael.text)
   w = dim[1]
   h = dim[2]
   vimgs[i][j]=[w,h,ael.href]
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

 var ovlparams = {}
 ovl = new overlay(ovlparams)

 var iboxparams = {
  overlay: ovl,
  showNumbers: false,
  showControls: true,
  openFromLink: false,
  movieWidth: 640,
  movieHeight: 480,
  descClassName: 'infoBoxDesc',
 }
 ibox = new multiBox('infoBox', iboxparams)

 var winparms = {
  /* onClick: showStop,  /* temporarily */
  embed: ['slideshowControls'],
 }
 showwin = new showWindow('slideshowContainer',winparms)

 var showparms = {
  wait: 3000,
  effect: 'fade',
  duration: 1000,
  loop: false, 
  thumbnails: false,
  onClick: function(i){alert(i)}
 }
 show = new slideShow('slideshowContainer',vimgs,showparms)

 var ctlparams = {
  next: function(){show.next()},
  prev: function(){show.previous()},
  stop: function(){show.stop()},
  play: function(){show.play()},
  exit: function(){showStop()},
 }
 ctl = new showControls('slideshowControls',ctlparams)

 parsedurl = parseUrl(document.URL)
 /* alert('Anchor: '+parsedurl['anchor']+'\nURL: '+document.URL) */
 if ($chk(parsedurl['anchor'])){
  showImage(parsedurl['anchor'],0)
 }
}

/* Initialization */
window.addEvent('domready',init_gallery)
