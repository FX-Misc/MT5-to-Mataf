//+-----------------------------------------------------------------------+
//|                                                      MT5-to-Mataf.mq4 |
//|       This software is licensed under the Apache License, Version 2.0 |
//|   which can be obtained at http://www.apache.org/licenses/LICENSE-2.0 |
//|                                                                       |
//|                                          Developed by Lakshan Perera: |
//|         https://www.upwork.com/o/profiles/users/_~0117e7a3d2ba0ba25e/ |
//|                                                                       |
//|                                             Documentation of the API: |
//| https://documenter.getpostman.com/view/425042/S17kzr7Y?version=latest |
//|                                                                       |
//|                            Create an account on https://www.mataf.net |
//|                  use your credentials (email+password) to use this EA |
//|                                                                       |
//+-----------------------------------------------------------------------+
#property copyright "Mataf.net"
#property link      "https://www.mataf.net"
#property version   "1.00"
#include "JAson.mqh"

//--- input parameters
input int         updateFrequency = 5;                        // Update Interval(in seconds)
input string      url="https://www.mataf.io";                 // URL
input string      email="";                                   // Email
input string      password="";                                // Password
input int         api_call_timeout=60000;                     // Time out
input string      token_file_name="MT5APISettings.txt";       // Settings File Name
input string      AccountAlias="Test Account MT5";            // Alias

string token="";
int id_user;
int AccountID;
string settings_file="";
CJAVal settingsFileParser;
bool previous_finished=true;
//+------------------------------------------------------------------+
//| File Type                                                        |
//+------------------------------------------------------------------+
enum ENUM_FILE_TYPE
  {
   TOKEN,
   USER_ID,
   ACCOUNT_ID
  };
bool connected=false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(updateFrequency);
   if(!connected)
      return(ApiOnInit());
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   if(reason==REASON_PARAMETERS)
      connected=false;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   if(!MQLInfoInteger(MQL_TESTER) && previous_finished)
     {
      OnTickSimulated();
     }

  }
//+------------------------------------------------------------------+
//| Connect To the API                                               |
//+------------------------------------------------------------------+
int ApiOnInit()
  {
   Comment("Gettting the token...");
   LoadSettings();

   Sleep(300);
   Comment("Creating an account...");
   if(!CreateAccount())
     {
      //---trying again with a fresh token
      GetToken();
      if(!CreateAccount())
        {
         Comment("Account Creation Failed!");
         return(INIT_FAILED);
        }
     }
   else
      Comment("Account created!...");
   Sleep(500);

//Alert("Connected to Mataf!");
   Comment("");
   previous_finished=false;
   UpdateTradesList(true);
   UpdateOrderList();
   previous_finished=true;

//OnTickSimulated();

   connected=true;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Send request at given frequency                                  |
//+------------------------------------------------------------------+
void OnTickSimulated()
  {
   previous_finished=false;
   CreateAccount(false);
   if(!UpdateOrderList())
     {
      Sleep(10);
      UpdateOrderList();
     }
   if(!UpdateTradesList())
     {
      Sleep(10);
      UpdateTradesList();
     }
   previous_finished=true;
  }
//+------------------------------------------------------------------+
//| Load settings: Token, id_user and AccountID from file            |
//+------------------------------------------------------------------+
void LoadSettings()
  {
   if(FileIsExist(token_file_name))
     {
      int handle=FileOpen(token_file_name,FILE_READ|FILE_TXT);
      settings_file=FileReadString(handle);
      FileClose(handle);
      //Print("Settings file is loaded");

      if(settingsFileParser.Deserialize(settings_file))
        {
         token=settingsFileParser["token"].ToStr();
         id_user=(int)settingsFileParser["id_user"].ToInt();
         AccountID=(int)settingsFileParser["AccountID"].ToInt();

         if(AccountID<=0 || id_user<=0 || token=="")
            GetToken();
        }
     }
   else
      GetToken();
  }
//+------------------------------------------------------------------+
//| Save token, id_user and AccountID onto the settings file         |
//+------------------------------------------------------------------+
void SaveSettings()
  {
   int handle=FileOpen(token_file_name,FILE_WRITE|FILE_TXT);
   FileWriteString(handle,settings_file);
   FileFlush(handle);
   FileClose(handle);
//Print("Settings saved to file");
  }
//+------------------------------------------------------------------+
//| Get new token                                                    |
//+------------------------------------------------------------------+
bool GetToken()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/user/login";
   string headers = "Content-Type: application/json\r\n X-Mataf-api-version: 1\r\n";
   char data[];
   string str="{"
              +GetLine("email",email)
              +GetLine("password",password,true)
              +"\r\n}";

   StringToCharArray(str,data,0,StringLen(str),CP_UTF8);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);
