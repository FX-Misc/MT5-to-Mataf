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
#property version   "1.02"
#include "JAson.mqh"
#include <Trade\SymbolInfo.mqh>; CSymbolInfo mysymbol;

//--- input parameters
input int         updateFrequency = 5;                        // Update Interval(in seconds)
input string      email="";                                   // Email
input string      password="";                                // Password
input string      AccountAlias="Test Account MT5";            // Alias

string   url               = "https://www.mataf.io";          // URL
int      api_call_timeout  = 60000;                           // Time out
int      api_version       = 1;
string   token             = "";
int      id_user;
int      AccountID;
bool     previous_finished = true;

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
   Comment("Connect to Mataf...");
   GetToken();
   if(!CreateAccount())
     {
      //---trying again with a fresh token
      Comment("Connection to Mataf failed... Try again...");
      GetToken();
      if(!CreateAccount())
        {
         Comment("Connection to Mataf Failed!");
         return(INIT_FAILED);
        }
     }
   else
      Comment("Connected to Mataf!...");

   previous_finished=false;
   Comment("Connected to Mataf, Send trades data...");
   UpdateTradesList(true);
   Comment("Connected to Mataf, Send orders data...");
   UpdateOrderList();
   previous_finished=true;
   Comment("Data sent to Mataf...");
   Sleep(500);
   connected=true;
   Comment("");
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
//| Get new token                                                    |
//+------------------------------------------------------------------+
bool GetToken()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/user/login";
   string headers = "Content-Type: application/json\r\n X-Mataf-api-version: 1\r\n";
   char data[];
   string str;

   parser["email"]=email;
   parser["password"]=password;
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
//| Create new account/update existing                               |
//+------------------------------------------------------------------+
bool CreateAccount(const bool firstRun=true)
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/trading/accounts";
   string headers = StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1",token,id_user);

   char   data[];
   string str = "";
   string created_time = "";
   int    counter = 0;

   double total_deposits = 0, total_withdraw = 0;
   CJAVal acountdepositsObject(NULL,jtUNDEF);

   HistorySelect(0,TimeCurrent());

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

         if(amount>0)
            total_deposits+=amount;
         else
            total_withdraw+=MathAbs(amount);

         acountdepositsObject[counter++] = CreateAccountTransactionJson(type,amount,date,(int)dealTicket,dealComment);
        }
     }
   bool IsDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);

   parser["version"]                          = api_version;
   parser["data"]["account_id_from_provider"] = string(AccountInfoInteger(ACCOUNT_LOGIN));
   parser["data"]["provider_name"]            = AccountInfoString(ACCOUNT_COMPANY);
   parser["data"]["source_name"]              = "MT5";
   parser["data"]["user_id_from_provider"]    = string(AccountInfoInteger(ACCOUNT_LOGIN));
   parser["data"]["account_alias"]            = AccountAlias;
   parser["data"]["account_name"]             = AccountInfoString(ACCOUNT_NAME);
   parser["data"]["currency"]                 = AccountInfoString(ACCOUNT_CURRENCY);
   parser["data"]["is_live"]                  = !IsDemo;
   parser["data"]["is_active"]                = true;
   parser["data"]["balance"]                  = (float)AccountInfoDouble(ACCOUNT_BALANCE);
   parser["data"]["profit_loss"]              = AccountInfoDouble(ACCOUNT_BALANCE) - (total_deposits - total_withdraw);
   parser["data"]["open_profit_loss"]         = AccountInfoDouble(ACCOUNT_PROFIT);
   parser["data"]["funds"]["deposit"]         = total_deposits;
   parser["data"]["funds"]["withdraw"]        = -1*total_withdraw;
   parser["data"]["history"]                  = acountdepositsObject;
   parser["data"]["created_at_from_provider"] = created_time;

   parser.Serialize(str);

   ArrayResize(data,StringToCharArray(str,data,0,-1,CP_UTF8)-1);
   ResetLastError();
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Connecting to Mataf: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         return(false);
        }
      else
        {
         AccountID=(int)parser["data"]["id"].ToInt();
         if(firstRun)
            PrintFormat("Connected to Mataf, Account ID: %d",AccountID);
        }
     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Update Order List                                                |
