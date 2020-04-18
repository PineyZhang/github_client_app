
import 'dart:convert';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:github_client_app/common/Global.dart';
import 'package:github_client_app/models/index.dart';
import 'package:github_client_app/models/user.dart';

class Git{

  Git([this.context]){
    _options = Options(extra: {"context":context});
  }

  BuildContext context;
  Options _options;
  static Dio dio = new Dio(
    new BaseOptions(
      baseUrl: 'https://api.github.com/',
      headers: {
        HttpHeaders.acceptHeader:"application/vnd.github.squirrel-girl-preview,"
          "application/vnd.github.symmetra-preview+json",
      }
    )
  );

  static void init(){
    // 添加缓存拦截器
    dio.interceptors.add(Global.netCache);
    // 设置用户token（可能为null,代表未登录）
    dio.options.headers[HttpHeaders.authorizationHeader] = Global.profile.token;

    // 调试模式下需要抓包调试，所以我们使用代理，并禁用HTTPS证书校验
    if(!Global.isRelease){
      (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = 
        (client){
          client.findProxy = (uri){
            return "PROXY 127.0.0.1:8888";
          };
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        };
    }
  }

  /// 登录接口
  /// 登录成功后返回用户信息
  Future<User> login(String name, String pwd) async{
    String basic = 'Basic ' + base64.encode(utf8.encode('$name:$pwd'));
    var r = await dio.get(
      '/users/$name',
      options: _options.merge(headers: {
        HttpHeaders.authorizationHeader:basic
      },extra: {
        "noCache":true // 本接口禁用缓存
      })
    );

    dio.options.headers[HttpHeaders.authorizationHeader] = basic;
    Global.netCache.cache.clear();
    Global.profile.token = basic;
    return User.fromJson(r.data);
  }

  Future<List<Repo>> getRepos({Map<String, dynamic> queryParameters, // query参数，用于接收分页信息
   refresh = false}) async{
    if(refresh){
      // 列表下拉刷新，需要删除缓存（拦截器中会读取这些信息）
      _options.extra.addAll({"refresh":true,"list":true});
    }
    var r = await dio.get<List>(
      "user/repos",
      queryParameters: queryParameters,
      options: _options,
    );
    return r.data.map((e) => Repo.fromJson(e)).toList();
  }
  
}