//Print(__FUNCTION__+" Result is "+(string)result+": "+(string)GetLastError());

   if(parser.Deserialize(data))
     {
      token=parser["data"]["token"].ToStr();

     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   id_user=(int)parser["data"]["id_user"].ToInt();

//Print("New Token: "+token);
//Print("id_user: ",id_user);

   settingsFileParser["token"]=token;
   settingsFileParser["id_user"]=id_user;

   settings_file=settingsFileParser.Serialize();
   SaveSettings();

   return(true);
  }
//+------------------------------------------------------------------+
//| Refresh the token                                                |
//+------------------------------------------------------------------+
bool RefreshToken()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/user/refreshToken";
   string headers= StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1",token,id_user);

   char data[];
   string str="";

   parser["id_user"]=id_user;
   parser["token"]=token;
   parser.Serialize(str);

   StringToCharArray(str,data,0,StringLen(str),CP_UTF8);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);
//Print(__FUNCTION__+" Result is "+(string)result+": "+(string)GetLastError());

   if(parser.Deserialize(data))
     {
      token=parser["data"]["token"].ToStr();
     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   id_user=(int)parser["data"]["id_user"].ToInt();

//Print("Token: "+token);
//Print("id_user: ",id_user);

   settingsFileParser["token"]=token;
   settingsFileParser["id_user"]=id_user;

   settings_file=settingsFileParser.Serialize();
   SaveSettings();

   return(true);
  }
//+------------------------------------------------------------------+
//| Create new account/update existing                               |
//+------------------------------------------------------------------+
bool CreateAccount(const bool firstRun=true)
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/trading/accounts";
   string headers= StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1",token,id_user);

   char data[];
   string str="";
   string created_time="";

   double total_deposits=0,total_withdraw=0;
   string acountdepositsObject="";

   HistorySelect(0,TimeCurrent());
   int counter=0;
   for(int j=0; j<HistoryDealsTotal(); j++)
     {
      ulong dealTicket=HistoryDealGetTicket(j);
      if(HistoryDealGetInteger(dealTicket,DEAL_TYPE)==DEAL_TYPE_BALANCE || HistoryDealGetInteger(dealTicket,DEAL_TYPE)==DEAL_TYPE_BONUS || HistoryDealGetInteger(dealTicket,DEAL_TYPE)==DEAL_TYPE_CREDIT)
        {
         datetime date = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         double amount = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

         string type=(HistoryDealGetInteger(dealTicket,DEAL_TYPE)==DEAL_TYPE_BALANCE  ?(amount>0?"DEPOSIT":"WITHDRAWAL"): "CREDIT/BONUS");
         string dealComment=HistoryDealGetString(dealTicket,DEAL_COMMENT);
         if(created_time=="")
            created_time=TimeToString(date,TIME_SECONDS|TIME_DATE);

         if(counter>0)
            acountdepositsObject+=",";
         if(amount>0)
           {
            total_deposits+=amount;
            acountdepositsObject+=CreateAccountTransactionJson(type,amount,date,(int)dealTicket,dealComment);
           }
         else
           {
            total_withdraw+=MathAbs(amount);
            acountdepositsObject+=CreateAccountTransactionJson(type,amount,date,(int)dealTicket,dealComment);
           }
         counter++;

        }
     }
   bool IsDemo=false;
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO)
      IsDemo=true;
   string AccountJson="{"
                      +GetLine("account_id_from_provider",string(AccountInfoInteger(ACCOUNT_LOGIN)))
                      +GetLine("provider_name",AccountInfoString(ACCOUNT_COMPANY))
                      +GetLine("source_name","MT5")
                      +GetLine("user_id_from_provider",string(AccountInfoInteger(ACCOUNT_LOGIN)))
                      +GetLine("account_alias",AccountAlias)
                      +GetLine("account_name",AccountInfoString(ACCOUNT_NAME))
                      +GetLine("currency",AccountInfoString(ACCOUNT_CURRENCY))
                      +GetLine("is_live",!IsDemo)
                      +GetLine("is_active",true)
                      +GetLine("balance",(float)AccountInfoDouble(ACCOUNT_BALANCE))
                      +GetLine("profit_loss",AccountInfoDouble(ACCOUNT_BALANCE)-(total_deposits-total_withdraw))
                      +GetLine("open_profit_loss",AccountInfoDouble(ACCOUNT_PROFIT))
                      +"\"funds\":"
                      +"{"
                      +GetLine("deposit",total_deposits)
                      +GetLine("withdraw",-1*total_withdraw)
                      +"\"history\":"
                      +"["
                      +acountdepositsObject
                      +"]"
                      +"},"
