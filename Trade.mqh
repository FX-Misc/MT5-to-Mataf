//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                                                    Arnaud Jeulin |
//|                                            https://www.mataf.net |
//+------------------------------------------------------------------+
#property copyright "Arnaud Jeulin"
#property link      "https://www.mataf.net"

#include "MT5-to-mataf.mq5"
#include "JAson.mqh"

//+------------------------------------------------------------------+
//| Update Trades List                                                |
//+------------------------------------------------------------------+
bool UpdateTradesList()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl=url+"/api/trading/accounts/"+IntegerToString(AccountID)+"/trades";
   string headers = getHeaders(H_PUT);
   char data[];
   string str;

   parser = CreateTradesListJson();

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
//| Create a trade object in JSON                                    |
//+------------------------------------------------------------------+
CJAVal CreateTradeObjectJson(const string order_id,const string symbol,const double lotsize,
                             const double open_price,const double closed_price,
                             const double PnL,const ENUM_ORDER_TYPE order_type,
                             const double sl_level, const double tp_level,
                             const datetime open_time,const datetime close_time,
                             const double commission,const double rollover,const double other_fees
                            )
  {
   CJAVal parser(NULL,jtUNDEF);
   double spread_cost=SymbolInfoInteger(symbol,SYMBOL_SPREAD)*SymbolInfoDouble(symbol,SYMBOL_POINT)*SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE)*lotsize;
   string dir="SELL";
   string type="";
   string status = close_time>0?(order_type>ORDER_TYPE_SELL?"CANCELLED":"CLOSED"):"OPEN";

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
   parser["closed_price"]                 = close_time>0?closed_price:0;
   parser["profit_loss"]                  = close_time>0?PnL:0.0;
   parser["open_profit_loss"]             = close_time>0?0:PnL;
   parser["rollover"]                     = rollover;
   parser["commission"]                   = commission;
   parser["other_fees"]                   = other_fees;
   parser["spread_cost"]                  = spread_cost;
   parser["status"]                       = status;
   parser["balance_at_opening"]           = balanceSearch(dateToGMT(open_time)); //AccountInfoDouble(ACCOUNT_BALANCE)-PnL;
   parser["stop_loss"]                    = sl_level;
   parser["take_profit"]                  = tp_level;
   parser["trailing_stop"]                = 0;
   parser["stop_loss_distance"]           = 0;
   parser["take_profit_distance"]         = 0;
   parser["trailing_stop_distance"]       = 0;
   parser["created_at_from_provider"]     = dateToGMT(open_time);
   parser["closed_at_from_provider"]      = dateToGMT(close_time);
   parser["current_time"]                 = dateToGMT(TimeCurrent());

   return(parser);
  }

//+------------------------------------------------------------------+
//| Create currently opened and closed trade list                    |
//+------------------------------------------------------------------+
CJAVal CreateTradesListJson()
  {
   CJAVal parser(NULL,jtUNDEF);

   parser["version"]                 = api_version;
   parser["source"]                  = SOURCE;
   parser["delete_data_not_in_list"] = firstRun;
   parser["date"]                    = dateToGMT(TimeCurrent());

// ======= Opened positions ===========
   int    j=0;
   string symbol;
   double profit=0,position_lots=0,position_units=0,position_open_price=0,position_sl=0,position_tp=0;
   datetime expiration=0,open_time=0,close_time=0, modified_time=0, latest_time=0, first_time=0;
   double commision=0,swap=0;

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      //Print(ticket);
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
               //Print(HistoryDealGetInteger(dealTicket,DEAL_TIME));
               //Print(TimeToString(HistoryDealGetInteger(dealTicket,DEAL_TIME),TIME_SECONDS|TIME_DATE));
              }
           }

         parser["data"][j++] = CreateTradeObjectJson((string)ticket,symbol,position_units,position_open_price,SymbolInfoDouble(symbol,(type==POSITION_TYPE_BUY?SYMBOL_BID:SYMBOL_ASK)),
                               profit,(ENUM_ORDER_TYPE)type,position_sl,position_tp,
                               open_time,close_time,commision,swap,0);
        }
     }

// ======= Closed positions ===========
   double order_lots=0,order_units=0,order_open_price=0,order_close_price=0,order_sl=0,order_tp=0;
   ENUM_ORDER_TYPE type=0;
   HistorySelect(0,TimeCurrent());
   for(int i=HistoryOrdersTotal()-1; i>=0; i--)
     {
      HistorySelect(0,TimeCurrent());

      ulong ticket       = HistoryOrderGetTicket(i);
      long positionID    = HistoryOrderGetInteger(ticket,ORDER_POSITION_ID);
      if(positionID==ticket)
         continue;
      symbol             = HistoryOrderGetString(ticket,ORDER_SYMBOL);
      order_lots         = HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);
      order_units        = order_lots*SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      order_open_price   = HistoryOrderGetDouble(positionID,ORDER_PRICE_OPEN);
      order_sl           = HistoryOrderGetDouble(positionID, ORDER_SL);
      order_tp           = HistoryOrderGetDouble(positionID, ORDER_TP);
      profit             = 0;

      swap               = 0;
      commision          = 0;
      if(HistorySelectByPosition(positionID))
        {
         latest_time = 0;
         first_time  = 0;
         for(int k=0; k<HistoryDealsTotal(); k++)
           {
            ulong dealTicket  = HistoryDealGetTicket(k);
            swap             += HistoryDealGetDouble(dealTicket,DEAL_SWAP);
            commision        += HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
            first_time        = first_time==0 ? (datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME) : first_time; //we keep the first time of the historyDeal, this is the open_time
            latest_time       = (datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME); // at the end latest_time will be the closed_time
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
      open_time           = first_time;
      close_time          = latest_time;
      datetime yesterday  = TimeCurrent() - (2*60*60);

      if(firstRun || (close_time >= yesterday))
        {
         parser["data"][j++] = CreateTradeObjectJson((string)positionID,symbol,order_units,order_open_price,order_close_price,profit,type,order_sl,order_tp,
                               open_time,close_time,commision,swap,0);
        }
     }

   if(j==0)
      parser["data"] = "";

   return(parser);
  }
//+------------------------------------------------------------------+
