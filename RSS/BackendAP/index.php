<?php
/*
  The RSS Backend AP for PTTP Interest  
    PPkPub.org   20200720
  Released under the MIT License.
*/
require_once 'ap.common.inc.php';

$array_req = \PPkPub\AP::parsePttpInterest();

$str_req_uri = $array_req['uri'];

if( $str_req_uri==null || strlen($str_req_uri)==0)
{
  \PPkPub\AP::respPttpException( 
        $str_req_uri,
        null,
        '400',
        "Bad Request : no valid uri "
    );
  exit(-1);
}

//Determine the resource prefix used by the response
$str_map_uri=null;
$spec_key_set=null;
$spec_plugin_set=null;

//从节点配置文件(vnode.inc.php)里查询匹配项
foreach($gMapSiteURI as $tmp_req_uri_prefix => $tmp_map_set)
{
   if( 0==strncasecmp($str_req_uri,$tmp_req_uri_prefix,strlen($tmp_req_uri_prefix)) )
   {
      $str_map_uri = $tmp_map_set['dest'].substr($str_req_uri,strlen($tmp_req_uri_prefix));
      
      if(array_key_exists('key_file',$tmp_map_set)){
        $spec_key_set = \PPkPub\AP::getOdinKeySetFromFile(@$tmp_map_set['key_file']);
      } 
      
      if(array_key_exists('plugin',$tmp_map_set)){
        $spec_plugin_set = $tmp_map_set['plugin'];
      } 
      
      if($tmp_map_set['redirect']){
        //直接返回跳转应答
        \PPkPub\AP::respPttpRedirect( 
            $str_req_uri,
            null,
            'text/html',
            $str_map_uri,
            $spec_key_set
        );
        exit;
      }
      
      break;
   } 
}

//echo " str_req_uri=$str_req_uri\n str_map_uri=$str_map_uri\n"; exit(-1);

if(strlen($str_map_uri)==0)
{
  \PPkPub\AP::respPttpException( 
        $str_req_uri,
        null,
        '400',
        "Bad Request : not supported uri: ".$str_req_uri
    );
  exit(-1);
}

//Parse mapped URI segments
$map_uri_segments = \PPkPub\ODIN::splitPPkURI($str_map_uri);

$parent_odin_path=$map_uri_segments['parent_odin_path'];
$resource_id=$map_uri_segments['resource_id'];
$req_resource_versoin=$map_uri_segments['resource_versoin'];
//$odin_chunks=$map_uri_segments['odin_chunks'];
    
if($spec_plugin_set!=null){ //调用指定动态插件处理
    require_once(PPK_AP_PLUGIN_DIR_PREFIX.$spec_plugin_set);
    $obj_result=plugInProcess($parent_odin_path,$resource_id,$req_resource_versoin);
    //print_r($obj_result);exit;
}else{
   //按缺省的静态内容处理 processed as default static content
   $obj_result=\PPkPub\AP::locateStaticResource($parent_odin_path,$resource_id,$req_resource_versoin);
}

//print_r($obj_result);

//Generate and output the PTTP data package
if($obj_result['code']==0){
    $obj_result_data = $obj_result['result_data'];
    $str_resp_uri = $str_req_uri.substr($obj_result_data['local_uri'],strlen($str_map_uri));

    \PPkPub\AP::respPttpData( 
        $str_resp_uri,
        $obj_result_data['local_uri'],
        '200',
        'OK',
        $obj_result_data['content_type'],
        $obj_result_data['content'],
        @$obj_result_data[\PPkPub\PTTP::PTTP_KEY_CACHE_AS_LATEST],
        $spec_key_set
    );
}else if($obj_result['code']>=300 && $obj_result['code']<=399){ 
    //3xx：重定向类型的应答
    \PPkPub\AP::respPttpRedirect( 
        $str_req_uri,
        $str_map_uri,
        $obj_result['content_type'],
        $obj_result['content'],
        $spec_key_set,
        $obj_result['code'],
        $obj_result['msg']
    );
}else{
    //其它异常应答
    //print_r($obj_result);exit;
    \PPkPub\AP::respPttpException( 
        $str_req_uri,
        $str_map_uri,
        $obj_result['code'],
        $obj_result['msg'],
        'text/html',
        '',
        @$obj_result[\PPkPub\PTTP::PTTP_KEY_CACHE_AS_LATEST]
    );
}