//+GetLine("rollover",132)
//+GetLine("commission",12)
//+GetLine("other_fees",0)
                      +GetLine("created_at_from_provider",created_time,true)
                      +"}";

   str="{"
       +GetLine("version",1)
       +"\"data\":"+AccountJson
       +"}";

//int handle= FileOpen(__FUNCTION__+".json",FILE_TXT|FILE_WRITE);
//if(handle!=INVALID_HANDLE)FileWriteString(handle,str,StringLen(str));
//FileClose(handle);

   StringToCharArray(str,data,0,StringLen(str),CP_UTF8);
   ResetLastError();
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);
//if(firstRun || result!=200)Print(__FUNCTION__+"  Result is "+(string)result+": "+(string)GetLastError());
   if(result!=200)
      return(false);

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Creating Account: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         return(false);
        }
      else
        {
         AccountID=(int)parser["data"]["id"].ToInt();
         if(firstRun)
            PrintFormat("Account Created successfully, Account ID: %d",AccountID);
        }
     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   settingsFileParser["AccountID"]=AccountID;
   settings_file=settingsFileParser.Serialize();
   if(firstRun)
      SaveSettings();

   return(true);
  }
//+------------------------------------------------------------------+
//| Update Order List                                                |
//+------------------------------------------------------------------+
bool UpdateOrderList()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/trading/accounts/"+(string)AccountID+"/orders";
   string headers= StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1\r\n X-HTTP-Method-Override: PUT",token,id_user);
   char data[];
   string str=CreateOpenedOrderListJson();
   if(str=="" || str==NULL)
      return(true);

   StringToCharArray(str,data,0,StringLen(str),CP_UTF8);

   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   int error= GetLastError();
//if(error!=ERR_SUCCESS || result!=200) Print(__FUNCTION__+"  Result is "+(string)result+": "+(string)error);

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Updating Order List: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         //Print("Token: ",token);
         //Print("AccountID: ",AccountID);
         //Print("id_user: ",id_user);
         return(false);
        }
     }
   else
      Print("Failed to Deserialize");

   return(true);
  }
//+------------------------------------------------------------------+
//| Update Trades List                                                |
//+------------------------------------------------------------------+
bool UpdateTradesList(const bool firsRun=false)
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/trading/accounts/"+IntegerToString(AccountID)+"/trades";
   string headers= StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1\r\n X-HTTP-Method-Override: PUT",token,id_user);
//Print("headers: ",headers);
   char data[];
   string str=CreateTradesListJson(firsRun);
   if(str=="" || str==NULL)
      return(true);
