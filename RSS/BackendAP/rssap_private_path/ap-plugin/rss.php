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
  }else if($function_name=='ipfs'){
    $tmp_function_result = rssIpfs($argvs_chunks[0]);
  }else if($function_name=='rinkeby'){
    $tmp_function_result = rssRinkeby($argvs_chunks[0]);
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

function rssIpfs($ipfs_hash)
{
    if(strlen($ipfs_hash)==0){
        return array('code'=>400,"msg"=>"No ipfs_hash");
    }
    
    $array_ipfs_gateways = array('https://ipfs.globalupload.io/','https://gateway.pinata.cloud/ipfs/','https://ipfs.io/ipfs/');
    
    foreach($array_ipfs_gateways as $tmp_ipfs_gateway  ){
        $ipfs_gateway_url = $tmp_ipfs_gateway.$ipfs_hash;
        //echo '$ipfs_gateway_url=',$ipfs_gateway_url;
        $tmp_content=@file_get_contents($ipfs_gateway_url);
        
        //echo '$tmp_content=',$tmp_content;exit;
        
        if(strlen($tmp_content)>0 && stripos($tmp_content,'<?xml')!==false){
           return array('code'=>0,"result_data"=>$tmp_content);
        }
    }

    return array('code'=>404,"msg"=>"The rss content not found.");
}

function rssRinkeby($tmp_address)
{
	define('RSS_DATA_FREFIX_HEX' ,'52535346454544'); //'RSSFEED';
    
	if(strlen($tmp_address)==0){
        return array('code'=>400,"msg"=>"No valid address");
    }
    
    $tmp_address=strtolower($tmp_address);

	$base_api_url = 'https://api-rinkeby.etherscan.io/api?module=account&action=txlist&address='.$tmp_address.'&sort=desc&apikey=C6852XSG3HRJAH6IM2DQFBVCAGNHQYJXCF';

    $pagesize = 5;
	for($page=1;$page<5;$page++){
		$tmp_content=@file_get_contents( $base_api_url.'&offset='.$pagesize.'&page='.$page );

		$array_resp=@json_decode($tmp_content,true);
        //print_r($array_resp);exit;
		
		if( is_array($array_resp) && array_key_exists('result',$array_resp)){
		   $tmp_counter=0;
		   for($tmp_counter=0;$tmp_counter<count($array_resp['result']);$tmp_counter++){
			   $tmp_tx=$array_resp['result'][$tmp_counter];
			   //print_r($tmp_tx);echo '<hr>';

               if( $tmp_tx['from'] == $tmp_address && $tmp_tx['to'] == $tmp_address ){
                   $tmp_posn = stripos($tmp_tx['input'],RSS_DATA_FREFIX_HEX);
                   if( $tmp_posn>0 )
                   {
                       //Matches transaction record that match the corresponding rss data
					   $str_rss_data=\PPkPub\Util::hexToStr(substr($tmp_tx['input'],$tmp_posn+strlen(RSS_DATA_FREFIX_HEX)));
					   //echo $str_rss_data;exit;
					   
					   return array('code'=>0,"result_data"=>$str_rss_data);
                   }
			   }
			}
			
			if( $tmp_counter < $pagesize ){//没有更多记录了
			   break;
		    }
		}else{
            break; //出错时结束循环
        }    
	}
    return array('code'=>404,"msg"=>"The RSS record not found.");
}