//+------------------------------------------------------------------+
bool UpdateOrderList()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/trading/accounts/"+(string)AccountID+"/orders";
   string headers = StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1\r\n X-HTTP-Method-Override: PUT",token,id_user);
   string str;
   char   data[];

   parser = CreateOpenedOrderListJson();
   parser.Serialize(str);

   ArrayResize(data,StringToCharArray(str,data,0,-1,CP_UTF8)-1);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Updating Order List: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         return(false);
        }
     }
   else
     {
      Print("["+__FUNCTION__+"] Failed to Deserialize");
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Update Trades List                                                |
//+------------------------------------------------------------------+
bool UpdateTradesList(const bool firstRun=false)
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/trading/accounts/"+IntegerToString(AccountID)+"/trades";
   string headers= StringFormat("Content-Type: application/json\r\n X-Mataf-token: %s\r\n X-Mataf-id: %d\r\n X-Mataf-api-version: 1\r\n X-HTTP-Method-Override: PUT",token,id_user);
   char data[];
   string str;

   parser = CreateTradesListJson(firstRun);

   if(!firstRun && parser["data"].Size()==0)
      return(true);

   parser.Serialize(str);

   ArrayResize(data,StringToCharArray(str,data,0,-1,CP_UTF8)-1);
   int result=WebRequest("POST",fullUrl,headers,api_call_timeout,data,data,headers);

   int error=GetLastError();

   if(parser.Deserialize(data))
     {
      if(parser["is_error"].ToBool())
        {
         PrintFormat("Error When Updating Trades List: %s [ status code: %d ] ",parser["status"].ToStr(),parser["status_code"].ToInt());
         return(false);
        }
     }
   else
     {
      Print("Failed to Deserialize");
      return(false);
     }

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
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
CJAVal CreateAccountTransactionJson(const string method,const double amount,const datetime time,const int id,const string comment)
  {
   CJAVal parser(NULL,jtUNDEF);
   parser["type"] = method;
   parser["amount"] = amount;
   parser["time"] = TimeToString(time,TIME_SECONDS|TIME_DATE);
   parser["transaction_id_from_provider"] = (string)id;
   parser["comment"] = comment;

   return(parser);
  }
//+------------------------------------------------------------------+
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
CJAVal CreateOrderObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const ENUM_ORDER_TYPE order_type,const double sl_level,
                             const double tp_level,const datetime expiry,const datetime open_time,const datetime closed_time)
  {
   CJAVal   parser(NULL,jtUNDEF);
   string dir="SELL",type="LIMIT";

   if(order_type==ORDER_TYPE_BUY|| order_type==ORDER_TYPE_BUY_STOP|| order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP_LIMIT)
      dir="BUY";
   if(order_type== ORDER_TYPE_BUY_LIMIT|| order_type == ORDER_TYPE_SELL_LIMIT)
      type="LIMIT";
   else
      if(order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_SELL_STOP)
         type="STOP";

   mysymbol.Name(symbol);
   string currency = mysymbol.CurrencyBase();
   
   parser["order_id_from_provider"]       = order_id;
   parser["account_id"]                   = AccountID;
   parser["trade_id"]                     = "";
   parser["trade_id_from_provider"]       = order_id;
   parser["instrument_id_from_provider"]  = symbol;
   parser["units"]                        = lotsize;
   parser["currency"]                     = currency;
   parser["price"]                        = open_price;
   parser["execution_price"]              = open_price;
   parser["direction"]                    = dir;
   parser["stop_loss"]                    = sl_level;
   parser["take_profit"]                  = tp_level;
   parser["trailing_stop"]                = 0;
   parser["stop_loss_distance"]           = 0;
   parser["take_profit_distance"]         = 0;
   parser["trailing_stop_distance"]       = 0;
   parser["order_type"]                   = type;
   parser["status"]                       = order_type>ORDER_TYPE_SELL?"PENDING":"FILLED";
   parser["expire_at"]                    = expiry>0?TimeToString(expiry,TIME_SECONDS|TIME_DATE):(string)0;
   parser["created_at_from_provider"]     = open_time>0?TimeToString(open_time,TIME_SECONDS|TIME_DATE):(string)0;
   parser["closed_at_from_provider"]      = closed_time>0?TimeToString(closed_time,TIME_SECONDS|TIME_DATE):(string)0;

   return(parser);

  }
