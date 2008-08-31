/*
	$Id$

        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.2) http://www.mootools.net/
	Inspired by slideshow http://www.phatfusion.net/slideshow/
*/

/*
	Slideshow

  - On show image: find this and next urls; put in place
    those that are already here; free unneeded; initiate download of
    the rest; if needed image is ready then initiate "transitioning", else
    initiate "loading".
  - On load complete: if this is the target image, initiate "transitioning".
  - On "loading": show "loading" image
  - On "transitioning": hide "loading" image; initiate FX animation to the
    needed image.
  - On animation complete: blank previous image; if "playing" then schedule
    autoswitch to next image in the future.
  - On autoswitch to next image: if "playing" then switch to next image.
  - On switch to next image: if next exists, show next image, else show
    "last image" message.
  - On switch to prev image: if prev exists, show prev image, else show
    "first image" message.
  - On "play": make "playing"; switch to next image.
  - On "stop": if "playing" cancel autoswitch; break "playing".
  - On "start show": set up things; set "playing" state; show needed image.
  - On "stop show": cancel any schedules, hide things.
  - On resize: recalculate existing image size and position; determine
    what image is needed; if it is not the one on display then request
    "show image" for the new image.
*/

var Show = new Class({

	getOptions: function(){
		return {
			cbStart: function(){ alert('show start undefined'); },
			cbExit: function(){ alert('show exit undefined'); },
			percentage: 98,
			delay: 5000,
		}
	},

	initialize: function(vimgs, container, controls, options){
		this.setOptions(this.getOptions(), options);
		this.vimgs = vimgs;
		this.container = container;
		this.controls = controls;
		this.controls.registershow(this);
		this.timer = 0;
		this.delay = this.options.delay;
		this.cache = {
			prev: {},
			curr: {},
			next: {},
		};
		this.updatecoords();
		this.previd = -1;
		this.ondisplay = new Element('img').
			injectInside(this.container.container);
		this.loadingdiv = new Element('div').
		addClass('loading').setStyles({
			position: 'absolute',
			top: 0,
			left: 0,
			zIndex: 3,
			display: 'none',
			width: this.coords.width,
			height: this.coords.height,
		}).injectInside(this.container.container);

		window.addEvent('resize', this.resizer.bind(this))
	},

	/* event handler for window resize */

	resizer: function(){
		this.updatecoords();
		var newstyle = this.calcsize(this.cache.curr);
		this.ondisplay.setStyles(newstyle);
		/* check if we need reload */
	},

	/* prev, play, stop, next, exit, comm are methods for button presses */

	prev: function(){
		if (this.currentid > 0) {
			this.show(this.currentid-1);
		} else {
			alert('show.prev called beyond first element');
		}
	},

	stop: function(){
		if (this.isplaying) { $clear(this.timer); }
		this.isplaying = false;
		$clear(this.timer);
		this.controls.running(0);
	},

	play: function(){
		this.isplaying = true;
		this.timer = this.autonext.delay(this.delay,this);
		this.controls.running(1);
	},

	next: function(){
		if (this.currentid < this.vimgs.length-1) {
			this.show(this.currentid+1);
		} else {
			alert('show.next called beyond last element');
		}
	},

	exit: function(){
		if (this.isplaying) { $clear(this.timer); }
		this.stopfx();
		this.options.cbExit();
	},

	comm: function(){
		/* alert('show.comm called, do nothing'); */
	},

	/* Entry point: called to start doing things */

	start: function(id, play){
		this.options.cbStart();
		this.isplaying = play;
		this.controls.running(this.isplaying);
		this.show(id);
		return false; /* to make it usable from href links */
	},

	/* "Private" methods to do the real job */

	show: function(id){
		/* alert('called show.show('+id+')'); */
		this.previd = this.currentid;
		this.currentid = id;
		var newcache = {
			prev: (id > 0)?this.prepare(id-1):{},
			curr: this.prepare(id),
			next: (id < (this.vimgs.length-1))?this.prepare(id+1):{},
		};
		delete this.cache;
		this.cache = newcache;
		if (this.cache.curr.ready) {
			this.display(this.cache.curr);
		} else {
			this.pendingload = true;
			this.showloading();
		}
		this.controls.info(id,this.vimgs.length,
				this.vimgs[id][0],
				this.vimgs[id][1]);
	},

	prepare: function(id){
		var vi;
		for (vi=0;vi<this.vimgs[id][2].length-1;vi++) {
			if ((this.vimgs[id][2][vi][0] >= this.target.width) ||
			    (this.vimgs[id][2][vi][1] >= this.target.height)) {
				break;
			}
		}
		/* alert('prepare id='+id+', selected '+vi+' at '+
			this.vimgs[id][2][vi][0]+'x'+
			this.vimgs[id][2][vi][1]); */
		var cachel;
		['prev', 'curr', 'next'].each(function(el){
			if (this.cache[el] &&
			    this.cache[el].id == id &&
			    this.cache[el].vi == vi) {
				cachel = this.cache[el];
			}
		}.bind(this));
		if (! cachel) {
			cachel = {
				id: id,
				vi: vi,
				ready: false,
				url: this.vimgs[id][2][vi][2],
			};
			cachel.img = this.bgload(cachel);
		}
		return cachel;
	},

	bgload: function(cachel){
		/* alert('bgload: id='+cachel.id+' vi='+cachel.vi+
			' url='+cachel.url); */
		return new Asset.image(this.vimgs[cachel.id][2][cachel.vi][2],{
			id: this.vimgs[cachel.id][0],
			title: this.vimgs[cachel.id][1],
			onload: this.loadcomplete.bind(this,[cachel]),
		});
	},

	loadcomplete: function(cachel){
		/* alert('loadcomplete '+cachel.url+' id='+cachel.id+
			' vi='+cachel.vi); */
		cachel.ready = true;
		if (cachel.id == this.currentid &&
		    this.pendingload) {
			this.pendingload = false;
			this.hideloading();
			this.display(cachel);
		}
	},

	display: function(cachel){
		var newstyle = this.calcsize(cachel);
		var newimg = cachel.img.clone();
		newimg.setStyles(newstyle);
		newimg.replaces(this.ondisplay);
		this.ondisplay = newimg;
		if (this.isplaying) {
			this.timer = this.autonext.delay(this.delay,this);
		}
	},

	autonext: function(){
		if (this.isplaying) {
			if (this.currentid < this.vimgs.length-1) {
				this.show(this.currentid+1);
			} else {
				this.exit();
			}
		}
	},

	calcsize: function(cachel){
		var factor = 1;
		var candidate;
		candidate = this.target.width /
				this.vimgs[cachel.id][2][cachel.vi][0];
		if (factor > candidate) { factor = candidate; }
		candidate = this.target.height /
				this.vimgs[cachel.id][2][cachel.vi][1];
		if (factor > candidate) { factor = candidate; }
		var w = Math.round(this.vimgs[cachel.id][2][cachel.vi][0] *
			factor);
		var h = Math.round(this.vimgs[cachel.id][2][cachel.vi][1] *
			factor);
		var t = Math.round((this.coords.height-h)/2);
		var l = Math.round((this.coords.width-w)/2);
		/* alert('new size: '+w+'x'+h+'+'+l+'+'+t); */
		return {
			position: 'absolute',
			top: t+'px',
			left: l+'px',
			width: w,
			height: h,
		};
	},

	showloading: function(){
		this.loadingdiv.setStyle('display', 'block');
	},

	hideloading: function(){
		this.loadingdiv.setStyle('display', 'none');
	},

	stopfx: function(){
	},

	updatecoords: function(){
		this.coords = this.container.getCoordinates();
		this.target = {
			width: Math.round(this.coords.width *
						this.options.percentage / 100),
			height: Math.round(this.coords.height *
						this.options.percentage / 100),
		};
		/* alert('coords: '+this.coords.width+'x'+this.coords.height+
		     ', target: '+this.target.width+'x'+this.target.height); */
	},

});
Show.implement(new Options);
Show.implement(new Events);

