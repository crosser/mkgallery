/*
	$Id$

        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.2) http://www.mootools.net/
	Inspired by slideshow http://www.phatfusion.net/slideshow/
*/

/*
	Slideshow controls

  - First, initialize "controls" without hooks to the "show".
  - Then, initialize "show" passing "controls" object as an argument to
    the constructor.
  - From the "show" constructuor, call "controls"'s "complete initialization"
    method passing them "this", so that they will be able to access "show"'s
    methods.
  - Because this is slightly simpler than symmetric "co-routine" approach,
    and arguably better suits the task at hand.
*/

var Controls = new Class({

	getOptions: function(){
		return {
			onClick: $empty,
			zIndex: 3,
			buttonClass: 'controlButton',
		}
	},

	initialize: function(name, parent, options){
		this.setOptions(this.getOptions(), options);
		this.parent = $(parent);
		this.container = new Element('div').addClass(name).
		setProperties({
			id: name,
			name: name,
		}).setStyles({
			zIndex: this.options.zIndex,
		}).addEvent('click', function(){
			this.options.onClick()
		}.bind(this)).injectInside(this.parent);
		var buttons = ['prev','stop','play','next','exit','comm'];
		buttons.each(function(el){
			var sub = new Element('div');
			sub.addClass(this.options.buttonClass).setProperties({
				id: el,
				name: el,
				title: el,
			}).addEvent('click', function(){
				this[el]();
			}.bind(this)).injectInside(this.container);
			this[el+'box'] = sub;
		},this);
		this.posbox = new Element('span').
		addClass('controlPosition').setProperties({
			id: 'controlPosition',
		}).injectInside(this.commbox);
		this.refbox = new Element('a', {
			href: 'javascript: void(1);',
			html: 'title',
		}).addClass('controlRef').setProperties({
			id: 'controlRef',
		}).injectInside(this.commbox);
	},

	registershow: function(show){
		this.show = show;
	},

	prev: function(){
		if (this.prevdisabled) { return; }
		if (this.show.prev) { this.show.prev() }
		else { alert('no method for "prev", file complaint with UN') }
	},

	stop: function(){
		if (this.show.stop) { this.show.stop() }
		else { alert('no method for "stop", file complaint with UN') }
	},

	play: function(){
		if (this.show.play) { this.show.play() }
		else { alert('no method for "play", file complaint with UN') }
	},

	next: function(){
		if (this.nextdisabled) { return; }
		if (this.show.next) { this.show.next() }
		else { alert('no method for "next", file complaint with UN') }
	},

	exit: function(){
		if (this.show.exit) { this.show.exit() }
		else { alert('no method for "exit", file complaint with UN') }
	},

	comm: function(){
		if (this.show.comm) { this.show.comm() }
		else { alert('no method for "comm", file complaint with UN') }
	},

	info: function(pos, max, ref, txt){
		var p1 = pos + 1;
		this.refbox.set('html',txt);
		this.refbox.set('href',ref);
		this.posbox.set('text',p1+' of '+max);
		if (p1 < 2) {
			this.prevbox.set('id', 'prevDisabled');
			this.prevdisabled = true;
		} else {
			this.prevbox.set('id', 'prev');
			this.prevdisabled = false;
		}
		if (p1 >= max) {
			this.nextbox.set('id', 'nextDisabled');
			this.nextdisabled = true;
		} else {
			this.nextbox.set('id', 'next');
			this.nextdisabled = false;
		}
	},

	running: function(isrunning){
		if (isrunning) {
			this.playbox.setStyle('display', 'none');
			this.stopbox.setStyle('display', 'block');
		} else {
			this.stopbox.setStyle('display', 'none');
			this.playbox.setStyle('display', 'block');
		}
	},
});
Controls.implement(new Options);

