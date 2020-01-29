//+------------------------------------------------------------------+
//|                                                    OpenOrder.mqh |
//|                                                    Arnaud Jeulin |
//|                                            https://www.mataf.net |
//+------------------------------------------------------------------+
#property copyright "Arnaud Jeulin"
#property link      "https://www.mataf.net"

#include "MT5-to-mataf.mq5"
#include "JAson.mqh"

//+------------------------------------------------------------------+
//| Update Order List                                                |
//+------------------------------------------------------------------+
bool UpdateOrderList()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/trading/accounts/"+(string)AccountID+"/orders";
   string headers = getHeaders(H_PUT);
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
   parser["source"]                  = SOURCE;
   parser["delete_data_not_in_list"] = true;
   parser["date"]                    = dateToGMT(TimeCurrent());

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
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
CJAVal CreateOrderObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const ENUM_ORDER_TYPE order_type,const double sl_level,
                             const double tp_level,const datetime expiry,const datetime open_time,const datetime close_time)
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
   parser["expire_at"]                    = dateToGMT(expiry);
   parser["created_at_from_provider"]     = dateToGMT(open_time);
   parser["closed_at_from_provider"]      = dateToGMT(close_time);

   return(parser);

  }
//+------------------------------------------------------------------+