//+------------------------------------------------------------------+
//| Create a trade object in JSON                                    |
//+------------------------------------------------------------------+
CJAVal CreateTradeObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const double closed_price,const double PnL,const ENUM_ORDER_TYPE order_type,const double sl_level,
                             const double tp_level,const datetime open_time,const datetime closed_time,const double commission,const double rollover,const double other_fees
                            )
  {
   CJAVal parser(NULL,jtUNDEF);
   double spread_cost=SymbolInfoInteger(symbol,SYMBOL_SPREAD)*SymbolInfoDouble(symbol,SYMBOL_POINT)*SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE)*lotsize;
   string dir="SELL";
   string type="";

   if(order_type==ORDER_TYPE_BUY || order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP_LIMIT)
      dir="BUY";
   if(order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_SELL_LIMIT)
      type="LIMIT";
   else
      if(order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_SELL_STOP)
         type="STOP";

   mysymbol.Name(symbol);
   string currency = mysymbol.CurrencyBase();

   parser["trade_id_from_provider"]       = order_id;
   parser["account_id"]                   = AccountID;
   parser["instrument_id_from_provider"]  = symbol;
   parser["direction"]                    = dir;
   parser["type"]                         = order_type<=ORDER_TYPE_SELL?"MARKET":type;
   parser["units"]                        = lotsize;
   parser["currency"]                     = currency;
   parser["open_price"]                   = open_price;
   parser["closed_price"]                 = closed_time>0?closed_price:0;
   parser["profit_loss"]                  = closed_time>0?PnL:0.0;
   parser["open_profit_loss"]             = closed_time>0?0:PnL;
   parser["rollover"]                     = rollover;
   parser["commission"]                   = commission;
   parser["other_fees"]                   = other_fees;
   parser["spread_cost"]                  = spread_cost;
   parser["status"]                       = closed_time>0?(order_type>ORDER_TYPE_SELL?"CANCELLED":"CLOSED"):"OPEN";
   parser["balance_at_opening"]           = AccountInfoDouble(ACCOUNT_BALANCE)-PnL;
   parser["stop_loss"]                    = sl_level;
   parser["take_profit"]                  = tp_level;
   parser["trailing_stop"]                = 0;
   parser["stop_loss_distance"]           = 0;
   parser["take_profit_distance"]         = 0;
   parser["trailing_stop_distance"]       = 0;
   parser["created_at_from_provider"]     = open_time>0?TimeToString(open_time,TIME_SECONDS|TIME_DATE):(string)0;
   parser["closed_at_from_provider"]      = closed_time>0?TimeToString(closed_time,TIME_SECONDS|TIME_DATE):(string)0;

   return(parser);
  }
//+------------------------------------------------------------------+
//| Create currently opened order list                               |
//+------------------------------------------------------------------+
CJAVal CreateOpenedOrderListJson()
  {
   CJAVal   parser(NULL,jtUNDEF);
   int      j=0;
   string   symbol;
   double   profit=0, order_lots=0, order_units=0, order_open_price=0, order_sl=0, order_tp=0;
   datetime expiration=0,open_time=0,close_time=0;
   ENUM_ORDER_TYPE type;

   parser["version"]                 = api_version;
   parser["delete_data_not_in_list"] = true;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket>0)
        {
         type              = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         symbol            = OrderGetString(ORDER_SYMBOL);
         order_lots        = OrderGetDouble(ORDER_VOLUME_INITIAL);
         order_units       = order_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
         order_open_price  = OrderGetDouble(ORDER_PRICE_OPEN);
         order_sl          = OrderGetDouble(ORDER_SL);
         order_tp          = OrderGetDouble(ORDER_TP);
         expiration        = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         open_time         = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         close_time        = 0;
         string id         = IntegerToString(OrderGetInteger(ORDER_POSITION_ID));

         parser["data"][j++] = CreateOrderObjectJson((string)id,symbol,order_units,order_open_price,type,order_sl,order_tp,expiration,open_time,close_time);
        }
     }

   if(j==0)
      parser["data"] = "";

   return(parser);
  }
