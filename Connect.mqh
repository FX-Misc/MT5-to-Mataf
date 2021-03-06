//+------------------------------------------------------------------+
//|                                                      Connect.mqh |
//|                                                    Arnaud Jeulin |
//|                                            https://www.mataf.net |
//+------------------------------------------------------------------+
#property copyright "Arnaud Jeulin"
#property link      "https://www.mataf.net"

#include "MT5-to-mataf.mq5"
#include "JAson.mqh"

enum ENUM_HEADER_TYPE
  {
   H_CONNECT         = 0,
   H_GET             = 1,
   H_POST            = 2,
   H_PUT             = 3
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string getHeaders(ENUM_HEADER_TYPE type)
  {
   string headers;

   switch(type)
     {
      case H_CONNECT:
         headers = StringFormat("Content-Type: application/json\r\n X-Mataf-api-version: %2.f\r\n X-Mataf-source: %s",api_version,SOURCE);
         break;
      case H_PUT:
         headers = StringFormat("Content-Type: application/json\r\n X-Mataf-api-version: %2.f\r\n X-Mataf-source: %s\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-HTTP-Method-Override: PUT",api_version,SOURCE,token,id_user);
         break;
      case H_POST:
      case H_GET:
      default:
         headers = StringFormat("Content-Type: application/json\r\n X-Mataf-api-version: %2.f\r\n X-Mataf-source: %s\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d",api_version,SOURCE,token,id_user);
         break;
     }
   return (headers);

  }
//+------------------------------------------------------------------+
//| Get new token                                                    |
//+------------------------------------------------------------------+
bool GetToken()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/user/login";
   string headers = getHeaders(H_CONNECT);
   char data[];
   string str;

   parser["email"]=email;
   parser["password"]=password;
   parser.Serialize(str);

   ArrayResize(data,StringToCharArray(str,data,0,-1,CP_UTF8)-1);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   if(parser.Deserialize(data))
     {
      token   = parser["data"]["token"].ToStr();
      id_user = (int)parser["data"]["id_user"].ToInt();
      if(parser["api_version"].ToDbl()>api_version)
         MessageBox("Please update your EA. Your version: "+(string)api_version+", current version: "+parser["api_version"].ToStr());
      else
         Print("Your EA is up to date");

     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Refresh the token                                                |
//+------------------------------------------------------------------+
bool RefreshToken()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/user/refreshToken";
   string headers= getHeaders(H_POST);

   char data[];
   string str="";

   parser["id_user"]=id_user;
   parser["token"]=token;
   parser.Serialize(str);

   ArrayResize(data,StringToCharArray(str,data,0,-1,CP_UTF8)-1);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   if(parser.Deserialize(data))
     {
      token=parser["data"]["token"].ToStr();
      id_user=(int)parser["data"]["id_user"].ToInt();
     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
