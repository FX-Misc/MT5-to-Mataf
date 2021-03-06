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
#define   VERSION   "1.05"
#define   SOURCE    "MT5"

#property copyright "Mataf.net"
#property link      "https://www.mataf.net"
#property version   VERSION
#include "JAson.mqh"
#include "Account.mqh"
#include "Connect.mqh"
#include "OpenOrder.mqh"
#include "Trade.mqh"
#include <Trade\SymbolInfo.mqh>; CSymbolInfo mysymbol;

//--- input parameters
input string email            = "";                     // Email
input string password         = "";                     // Password
input string AccountAlias     = "Account MT5";          // Alias
input string url              = "https://www.mataf.io"; // URL
input int    updateFrequency  = 60;                     // Update Interval(in seconds)
input int    api_call_timeout = 60000;                  // Time out

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double   api_version       = (double)VERSION;
string   token             = "";
int      id_user           = 0;
int      AccountID         = 0;
bool     previous_finished = true;
int      globalCounter     = 0;
bool     firstRun          = true;
bool     connected         = false;
CJAVal   balanceHistory(NULL,jtUNDEF);
//+------------------------------------------------------------------+
//| File Type                                                        |
//+------------------------------------------------------------------+
enum ENUM_FILE_TYPE
  {
   TOKEN,
   USER_ID,
   ACCOUNT_ID
  };
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
   if(!GetToken())
     {
      //---trying again with a fresh token
      Comment("Connection to Mataf failed... Try again...");
      if(!GetToken())
        {
         Comment("Connection to Mataf Failed!");
         return(INIT_FAILED);
         connected = false;
        }
     }

   Comment("Connected to Mataf!...");
   OnTickSimulated();
   connected = true;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Send request at given frequency                                  |
//+------------------------------------------------------------------+
void OnTickSimulated()
  {
   bool success     = true;

   previous_finished = false;

   string comment="Connect to Mataf";
   Comment(comment);
   CreateAccount();

   comment += ", Send Open Orders data";
   Comment(comment);
   if(!UpdateOrderList())
     {
      comment += " (fail), Send again";
      Comment(comment);
      Sleep(10);
      if(!UpdateOrderList())
        {
         success = false;
         comment += " (fail)";
         Comment(comment);
        }
      else
        {
         comment += " (success)";
         Comment(comment);
        }
     }
   else
     {
      comment += " (success)";
      Comment(comment);
     }
   comment += ", Send Trades data";
   Comment(comment);

   if(!UpdateTradesList())
     {
      comment += " (fail), Send again";
      Comment(comment);
      Sleep(10);
      if(!UpdateTradesList())
        {
         success = false;
         comment += " (fail)";
         Comment(comment);
        }
      else
        {
         comment += " (success)";
         Comment(comment);
        }
     }
   else
     {
      comment += " (success)";
      Comment(comment);
     }
   comment += ", End";
   Comment(comment);

   if(success)
      firstRun = false;

   previous_finished=true;
  }
//+------------------------------------------------------------------+
//| Get the current time stamp                                       |
//+------------------------------------------------------------------+
datetime GetLastActiveTimeStamp()
  {

   return(0);
  }

//+------------------------------------------------------------------+
//| Convert the date to GMT                                          |
//+------------------------------------------------------------------+
string dateToGMT(datetime dateToConvert)
  {
   float GMTOffset = (float)(TimeGMT() - TimeCurrent());
   return dateToConvert>0? displayDate((datetime)(dateToConvert + GMTOffset)):(string)0;
  }

//+------------------------------------------------------------------+
//| Display a date with the correct format                           |
//+------------------------------------------------------------------+
string displayDate(datetime dateToDisplay)
  {
   string date = dateToDisplay>0 ? TimeToString(dateToDisplay,TIME_SECONDS|TIME_DATE) : (string)0;
   StringReplace(date,".","-");
   return date;
  }
//+------------------------------------------------------------------+
