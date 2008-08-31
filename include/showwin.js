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
			zIndex: 2,
			container: document.body,
			tohide: '',
			onClick: $empty,
		}
	},

	initialize: function(name,options){
		this.setOptions(this.getOptions(), options);

		this.options.container = $(this.options.container);
		this.options.tohide = $(this.options.tohide);

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

		this.position();

		window.addEvent('resize', this.position.bind(this));
		window.addEvent('scroll', this.position.bind(this));
	},

	position: function(){
		if(this.options.container == document.body){
			this.w = window.getWidth();
			this.h = window.getHeight();
			this.s = window.getScrollTop();
		}else{
			var myCoords = this.options.container.getCoordinates();
			this.w = myCoords.width;
			this.h = myCoords.height;
			this.s = myCoords.top;
		}
		this.container.setStyles({
			top: this.s+'px',
			height: this.h+'px'
		})
	},

	getCoordinates: function(){
		return {
			width: this.w,
			height: this.h,
			top: this.s,
		};
	},

	show: function(){
		if (this.options.tohide) {
			this.hiddenstyles = this.options.tohide.getStyles(
				'display'
			);
			this.options.tohide.setStyles({
				display: 'none',
			});
		}
		this.bodystyles = document.body.getStyles(
			'overflow', 'overflow-x', 'overflow-y'
		);
		document.body.setStyles({
			overflow: 'hidden',
			'overflow-x': 'hidden',
			'overflow-y': 'hidden',
		});
		this.container.setStyle('display', 'block');
	},

	hide: function(){
		if (this.options.tohide) {
			this.options.tohide.setStyles(this.hiddenstyles);
		}
		document.body.setStyles(this.bodystyles);
		this.container.setStyle('display', 'none');
	}
})
showWindow.implement(new Options);