//--- save the json to a file
//if(firsRun)
//  {
//   int handle=FileOpen("UpdateTradesList.json",FILE_WRITE|FILE_TXT|FILE_SHARE_READ);
//   FileWriteString(handle,str);
//   FileClose(handle);
//  }
//return(true);
//--- end saving

   StringToCharArray(str,data,0,StringLen(str),CP_UTF8);

   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   int error=GetLastError();
//if(result!=200)
//   Print(__FUNCTION__+"  Result is "+(string)result+": "+(string)error);

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Updating Trades List: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         //Print("Token: ",token);
         //Print("AccountID: ",AccountID);
         //Print("id_user: ",id_user);
         return(false);
        }
      else
        {
         //Print("Trades list updated successfully");
        }
     }
   else
      Print("Failed to Deserialize");
   return(true);
  }
//+------------------------------------------------------------------+
//| Get the current time stamp                                       |
//+------------------------------------------------------------------+
datetime GetLastActiveTimeStamp()
  {

   return(0);
  }
//+------------------------------------------------------------------+
//| Easier JSON Parser by line (key:value pair)                      |
//+------------------------------------------------------------------+
template<typename T>
string GetLine(const string key,const T value,const bool lastline=false)
  {
   if(typename(T)=="string")
      return(lastline?"\t\r\n\""+key+"\":"+"\""+(string)value+"\"":"\t\r\n\""+key+"\":"+"\""+(string)value+"\",");
   else
      return(lastline?"\t\r\n\""+key+"\":"+(string)value:"\t\r\n\""+key+"\":"+(string)value+",");
  }
//+------------------------------------------------------------------+
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
string CreateAccountTransactionJson(const string method,const double amount,const datetime time,const int id,const string comment)
  {
   string main="{"
               +GetLine("type",method)
               +GetLine("amount",amount)
               +GetLine("time",TimeToString(time,TIME_SECONDS|TIME_DATE))
               +GetLine("transaction_id_from_provider",(string)id)
               +GetLine("comment",comment,true)
               +"}";
   return(main);
  }
//+------------------------------------------------------------------+
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
string CreateOrderObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const ENUM_ORDER_TYPE order_type,const double sl_level,
                             const double tp_level,const datetime expiry,const datetime open_time,const datetime closed_time)
  {
   string dir="SELL",type="LIMIT";
   if(order_type==ORDER_TYPE_BUY|| order_type==ORDER_TYPE_BUY_STOP|| order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP_LIMIT)
      dir="BUY";
   if(order_type== ORDER_TYPE_BUY_LIMIT|| order_type == ORDER_TYPE_SELL_LIMIT)
      type="LIMIT";
   else
      if(order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_SELL_STOP)
         type="STOP";

   string main="{"
               +GetLine("order_id_from_provider",order_id)
               +GetLine("account_id",AccountID)
               +"\"trade_id\":null,"
               +GetLine("trade_id_from_provider",order_id)
               +GetLine("instrument_id_from_provider",symbol)
               +GetLine("units",lotsize)
               +GetLine("currency",symbol)
               +GetLine("price",open_price)
               +GetLine("execution_price",open_price)
               +GetLine("direction",dir)//
               +GetLine("stop_loss",sl_level)
               +GetLine("take_profit",tp_level)
               +GetLine("trailing_stop",0)
               +GetLine("stop_loss_distance",0)
               +GetLine("take_profit_distance",0)
               +GetLine("trailing_stop_distance",0)
               +GetLine("order_type",type)
               +GetLine("status",order_type>ORDER_TYPE_SELL?"PENDING":"FILLED")
               +GetLine("expire_at",expiry>0?TimeToString(expiry,TIME_SECONDS|TIME_DATE):(string)0)
               +GetLine("created_at_from_provider",open_time>0?TimeToString(open_time,TIME_SECONDS|TIME_DATE):(string)0)
               +GetLine("closed_at_from_provider",closed_time>0?TimeToString(closed_time,TIME_SECONDS|TIME_DATE):(string)0,true)
               +"}";
   return(main);
  }
