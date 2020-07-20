<?php
/*
  Response the RSS interface  
    PPkPub.org   20200720
  Released under the MIT License.
*/

define('BASE_ODIN_URI', 'ppk:joy/rss/' ); //The base URI

//Process the resources
function plugInProcess($parent_odin_path,$resource_id,$req_resource_versoin=null){
   
    //echo $parent_odin_path,"<br>",$resource_id,"<br>",$req_resource_versoin,"<br>base_odin_prefix=",$base_odin_prefix,"<br>sub_odin_path=",$sub_odin_path;exit(-1);
    
    $tmp_posn_func_flag=strpos($resource_id,'(');
    if($tmp_posn_func_flag!==false){
      //If the resource_id contains characters '(',  processed as calling function with parameters
      //如果resource_id的含有字符(，按传入参数方式动态处理
      $obj_result=plugInProcessFunctionResource($parent_odin_path,$resource_id,$req_resource_versoin);
    }else{
      //按静态内容处理 processed as static content
      $obj_result=\PPkPub\AP::locateStaticResource($parent_odin_path,$resource_id,$req_resource_versoin);
    }
    
    return $obj_result;
}

//Process the function resources
function plugInProcessFunctionResource($parent_odin_path,$resource_id,$req_resource_versoin=null){
  global $gArrayCoinTypeSet;
  
  $tmp_posn_func_flag=strpos($resource_id,'(');
  $function_name=substr($resource_id,0,$tmp_posn_func_flag);
  $argvs_chunks=explode(",",substr($resource_id,$tmp_posn_func_flag+1,strlen($resource_id)-$tmp_posn_func_flag-2));
  $array_result=array();

  //默认不带具体版本号，表示内容是动态生成的，且下一次同样标识请求的处理结果是相同的，允许缓存生效
  $resp_resource_versoin=""; 

  //带时间作为版本号，表示内容是动态生成的，且下一次同样标识请求的处理结果是不同的，缓存应禁止
  //$resp_resource_versoin=@strftime("20%y%m%d%H%M%S",time()); 
  
  //可具体实现对请求中req_resource_versoin的支持处理，允许或不支持返回指定历史结果
  if(strlen($req_resource_versoin)>0){
     return array('code'=>410,"msg"=>"History result not supported!");
  }
  
  if($function_name=='hub'){
    $tmp_function_result = rsshub($argvs_chunks);
  }else{
    $tmp_function_result = array('code'=>404,"msg"=>"NOT EXISTED FUNCTION:".$function_name);
  }
  
  if($tmp_function_result['code'] != 0 ) {
    $tmp_function_result[\PPkPub\PTTP::PTTP_KEY_CACHE_AS_LATEST] = \PPkPub\PTTP::CACHE_AS_LATEST_NO_STORE ;
    return $tmp_function_result;
  }
    
  $array_result = $tmp_function_result['result_data'];
  
  //Only for debug
  $array_result['ppk_debug_info']=array(
    'function_name'=>$function_name,
    'function_argvs'=>$argvs_chunks,
    'time'=>@strftime("20%y-%m-%d %H:%M:%S",time()),
  );

  $str_local_uri=\PPkPub\ODIN::PPK_URI_PREFIX
                .$parent_odin_path."/"
                .$resource_id
                .\PPkPub\ODIN::PPK_URI_RESOURCE_MARK
                .$resp_resource_versoin;
                
  $str_content_type='text/json';
  
  return array(
              'code'=>0,
              'result_data'=>array(
                  'local_uri'=>$str_local_uri,
                  'content_type'=>$str_content_type,
                  'content'=>$tmp_function_result['result_data'],
                  \PPkPub\PTTP::PTTP_KEY_CACHE_AS_LATEST=>'public,max-age=3600',
              )  
          );
}


function rsshub($rss_chunks)
{
    if(count($rss_chunks)==0){
        return array('code'=>400,"msg"=>"No argus");
    }
    
    $rss_resource_path = implode($rss_chunks,'/');
    
    $rss_url = 'https://rsshub.app/'.$rss_resource_path;
    //echo '$rss_url=',$rss_url;
    
    $tmp_content=@file_get_contents($rss_url);
    
    //echo '$tmp_content=',$tmp_content;exit;
    
    if(strlen($tmp_content)>0){
       return array('code'=>0,"result_data"=>$tmp_content);
    }

    return array('code'=>404,"msg"=>"The rss content not found.");
}

