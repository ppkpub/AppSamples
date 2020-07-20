/* 
访问PPk开放协议的JS代码
JS SDK for PPk ODIN&PTTP protocols   
-- PPkPub.org
-- 2020-07-06
*/
 
var PPKLIB = function() {
    // *****************************************************************
    // *** PRIVATE PROPERTIES AND METHODS *******************************
    // *****************************************************************
    
    //是否支持PPk插件
    var _mbSupportPeerWebPlugin = false;
    
    //ODIN根标识解析服务
    const PPK_ROOT_ODIN_API_URL = "https://tool.ppkpub.org/ppkapi2/";
    
    //IPFS访问代理服务
    const IPFS_CAT_SERVICE_URL= 'https://ipfs.eternum.io/ipfs/';
    
    
    //解构PPK资源地址
    var _splitPPkURI = function(ppk_uri){
        if(ppk_uri.substring(0,"ppk:".length).toLowerCase()!="ppk:" ) { 
            return null;
        }

        odin_chunks=[];
        parent_odin_path="";
        resource_id="";
        req_resource_versoin="";

        tmp_chunks=ppk_uri.substring("ppk:".length).split("*");
        console.log("tmp_chunks=",JSON.stringify(tmp_chunks));
        if(tmp_chunks.length>=2){
          req_resource_versoin=tmp_chunks[1];
        }

        odin_chunks=tmp_chunks[0].split("/");
        if(odin_chunks.length==1){
          parent_odin_path="";
          resource_id=odin_chunks[0];
        }else{
          resource_id=odin_chunks[odin_chunks.length-1];
          odin_chunks[odin_chunks.length-1]="";
          parent_odin_path=odin_chunks.join("/");
        }

        console.log("odin_chunks=",JSON.stringify(odin_chunks));
        console.log("odin_chunks.length=",odin_chunks.length);
        console.log("resource_id=",resource_id);
        console.log("parent_odin_path=",parent_odin_path);

        return {
                'uri':ppk_uri,
                'parent_odin_path':parent_odin_path,
                'resource_id':resource_id,
                'resource_versoin':req_resource_versoin,
                'odin_chunks':odin_chunks
            };
    };
    
    //读取缓存
    var _readCache = function(uri){
        try{
            str_cache_info = getLocalConfigData( uri );
            if( str_cache_info==null || str_cache_info.length==0 ){
                console.log("readCache() no cache for "+uri );
                return null;
            }
            
            obj_cache_info = JSON.parse( str_cache_info );
            
            exp_utc = obj_cache_info.exp_utc ;
            now = getNowTimeStamp();
            //console.log("readCache() exp_utc="+exp_utc+ " left:"+(exp_utc-now));
            
            if( exp_utc!=-1 && exp_utc < now){
                console.log("Delete expired cache for "+uri);
                removeLocalConfigData(uri);
                return null;
            }
            
            chunk_content_bytes = getLocalConfigData(obj_cache_info.data_key);
            
            if(chunk_content_bytes==null){ //无效的内容数据
                console.log("readCache() no valid data for "+ obj_cache_info.data_key );
                return null;
            }

            console.log("readCache() OK for "+uri);
            
            return decompressStr(chunk_content_bytes);
        }catch(e){
            console.log("readCache("+uri+") error:"+e);
            return null;
        }
        
    }
    
    //写入缓存
    var _saveCache = function(ppk_uri,str_pttp_data){
      try{
        ap_resp_ppk_uri = ppk_uri;
        
        //ap_resp_ppk_uri = ODIN.formatPPkURI(ap_resp_ppk_uri);
        //if(ap_resp_ppk_uri==null) //不规范的URI将不被缓存
        //    return false;
        
        chunk_content_bytes = compressStr(str_pttp_data);
        
        cache_as_latest_seconds = 3600 ; //缺省缓存1小时

        exp_utc= getNowTimeStamp() + cache_as_latest_seconds;
        
        obj_cache_info = new Object();

        obj_cache_info.exp_utc=exp_utc;
        obj_cache_info.data_key="data-"+ap_resp_ppk_uri;
        
        str_cache_info = JSON.stringify(obj_cache_info)
        saveLocalConfigData( ap_resp_ppk_uri, str_cache_info  );
        saveLocalConfigData( obj_cache_info.data_key, chunk_content_bytes  ); 
        
        console.log("saveCache() ok: "+ ap_resp_ppk_uri+ "\n str_cache_info="+str_cache_info);

        return true;
      }catch(e){
        console.log("saveCache() error:"+e.toString());
        return false;
      }
    }


    var _getApDataByAjax = function(obj_ppk_uri_info,path_level,parent_odin_setting,use_cache,callback_function){
        console.log("getApData() obj_ppk_uri_info="+JSON.stringify(obj_ppk_uri_info));
        console.log("path_level="+path_level);
        //console.log("parent_odin_setting="+JSON.stringify(parent_odin_setting));
        
        var current_uri=null;
        var str_ap_url=null;
        var is_leaf_resource = ( path_level == obj_ppk_uri_info.odin_chunks.length - 1 );
        var next_parent_odin_path=null;
        
        if(path_level==0){ //根标识
            current_uri = 'ppk:'+ obj_ppk_uri_info.odin_chunks[0] + "*";
            
            if(is_leaf_resource){
                current_uri += obj_ppk_uri_info.resource_versoin;
            }
            
            str_ap_url = PPK_ROOT_ODIN_API_URL+"?force_pns=on&pttp="+encodeURIComponent(current_uri);
            next_parent_odin_path=obj_ppk_uri_info.odin_chunks[0]+"/";
        }else { //扩展标识
            current_uri = 'ppk:'+ obj_ppk_uri_info.odin_chunks[0];
            for(kk=1;kk<path_level;kk++){
                current_uri += "/"+obj_ppk_uri_info.odin_chunks[kk];
            }
            
            if(is_leaf_resource){
                current_uri += "/"+obj_ppk_uri_info.resource_id +"*"+obj_ppk_uri_info.resource_versoin;
            }else{
                next_parent_odin_path = current_uri +"/";
                current_uri += "/"+obj_ppk_uri_info.odin_chunks[path_level]+"*";
            }
            
            
            if( !parent_odin_setting.hasOwnProperty("ap_set") ){
                callback_function("Invalid ap_set",{'status_code':503,'status_detail':"Invalid parent ap_set for "+current_uri});
                return false;
            }
            
            for(var ap_id in parent_odin_setting.ap_set) {
                tmp_ap_url = parent_odin_setting.ap_set[ap_id]['url'];
                console.log("AP[",ap_id,"]:",tmp_ap_url);
                
                if( tmp_ap_url.toLowerCase().startsWith('http') ){
                    str_ap_url = tmp_ap_url+"?pttp="+encodeURIComponent(current_uri);
                }else if( tmp_ap_url.startsWith('ppk:') && tmp_ap_url.endsWith('/') ){
                    str_ap_url = tmp_ap_url+"pttp("+stringToHex(current_uri)+")*";
                }else if( tmp_ap_url.toLowerCase().startsWith('ipfs:') ){
                    str_ap_url = IPFS_CAT_SERVICE_URL+tmp_ap_url.substr(5);
                }else{
                    str_ap_url = tmp_ap_url;
                } 
                    
                break; //目前只是用第一个AP,待完善遍历使用全部可能的AP直到获得有效应答
            }
        }

        console.log("current_uri=",current_uri);
        console.log("str_ap_url=",str_ap_url);
        console.log("is_leaf_resource=",is_leaf_resource);
        console.log("next_parent_odin_path=",next_parent_odin_path);
        
        if(use_cache){ //缓存处理
            str_pttp_data = _readCache(current_uri);
            var obj_resp = parseJsonObjFromAjaxResult(str_pttp_data);
            if(obj_resp!=null){
                return _processApDataByAjax(obj_ppk_uri_info,obj_resp,path_level,parent_odin_setting,use_cache,callback_function);
            }
        }
        
        if( str_ap_url.startsWith('ppk:') ){
            var tmp_callback =function(tmp_status,tmp_result){
                if('OK'==tmp_status){
                    obj_result_data = parseJsonObjFromAjaxResult(tmp_result);
                    
                    str_pttp_data = PPKLIB.getContentFromData(obj_result_data);
                    var obj_resp = parseJsonObjFromAjaxResult( str_pttp_data );
                    
                    if(obj_resp==null){
                        callback_function("AP response is null",null);
                        return false;
                    }
                    
                    //验证签名合法性
                    //待完善
                    
                    //缓存
                    _saveCache(current_uri,str_pttp_data);

                    return _processApDataByAjax(obj_ppk_uri_info,obj_resp,path_level,parent_odin_setting,use_cache,callback_function);
                }else{
                    console.log("Meet Invalid PPk AP!");
                    callback_function("AP ERROR","Invalid PPk AP");
                }
            }
            getPPkData(str_ap_url,tmp_callback,true)
        }else{
           $.ajax({
                type: "GET",
                url: str_ap_url,
                data: {},
                dataType: "text",
                success : function (tmp_result) {
                    var obj_resp = null;
                    var str_pttp_data = null;
                    if(tmp_result.startsWith('{')){
                        obj_resp = parseJsonObjFromAjaxResult(tmp_result);
                        str_pttp_data = tmp_result;
                    }else{
                        obj_resp = {
                            'uri' : current_uri,
                            'metainfo':JSON.stringify({"status_code":200,"content_type":"","content_length":tmp_result.length}),
                            'content': tmp_result
                        };
                        str_pttp_data = JSON.stringify(obj_resp);
                    }
                    
                    if(obj_resp==null){
                        callback_function("AP response is null",null);
                        return false;
                    }
                    
                    //验证签名合法性
                    //待完善
                    
                    //缓存
                    _saveCache(current_uri,str_pttp_data);
                    
                    return _processApDataByAjax(obj_ppk_uri_info,obj_resp,path_level,parent_odin_setting,use_cache,callback_function);
                },
                error:function(xhr,state,errorThrown){
                    console.log("Meet AJAX error!");
                    callback_function("AJAX ERROR",null);
                }
            }); 
            
        }
        return false;
    };
    
    var _processApDataByAjax = function(obj_ppk_uri_info,obj_resp,path_level,parent_odin_setting,use_cache,callback_function){

        var is_leaf_resource = ( path_level == obj_ppk_uri_info.odin_chunks.length - 1 );
        
        if(is_leaf_resource){
            callback_function("OK",obj_resp);
            return true;
        }else{
            console.log("obj_resp.metainfo="+typeof(obj_resp.metainfo));
            obj_metainfo= parseJsonObjFromAjaxResult(obj_resp.metainfo); 
            console.log("obj_metainfo="+obj_metainfo);
            if( obj_metainfo!=null && obj_metainfo.status_code==200){
                var content=obj_resp.content;
                //var content=window.atob(obj_payload.content_base64);
                console.log("_getApDataByAjax() uri=",obj_resp.uri+"\ntype=",obj_metainfo.content_type," \nlength=",obj_metainfo.content_length);
                //console.log("content=",content);

                next_parent_odin_setting = JSON.parse( content );
                if(parent_odin_setting!=null){
                    if( !next_parent_odin_setting.hasOwnProperty("ap_set") &&  parent_odin_setting.hasOwnProperty("ap_set") )
                    { //子级未设置有效AP参数时，默认继承上一级
                        next_parent_odin_setting.ap_set = parent_odin_setting.ap_set;
                    }
                    if( !next_parent_odin_setting.hasOwnProperty("vd_set") &&  parent_odin_setting.hasOwnProperty("vd_set")  )
                    { //子级未设置有效验证参数时，默认继承上一级
                        next_parent_odin_setting.vd_set = parent_odin_setting.vd_set;
                    }
                }
                
                return  _getApDataByAjax(obj_ppk_uri_info,path_level+1,next_parent_odin_setting,use_cache,callback_function);
                
            }else{
                var str_err = "PTTP status : "+obj_metainfo.status_code +" ";
                if( obj_metainfo!=null && obj_metainfo.hasOwnProperty('status_detail') ){
                    str_err += obj_metainfo.status_detail;
                }
                console.log(str_err);
                callback_function("PTTP exception",str_err);
            }
        }
        
        return false;
    }
    
    //获得方法对象的名称
    var _getFuncName = function(callee)
    {
        /*
        Function.prototype.getFuncName = function(){
            return this.name || this.toString().match(/function\s*([^(]*)\(/)[1]
        }
        return _callee.getFuncName();
        */
        
        var _callee = callee.toString().replace(/[\s\?]*/g,""),

        comb = _callee.length >= 50 ? 50 :_callee.length;
        _callee = _callee.substring(0,comb);

        var name = _callee.match(/^function([^\(]+?)\(/);
        if(name && name[1]){

            return name[1];

        }

        var caller = callee.caller,
        _caller = caller.toString().replace(/[\s\?]*/g,"");

        var last = _caller.indexOf(_callee),
        str = _caller.substring(last-30,last);
        name = str.match(/var([^\=]+?)\=/);
        if(name && name[1]){
            return name[1];
        }

        return "anonymous";
    };
    
    //初始化
    var _init = function( ){
        console.log("PPkLib-JS initing");
        if(typeof(PeerWeb) !== 'undefined'){ //检查PPk开放协议相关PeerWeb JS接口可用性
            console.log("PeerWeb enabled");
            _mbSupportPeerWebPlugin=true;
        }else{
            console.log("PeerWeb not valid");
            _mbSupportPeerWebPlugin=false;
        }
    };
    
    _init();
    
    // *****************************************************************
    // *** PUBLIC PROPERTIES AND METHODS *******************************
    // *****************************************************************
    return {
        version: "0.1.20200629", 
        
        // -- UTILITY METHODS ------------------------------------------------------------
        
         
        //检查PPk开放协议相关PeerWeb插件接口可用性, 可用返回true,否则返回false
        isPeerWebPluginEnabled: function(){ 
            return _mbSupportPeerWebPlugin;
        },
        
        //禁止PeerWeb插件接口, 强制使用AJAX方式
        disablePeerWebPlugin: function(){ 
            _mbSupportPeerWebPlugin=false;
        },
        
        //兼容DID的用户标识处理，得到以ppk:起始的URI
        formatPPkURI: function(user_uri){ 
            if(typeof user_uri == "undefined" || user_uri==null || user_uri.length==0)
                return null;
            
            if(user_uri.substring(0,"ppk:".length).toLowerCase()=="ppk:" ) { 
                user_uri = "ppk:"+user_uri.substring("ppk:".length);
            }else if(user_uri.substring(0,"did:ppk:".length).toLowerCase()=="did:ppk:" ) { 
                user_uri = user_uri.substring("did:".length);
            }else{
                user_uri = null ;
            }
            
            return user_uri;
        },
        
        //调用AJAX方式获取PPK网络资源
        loadPPkDataByAjax: function(ppk_uri,use_cache = false,callback){
            ppk_uri=this.formatPPkURI(ppk_uri);   

            if(ppk_uri==null){
                callback("Invalid ppk uri",null);
            }

            if(use_cache){ //缓存处理
                str_pttp_data = _readCache(ppk_uri);
                if(str_pttp_data!=null){
                    return callback("OK",parseJsonObjFromAjaxResult(str_pttp_data));
                }
            }
            
            var obj_ppk_uri_info = _splitPPkURI(ppk_uri);
            
            console.log("callback=",_getFuncName(callback));

            //递归解析多级路径直到叶子资源
            _getApDataByAjax(obj_ppk_uri_info,0,null,use_cache,callback);

        },
        
        //调用Plugin方式获取PPK网络资源
        loadPPkDataByPlugin: function(ppk_uri,use_cache = false,callback){
            if(!_mbSupportPeerWebPlugin){
                callback("Not support plugin",null);
            }
            
            ppk_uri=this.formatPPkURI(ppk_uri);  
            
            if(ppk_uri==null){
                callback("Invalid ppk uri",null);
            }

            PeerWeb.getPPkResource(
                ppk_uri,
                'full',
                _getFuncName(callback)  //回调方法名称
            );

        },
        
        //获取PPk原始数据包,自动选用Plugin（优先支持）或AJAX方式
        //所获得结果将作为参数传给指定的callback回调方法处理
        //回调方法参数为status字符串（正常为OK,出错为相应的错误代码）和对应PTTP数据报文完整对象字段（无法获得数据时为null）
        getPPkData: function(ppk_uri,callback,use_cache = true){
            if(_mbSupportPeerWebPlugin){
                this.loadPPkDataByPlugin(ppk_uri,use_cache,callback);
            }else{
                this.loadPPkDataByAjax(ppk_uri,use_cache,callback)
            }
        },
        
        getContentFromData: function(obj_resp){
            console.log("getContentFromData() result uri=",obj_resp.uri);
            
            if(obj_resp==null){
                return null;
            }
                
            obj_metainfo= parseJsonObjFromAjaxResult(obj_resp.metainfo); 
            
            if( obj_metainfo!=null && obj_metainfo.status_code==200){
                var content=obj_resp.content;
                console.log("getContentFromData() uri=",obj_resp.uri+"\ntype=",obj_metainfo.content_type," \nlength=",obj_metainfo.content_length);

                return content;
            }else{
                var str_err = "PTTP status : "+obj_metainfo.status_code +" ";
                if( obj_metainfo!=null && obj_metainfo.hasOwnProperty('status_detail')){
                    str_err += obj_metainfo.status_detail;
                }
                console.log(str_err);
                return null;
            }
        },
            
    }
}();