//+------------------------------------------------------------------+
//| Create currently opened and closed trade list                    |
//+------------------------------------------------------------------+
CJAVal CreateTradesListJson(const bool firstRun)
  {
   CJAVal parser(NULL,jtUNDEF);

   parser["version"]                 = api_version;
   parser["delete_data_not_in_list"] = firstRun;

// Opened positions
   int    j=0;
   string symbol;
   double profit=0,position_lots=0,position_units=0,position_open_price=0,position_sl=0,position_tp=0;
   datetime expiration=0,open_time=0,close_time=0;
   double commision=0,swap=0;

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0)
        {
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         profit                  = PositionGetDouble(POSITION_PROFIT);
         symbol                  = PositionGetString(POSITION_SYMBOL);
         position_lots           = PositionGetDouble(POSITION_VOLUME);
         position_units          = position_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
         position_open_price     = PositionGetDouble(POSITION_PRICE_OPEN);
         position_sl             = PositionGetDouble(POSITION_SL);
         position_tp             = PositionGetDouble(POSITION_TP);
         swap                    = PositionGetDouble(POSITION_SWAP);
         expiration              = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         open_time               = (datetime)PositionGetInteger(POSITION_TIME);
         close_time              = 0;
         commision               = 0;
         if(PositionSelectByTicket(ticket))
           {
            for(int k=0; k<HistoryDealsTotal(); k++)
              {
               ulong dealTicket  = HistoryDealGetTicket(k);
               commision        += HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
              }
           }

         parser["data"][j++] = CreateTradeObjectJson((string)ticket,symbol,position_units,position_open_price,SymbolInfoDouble(symbol,(type==POSITION_TYPE_BUY?SYMBOL_BID:SYMBOL_ASK)),
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

      ulong ticket      = HistoryOrderGetTicket(i);
      long positionID   = HistoryOrderGetInteger(ticket,ORDER_POSITION_ID);
      if(positionID==ticket)
         continue;
      symbol            = HistoryOrderGetString(ticket,ORDER_SYMBOL);
      order_lots        = HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);
      order_units       = order_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      order_open_price  = HistoryOrderGetDouble(positionID,ORDER_PRICE_OPEN);
      order_sl          = HistoryOrderGetDouble(positionID, ORDER_SL);
      order_tp          = HistoryOrderGetDouble(positionID, ORDER_TP);
      profit            = 0;
      open_time         = (datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP);
      close_time        = (datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_DONE);
      datetime today    = StringToTime(TimeToString(TimeCurrent(),TIME_DATE|TIME_DATE));

      if(firstRun || close_time<today)
        {
         swap=0;
         commision=0;
         if(HistorySelectByPosition(positionID))
           {
            for(int k=0; k<HistoryDealsTotal(); k++)
              {
               ulong dealTicket  = HistoryDealGetTicket(k);
               swap             += HistoryDealGetDouble(dealTicket,DEAL_SWAP);
               commision        += HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);

               if(HistoryDealGetInteger(dealTicket,DEAL_ENTRY)==DEAL_ENTRY_IN)
                 {
                  type              = (ENUM_ORDER_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
                  order_open_price  = HistoryDealGetDouble(dealTicket,DEAL_PRICE);
                 }
               else
                  if(HistoryDealGetInteger(dealTicket,DEAL_ENTRY)==DEAL_ENTRY_OUT)
                    {
                     profit           += HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
                     order_close_price = HistoryDealGetDouble(dealTicket,DEAL_PRICE);
                    }
              }
           }

         parser["data"][j++] = CreateTradeObjectJson((string)positionID,symbol,order_units,order_open_price,order_close_price,profit,type,order_sl,order_tp,
                               open_time,close_time,commision,swap,0);
        }
     }

   if(j==0)
      parser["data"] = "";

   return(parser);
  }
//+------------------------------------------------------------------+
