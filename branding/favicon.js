var link = document.querySelector("link[rel*='icon']") || document.createElement('link');
link.type = 'image/x-icon';
link.rel = 'icon';
link.href = 'app/ext/Sam/images/favicon.ico'; 
document.getElementsByTagName('head')[0].appendChild(link);