//+------------------------------------------------------------------+
//| Create a trade object in JSON                                    |
//+------------------------------------------------------------------+
string CreateTradeObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const double closed_price,const double PnL,const ENUM_ORDER_TYPE order_type,const double sl_level,
                             const double tp_level,const datetime open_time,const datetime closed_time,const double commission,const double rollover,const double other_fees
                            )
  {
   double spread_cost=SymbolInfoInteger(symbol,SYMBOL_SPREAD)*SymbolInfoDouble(symbol,SYMBOL_POINT)*SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE)*lotsize;
   string dir="SELL";
   if(order_type==ORDER_TYPE_BUY || order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP_LIMIT)
      dir="BUY";

   string type="";
   if(order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_SELL_LIMIT)
      type="LIMIT";
   else
      if(order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_SELL_STOP)
         type="STOP";

   string main="{"
               +GetLine("trade_id_from_provider",order_id)
               +GetLine("account_id",AccountID)
//+"\"trade_id\":null,"
               +GetLine("instrument_id_from_provider",symbol)
               +GetLine("direction",dir)
               +GetLine("type",order_type<=ORDER_TYPE_SELL?"MARKET":type)
               +GetLine("units",lotsize)
               +GetLine("currency",StringSubstr(symbol,3,3))
               +GetLine("open_price",open_price)
               +GetLine("closed_price",closed_time>0?closed_price:0)
               +GetLine("profit_loss",closed_time>0?PnL:0.0)
               +GetLine("open_profit_loss",closed_time>0?0:PnL)
               +GetLine("rollover",rollover)
               +GetLine("commission",commission)
               +GetLine("other_fees",other_fees)
               +GetLine("spread_cost",spread_cost)
               +GetLine("status",closed_time>0?(order_type>ORDER_TYPE_SELL?"CANCELLED":"CLOSED"):"OPEN")
               +GetLine("balance_at_opening",AccountInfoDouble(ACCOUNT_BALANCE)-PnL)
               +GetLine("stop_loss",sl_level)
               +GetLine("take_profit",tp_level)
               +GetLine("trailing_stop",0)
               +GetLine("stop_loss_distance",0)
               +GetLine("take_profit_distance",0)
               +GetLine("trailing_stop_distance",0)
               +GetLine("created_at_from_provider",open_time>0?TimeToString(open_time,TIME_SECONDS|TIME_DATE):(string)0)
               +GetLine("closed_at_from_provider",closed_time>0?TimeToString(closed_time,TIME_SECONDS|TIME_DATE):(string)0,true)
               +"}";

   return(main);
  }
//+------------------------------------------------------------------+
//| Create currently opened order list                               |
//+------------------------------------------------------------------+
string CreateOpenedOrderListJson()
  {
   string json="{"
               +GetLine("version",1)
               +GetLine("delete_data_not_in_list",true)
               +"\"data\":[";
   int x=0;
   double profit=0;
   string symbol;
   double order_lots=0,order_units=0,order_open_price=0,order_sl=0,order_tp=0;
   datetime expiration=0,open_time=0,close_time=0;
   ENUM_ORDER_TYPE type;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket>0)
        {
         type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         symbol=OrderGetString(ORDER_SYMBOL);
         order_lots=OrderGetDouble(ORDER_VOLUME_INITIAL);
         order_units=order_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
         order_open_price=OrderGetDouble(ORDER_PRICE_OPEN);
         order_sl=OrderGetDouble(ORDER_SL);
         order_tp=OrderGetDouble(ORDER_TP);
         expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         open_time=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
         close_time=0;

         string id=IntegerToString(OrderGetInteger(ORDER_POSITION_ID));

         if(x>0)
            json+=",";
         json+=CreateOrderObjectJson((string)id,symbol,order_units,
                                     order_open_price,type,order_sl,order_tp,expiration,open_time,close_time);
         x++;
        }
     }

   json+="] }";

//if(x==0)return("");

   return(json);
  }
