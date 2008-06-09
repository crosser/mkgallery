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
}

