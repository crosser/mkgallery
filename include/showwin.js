/*
	$Id$

        This is a part of mkgallery.pl suite
        http://www.average.org/mkgallery/

	Uses mootools (1.2) http://www.mootools.net/
	Uses slideshow http://www.phatfusion.net/slideshow/
*/

/*
	Hidable "fullscreen" Window for Slideshow
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
		this.setOptions(this.getOptions(), options);

		this.options.container = $(this.options.container);

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

		this.embedded = [];
		this.options.embed.each(function(el){
			var sub = new Element('div');
			sub.addClass(el).setProperties({
				id: el,
				name: el,
			}).injectInside(this.container);
			this.embedded.push(sub);
		},this);

		this.position();

		window.addEvent('resize', this.position.bind(this));
		window.addEvent('scroll', this.position.bind(this));
	},

	position: function(){
		if(this.options.container == document.body){
			this.h = window.getHeight();
			this.s = window.getScrollTop();
		}else{
			var myCoords = this.options.container.getCoordinates();
			this.h = myCoords.height;
			this.s = myCoords.top;
		}
		this.container.setStyles({
			top: this.s+'px',
			height: this.h+'px'
		})
	},

	show: function(){
		this.container.setStyle('display', 'block');
	},

	hide: function(){
		this.container.setStyle('display', 'none');
	}
})
showWindow.implement(new Options);