//+------------------------------------------------------------------+
//| Create currently opened and closed trade list                    |
//+------------------------------------------------------------------+
string CreateTradesListJson(const bool firstRun)
  {
   string json="{"
               +GetLine("version",1)
               +GetLine("delete_data_not_in_list",firstRun)
               +"\"data\":[";

   datetime today=StringToTime(TimeToString(TimeCurrent(),TIME_DATE|TIME_DATE));

// Opened positions
   int x=0;
   double profit=0;
   string symbol;
   double position_lots=0,position_units=0,position_open_price=0,position_sl=0,position_tp=0;
   datetime expiration=0,open_time=0,close_time=0;
   double commision=0,swap=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0)
        {
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         profit = PositionGetDouble(POSITION_PROFIT);
         symbol = PositionGetString(POSITION_SYMBOL);

         position_lots=PositionGetDouble(POSITION_VOLUME);
         position_units=position_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
         position_open_price=PositionGetDouble(POSITION_PRICE_OPEN);
         position_sl=PositionGetDouble(POSITION_SL);
         position_tp=PositionGetDouble(POSITION_TP);
         swap=PositionGetDouble(POSITION_SWAP);
         expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         open_time=(datetime)PositionGetInteger(POSITION_TIME);
         close_time=0;
         commision=0;
         if(PositionSelectByTicket(ticket))
           {
            for(int j=0; j<HistoryDealsTotal(); j++)
              {
               ulong dealTicket=HistoryDealGetTicket(j);
               commision+=HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
              }
           }

         if(x++>0)
            json+=",";
         json+=CreateTradeObjectJson((string)ticket,symbol,position_units,position_open_price,SymbolInfoDouble(symbol,(type==POSITION_TYPE_BUY?SYMBOL_BID:SYMBOL_ASK)),
                                     profit,(ENUM_ORDER_TYPE)type,position_sl,position_tp,
                                     open_time,0,commision,swap,0);
        }
     }

   double order_lots=0,order_units=0,order_open_price=0,order_close_price=0,order_sl=0,order_tp=0;
   ENUM_ORDER_TYPE type=0;
   HistorySelect(0,TimeCurrent());
   for(int i=HistoryOrdersTotal()-1; i>=0; i--)
     {
      HistorySelect(0,TimeCurrent());

      ulong ticket=HistoryOrderGetTicket(i);
      long positionID=HistoryOrderGetInteger(ticket,ORDER_POSITION_ID);
      if(positionID==ticket)
         continue;
      symbol=HistoryOrderGetString(ticket,ORDER_SYMBOL);
      order_lots=HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);
      order_units=order_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);


      order_open_price=HistoryOrderGetDouble(positionID,ORDER_PRICE_OPEN);
      order_sl=HistoryOrderGetDouble(positionID, ORDER_SL);
      order_tp=HistoryOrderGetDouble(positionID, ORDER_TP);

      profit=0;

      open_time=(datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP);
      close_time=(datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_DONE);
      if(!firstRun)
        {
         if(close_time<today)
            break;
        }

      swap=0;
      commision=0;
      if(HistorySelectByPosition(positionID))
        {
         for(int j=0; j<HistoryDealsTotal(); j++)
           {
            ulong dealTicket=HistoryDealGetTicket(j);

            swap+=HistoryDealGetDouble(dealTicket,DEAL_SWAP);
            commision+=HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);

            if(HistoryDealGetInteger(dealTicket,DEAL_ENTRY)==DEAL_ENTRY_IN)
              {
               type=(ENUM_ORDER_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
               order_open_price=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
              }
            else
               if(HistoryDealGetInteger(dealTicket,DEAL_ENTRY)==DEAL_ENTRY_OUT)
                 {
                  profit+=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
                  order_close_price=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
                 }
           }
        }

      if(x++>0)
         json+=",";

      json+=CreateTradeObjectJson((string)positionID,symbol,order_units,order_open_price,order_close_price,profit,type,order_sl,order_tp,
                                  open_time,close_time,commision,swap,0);
     }

   json+="] }";

   if(firstRun)
      Print("Send the full history ("+x+" trades) to the database");

   if(x==0)
      return("");

   return(json);
  }
//+------------------------------------------------------------------+
