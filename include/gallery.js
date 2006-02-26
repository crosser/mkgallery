function showIbox(iboxid) {
 var ibox = document.getElementById(iboxid);
 var wwidth;
 var wheight;
 var bwidth = 400;
 var bheight = 300;
 if (self.innerWidth)
 {
  wwidth = self.innerWidth;
  wheight = self.innerHeight;
 }
 else if (document.documentElement && document.documentElement.clientWidth)
 {
  wwidth = document.documentElement.clientWidth;
  wheight = document.documentElement.clientHeight;
 }
 else if (document.body)
 {
  wwidth = document.body.clientWidth;
  wheight = document.body.clientHeight;
 }
 ibox.style.width = bwidth + "px";
 ibox.style.height = bheight + "px";
 ibox.style.left = ((wwidth - bwidth) / 2) + "px";
 ibox.style.top = ((wheight - bheight) / 2) + "px";
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
