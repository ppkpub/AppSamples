<?php
//Basic settings
define('PPK_LIB_DIR_PREFIX', dirname(__FILE__).'/../../../ppk-lib2/php/');   //此处配置PPK PHP SDK的引用路径

define('PPK_AP_NODE_NAME', 'AP Node Demo For RSS reader' );      //The label for your AP node

define('PPK_AP_PRIVATE_DIR_PREFIX', dirname(__FILE__).'/../rssap_private_path/');  //Your private data path
define('PPK_AP_RESOURCE_DIR_PREFIX', PPK_AP_PRIVATE_DIR_PREFIX."ap-resource/" ); //The static resource path
define('PPK_AP_PLUGIN_DIR_PREFIX', PPK_AP_PRIVATE_DIR_PREFIX."ap-plugin/" ); //The function plugin path
define('PPK_AP_KEY_DIR_PREFIX',      PPK_AP_PRIVATE_DIR_PREFIX."ap-key/" );      //The key file path

define('PPK_AP_DEFAULT_KEY_FILE',PPK_AP_KEY_DIR_PREFIX.'rss.key.json');    //The default key for signing data

define('PPK_API_SERVICE_URL','http://tool.ppkpub.org/ppkapi2/');  //PTTP API service for parsing ROOT ODIN etc

define('MAX_FILE_KB',1024);    //Maximum readable file size(KB)

require_once dirname(__FILE__).'/vnode.inc.php';
