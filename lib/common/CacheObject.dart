import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:github_client_app/common/Global.dart';

class CacheObject{

  CacheObject(this.response):timeStamp = DateTime.now().millisecondsSinceEpoch;

  Response response;
  int timeStamp; // 缓存创建时间

  bool operator == (other){
    return response.hashCode == other.hashCode;
  }

  @override
  int get hashCode => response.realUri.hashCode;

}

class NetCache extends Interceptor{

  var cache = LinkedHashMap<String,CacheObject>();

  @override
  onRequest(RequestOptions options) async {
    if(!Global.profile.cache.enable) return options;
    // refresh 标记是否是“下拉刷新”
    bool refresh = options.extra["refresh"] == true;
    // 如果是下拉刷新，先删除相关缓存
    if(refresh){
      if(options.extra["list"] == true){
        // 若是列表，则只要url中包含当前path的缓存全部删除
        cache.removeWhere((key,v) => key.contains(options.path));
      }else{
        // 如果不是列表，则只删除uri相同的缓存
        delete(options.uri.toString());
      }
      return options;
    }
    
    if(options.extra["noCache"] != true && options.method.toLowerCase() == 'get'){
      String key = options.extra["cacheKey"] ?? options.uri.toString();
      var ob = cache[key];
      if(ob != null){
        // 如缓存未过期，则返回缓存内容
        if(DateTime.now().millisecondsSinceEpoch - ob.timeStamp/100 < Global.profile.cache.maxAge){
          return ob.response;
        }else{
          // 若已过期则删除缓存，继续向服务器请求
          cache.remove(key);
        }
      }
    }

  }

  @override
  Future onError(DioError err) {
    // 错误状态不缓存
  }


  @override
  Future onResponse(Response resp) {
    // 如果启用缓存，将返回结果保存到缓存
      if(Global.profile.cache.enable){
        _saveResponse(resp);
      }
  }

  void _saveResponse(Response resp) {
    RequestOptions options = resp.request;
        if(options.extra["noCache"] != null && options.method.toLowerCase() == 'get'){
          // 如果缓存数量超过最大数量限制，则先移除最早的一条记录
          if(cache.length == Global.profile.cache.maxCount){
            cache.remove(cache[cache.keys.first]);
          }
          String key = options.extra["cacheKey"] ?? options.uri.toString();
          cache[key] = CacheObject(resp);
        }
  }
  void delete(String key) {
    cache.remove(key);
  }
}