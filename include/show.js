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
		}
	},

	initialize: function(vimgs, container, controls, options){
		this.setOptions(this.getOptions(), options);
		this.vimgs = vimgs;
		this.container = $(container);
		this.controls = controls;
		this.controls.registershow(this);

		window.addEvent('resize', this.resizer.bind(this))
		window.addEvent('scroll', this.scroller.bind(this))
	},

	resizer: function(){
		alert('show.resizer called');
	},

	scroller: function(){
		alert('show.scroller called');
	},

	prev: function(){
		this.controls.info(-1,this.vimgs.length,
				'<ref>','prev called');
	},

	stop: function(){
		this.controls.info(0,this.vimgs.length,
				'<ref>','stop called');
		this.controls.running(0);
	},

	play: function(){
		this.controls.info(999,this.vimgs.length,
				'<ref>','play called');
		this.controls.running(1);
	},

	next: function(){
		this.controls.info(1,this.vimgs.length,
				'<ref>','next called');
	},

	start: function(id, play){
		this.options.cbStart();
		/* real job here */
		return false; /* tao make it usable from href links */
	},

	exit: function(){
		this.options.cbExit();
	},

	comm: function(){
		alert('show.comm called, do nothing');
	},

});
Show.implement(new Options);
Show.implement(new Events);

