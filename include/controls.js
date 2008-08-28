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
		}
	},

	initialize: function(container, options){
		this.setOptions(this.getOptions(), options);
		this.container = $(container);
		var buttons = ['prev','stop','play','next','exit','comm'];
		buttons.each(function(el){
			var sub = new Element('div');
			sub.addClass('controlButton').setProperties({
				id: el,
				name: el,
			}).injectInside(this.container);
			this[el] = sub;
		},this);
	},

	registershow: function(show){
		alert('controls.registershow called');
		this.show = show;
		var buttons = ['prev','stop','play','next','exit'];
		buttons.each(function(el){
			var sub = new Element('div');
			sub.addEvent('click', function() {
				this.show[el]();
			}.bind(this.show));
		},this);
	},


});
Controls.implement(new Options);

