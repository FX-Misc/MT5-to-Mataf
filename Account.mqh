//+------------------------------------------------------------------+
//|                                                      Account.mqh |
//|                                                    Arnaud Jeulin |
//|                                            https://www.mataf.net |
//+------------------------------------------------------------------+
#property copyright "Arnaud Jeulin"
#property link      "https://www.mataf.net"

#include "MT5-to-mataf.mq5"
#include "JAson.mqh"

//+------------------------------------------------------------------+
//| Create new account/update existing                               |
//+------------------------------------------------------------------+
bool CreateAccount()
  {
   CJAVal parser(NULL,jtUNDEF);
   string fullUrl = url+"/api/trading/accounts";
   string headers = getHeaders(H_POST);

   char   data[];
   string str    = "";
   bool   IsDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);

   parser["version"]                          = api_version;
   parser["source"]                           = SOURCE;
   parser["date"]                             = dateToGMT(TimeCurrent());

   parser["data"]["account_id_from_provider"] = string(AccountInfoInteger(ACCOUNT_LOGIN));
   parser["data"]["provider_name"]            = AccountInfoString(ACCOUNT_COMPANY);
   parser["data"]["source_name"]              = SOURCE;
   parser["data"]["user_id_from_provider"]    = string(AccountInfoInteger(ACCOUNT_LOGIN));
   parser["data"]["account_alias"]            = AccountAlias;
   parser["data"]["account_name"]             = AccountInfoString(ACCOUNT_NAME);
   parser["data"]["currency"]                 = AccountInfoString(ACCOUNT_CURRENCY);
   parser["data"]["is_live"]                  = !IsDemo;
   parser["data"]["is_active"]                = true;
   parser["data"]["balance"]                  = (float)AccountInfoDouble(ACCOUNT_BALANCE);
   parser["data"]["balance_history"][0]       = 0; //calulated in updateBalanceHistory
   parser["data"]["profit_loss"]              = 0; //calulated in updateBalanceHistory
   parser["data"]["open_profit_loss"]         = AccountInfoDouble(ACCOUNT_PROFIT);
   parser["data"]["funds"]["deposit"]         = 0; //calulated in updateBalanceHistory
   parser["data"]["funds"]["withdraw"]        = 0; //calulated in updateBalanceHistory
   parser["data"]["funds"]["history"][0]      = 0; //calulated in updateBalanceHistory
   parser["data"]["created_at_from_provider"] = 0; //calulated in updateBalanceHistory

   updateBalanceHistory(parser);

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
//| Create Withdrawing and Depositing JSON Data Object               |
//+------------------------------------------------------------------+
CJAVal CreateAccountTransactionJson(const string method,const double amount,const datetime time,const int id,const string comment)
  {
   CJAVal parser(NULL,jtUNDEF);
   parser["type"] = method;
   parser["amount"] = amount;
   parser["time"] = dateToGMT(time);
   parser["transaction_id_from_provider"] = (string)id;
   parser["comment"] = comment;

   return(parser);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void updateBalanceHistory(CJAVal &account)
  {

   int      j       = 0;
   int      k       = 0;
   int      l       = 0;
   ulong    ticket  = 0;   // Deal ticket
   double   balance = 0.0; // Balance
   double   swap, commission, profit, variation, amount, total_deposits=0, total_withdraw=0;
   datetime date;
   string   type, dealComment, created_time="";

   HistorySelect(0,TimeCurrent());
   for(int i=0; i<HistoryDealsTotal(); i++)
     {
      ticket=HistoryDealGetTicket(i);

      profit     = HistoryDealGetDouble(ticket,DEAL_PROFIT);
      swap       = HistoryDealGetDouble(ticket,DEAL_SWAP);
      commission = HistoryDealGetDouble(ticket,DEAL_COMMISSION);

      variation = profit + swap + commission;

      if(variation!=0)
        {
         balance   += variation;

         //--- Get all the deal properties
         balanceHistory[l]["time"]                         = dateToGMT((datetime)HistoryDealGetInteger(ticket,DEAL_TIME));
         balanceHistory[l]["balance"]                      = balance;
         balanceHistory[l]["balance"]                      = balance;
         balanceHistory[l]["transaction_id_from_provider"] = (int)ticket;
         balanceHistory[l]["comment"]                      = HistoryDealGetString(ticket,DEAL_SYMBOL) + HistoryDealGetString(ticket,DEAL_COMMENT);


         account["data"]["balance_history"][j++] = balanceHistory[l++];

         if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BALANCE || HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BONUS || HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_CREDIT)
           {
            //-- Withdraw Or Deposit
            date        = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            amount      = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            type        = (HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BALANCE  ?(amount>0?"DEPOSIT":"WITHDRAWAL"): "CREDIT/BONUS");
            dealComment = HistoryDealGetString(ticket,DEAL_COMMENT);

            if(created_time=="")
               created_time = dateToGMT(date);

            if(amount>0)
               total_deposits += amount;
            else
               total_withdraw += MathAbs(amount);

            account["data"]["funds"]["history"][k++] = CreateAccountTransactionJson(type,amount,date,(int)ticket,dealComment);
           }

        }
     }
   account["data"]["created_at_from_provider"] = created_time;
   account["data"]["profit_loss"]              = AccountInfoDouble(ACCOUNT_BALANCE) - (total_deposits - total_withdraw);
   account["data"]["funds"]["deposit"]         = total_deposits;
   account["data"]["funds"]["withdraw"]        = -1*total_withdraw;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double balanceSearch(string date)
  {
   int i;
   for(i=0; i<balanceHistory.Size(); i++)
     {
      if(balanceHistory[i]["time"].ToStr()>date)
         break;
     }
   return balanceHistory[i-1]["balance"].ToDbl();
  }

//+------------------------------------------------------------------+
