/*      PPK Common JS Functions           */
/*         PPkPub.org  20200701           */  
/*    Released under the MIT License.     */

function stringToHex(str){
  var val="";
  for(var i = 0; i < str.length; i++){
      if(val == "")
          val = str.charCodeAt(i).toString(16);
      else
          val += str.charCodeAt(i).toString(16);
  }
  return val;
}

function setCookie(c_name, value, expiredays){
  var exdate=new Date();
  exdate.setDate(exdate.getDate() + expiredays);
  document.cookie=c_name+ "=" + escape(value) + ((expiredays==null) ? "" : ";expires="+exdate.toGMTString());
}

function getCookie(c_name){
  if (document.cookie.length>0){ 
    c_start=document.cookie.indexOf(c_name + "=");
    if (c_start!=-1){ 
      c_start=c_start + c_name.length+1;
      c_end=document.cookie.indexOf(";",c_start);
      if (c_end==-1) 
        c_end=document.cookie.length    
      return unescape(document.cookie.substring(c_start,c_end));
    } 
  }
  return "";
}

function utf16ToUtf8(s){
	if(!s){
		return;
	}
	
	var i, code, ret = [], len = s.length;
	for(i = 0; i < len; i++){
		code = s.charCodeAt(i);
		if(code > 0x0 && code <= 0x7f){
			//单字节
			//UTF-16 0000 - 007F
			//UTF-8  0xxxxxxx
			ret.push(s.charAt(i));
		}else if(code >= 0x80 && code <= 0x7ff){
			//双字节
			//UTF-16 0080 - 07FF
			//UTF-8  110xxxxx 10xxxxxx
			ret.push(
				//110xxxxx
				String.fromCharCode(0xc0 | ((code >> 6) & 0x1f)),
				//10xxxxxx
				String.fromCharCode(0x80 | (code & 0x3f))
			);
		}else if(code >= 0x800 && code <= 0xffff){
			//三字节
			//UTF-16 0800 - FFFF
			//UTF-8  1110xxxx 10xxxxxx 10xxxxxx
			ret.push(
				//1110xxxx
				String.fromCharCode(0xe0 | ((code >> 12) & 0xf)),
				//10xxxxxx
				String.fromCharCode(0x80 | ((code >> 6) & 0x3f)),
				//10xxxxxx
				String.fromCharCode(0x80 | (code & 0x3f))
			);
		}
	}
	
	return ret.join('');
}

function utf8ToUtf16(s){
	if(!s){
		return;
	}
	
	var i, codes, bytes, ret = [], len = s.length;
	for(i = 0; i < len; i++){
		codes = [];
		codes.push(s.charCodeAt(i));
		if(((codes[0] >> 7) & 0xff) == 0x0){
			//单字节  0xxxxxxx
			ret.push(s.charAt(i));
		}else if(((codes[0] >> 5) & 0xff) == 0x6){
			//双字节  110xxxxx 10xxxxxx
			codes.push(s.charCodeAt(++i));
			bytes = [];
			bytes.push(codes[0] & 0x1f);
			bytes.push(codes[1] & 0x3f);
			ret.push(String.fromCharCode((bytes[0] << 6) | bytes[1]));
		}else if(((codes[0] >> 4) & 0xff) == 0xe){
			//三字节  1110xxxx 10xxxxxx 10xxxxxx
			codes.push(s.charCodeAt(++i));
			codes.push(s.charCodeAt(++i));
			bytes = [];
			bytes.push((codes[0] << 4) | ((codes[1] >> 2) & 0xf));
			bytes.push(((codes[1] & 0x3) << 6) | (codes[2] & 0x3f));			
			ret.push(String.fromCharCode((bytes[0] << 8) | bytes[1]));
		}
	}
	return ret.join('');
}

//判断是否为ODIN根标识
function isRootODIN(uri){
    if(uri==null)
        return false;
    
    var parts = uri.split("/");
    
    if(parts.length==1)
        return true;
    
    if(parts.length>2)
        return false;
    
    if(parts[1].trim().length==0)
        return true;
    
    var parts2 = parts[1].split("#");
    if(parts2[0].trim().length==0)
        return true;
    else
        return false;
    
}

//获取当前时间戳（到秒值）
function getNowTimeStamp(){
    var timestamp1 = Date.parse( new Date());
    return timestamp1/1000;
}

//统一的提示信息显示方法
function myAlert(obj){
    var str= typeof(obj)=="string" ? obj : JSON.stringify(obj);
    if(typeof(imToken)  !== 'undefined' ){
        imToken.callAPI('native.toastInfo', str);
    }else{
        alert(str);
    }
}

//采用H5本地存储保存数据
function getLocalConfigData(key){
    if(typeof(Storage)!=="undefined")
    {
        // 是的! 支持 localStorage  sessionStorage 对象!
        return localStorage.getItem(key);
    } else {
        // 抱歉! 不支持 web 存储。
        return null;
    }
}

//从H5本地存储读取数据
function saveLocalConfigData(key,value){
    if(typeof(Storage)!=="undefined")
    {
        // 是的! 支持 localStorage  sessionStorage 对象!
        return localStorage.setItem(key,value);
        try {
            localStorage.setItem(key, data);
        } catch (e) {
            if (e.code === 22 ) { //如果空间已满,则自动清理,待完善为清理最旧的
                localStorage.clear();
                /*
                for(var i=localStorage.length - 1 ; i >=0; i--){
                    console.log('第'+ (i+1) +'条数据的键值为：' + localStorage.key(i) +'，数据为：' + localStorage.getItem(localStorage.key(i)));
                }
                */
                return localStorage.setItem(key, data);
            }
        }
        
    } else {
        // 抱歉! 不支持 web 存储。
        return false;
    }
}

//删除H5本地存储保存数据
function removeLocalConfigData(key){
    if(typeof(Storage)!=="undefined")
    {
        // 是的! 支持 localStorage  sessionStorage 对象!
        return localStorage.removeItem(key);
    } else {
        // 抱歉! 不支持 web 存储。
        return null;
    }
}

//获取网址中的查询参数
function getQueryString(name) {
    let reg = new RegExp("(^|&)" + name + "=([^&]*)(&|$)", "i");
    let r = window.location.search.substr(1).match(reg);
    if (r != null) {
        return decodeURIComponent(r[2]);
    };
    return null;
}

/**
 * 压缩 ，注意先引用https://cdn.bootcss.com/pako/1.0.6/pako.min.js
 */
function compressStr(strNormalString) {
    console.log("压缩前长度：" + strNormalString.length);
    var strCompressedString = null;
    try{
        strCompressedString = pako.deflate(strNormalString, { to: 'string' });
    }catch(e){
        //console.log("compressStr() error:"+e);
        strCompressedString = strNormalString;
    }
    
    console.log("压缩后长度：" + strCompressedString.length);
    return strCompressedString;
}

/**
 * 解压缩
 */
function decompressStr(strCompressedString) {
    console.log("解压前长度：" + strCompressedString.length);
    var strNormalString = null;
    try{
        strNormalString = pako.inflate(strCompressedString, { to: 'string' });
    }catch(e){
        //console.log("decompressStr() error:"+e);
        strNormalString = strCompressedString;
    }
    
    console.log("解压后长度：" + strNormalString.length);
    return strNormalString;
}

/**
 * 将AJAX的结果转换为JSON对象
 */
function parseJsonObjFromAjaxResult(result){
    if(typeof result != 'string')
        return result;
    try{
        return JSON.parse( result );
    }catch(e){
        console.log("Meet invalid json string : "+result);
        return null;
    }
};