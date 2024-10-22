
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>

CTrade negocio;
CSymbolInfo simbolo;
CPositionInfo posicao;

int _volume = 1;
int _take_profit = 200;
int _stop_loss = 100;

int _break_even = 100;
int _trailing = 80;
int _tx_trailing = 10;

int contador = 0;

ENUM_TIMEFRAMES _tempo_grafico = PERIOD_M5;

int primeira_vez = 0;
double priceCurrent, priceOpen, take, stop, priceOpenY = 0.0;
MqlRates rates[], rates_dia[];
datetime candle_atual, candle_novo, candle_atual_dia, candle_novo_dia;

int OnInit() {
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   negocio.SetExpertMagicNumber(MathRand());
   simbolo.Name(_Symbol);
   
   ArraySetAsSeries(rates, true);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   Comment("");
}

void OnTick() {

   CopyRates(_Symbol, _tempo_grafico, 0, 4, rates);
   simbolo.Refresh();
   simbolo.RefreshRates();

   candle_atual = rates[0].time;

   if(posicao.Select(_Symbol)){
   
      candle_novo = candle_atual;
      if(posicao.PositionType() == POSITION_TYPE_BUY) ModificarCompra();
      else if(posicao.PositionType() == POSITION_TYPE_SELL) ModificarVenda();
   } else {
      
      if(candle_atual != candle_novo){
         
         priceOpen = simbolo.Ask();
         
         double rannd = MathRand() - MathRand();
         
         // COMPRA
         if(rannd > 0){
            
            stop = NormalizeDouble(priceOpen - _stop_loss, _Digits);
            take = NormalizeDouble(priceOpen + _take_profit, _Digits);
            
            if(negocio.Buy(_volume, _Symbol, priceOpen, stop, take, "Comprado!")){
               primeira_vez = 1;
            }
            
            candle_novo = candle_atual;
            contador++;
            Comment("Trades: ", contador);
         }
         // VENDA
         else if(rannd < 0){

            stop = NormalizeDouble(priceOpen + _stop_loss, _Digits);
            take = NormalizeDouble(priceOpen - _take_profit, _Digits);
            
            if(negocio.Sell(_volume, _Symbol, priceOpen, stop, take, "Vendido!")){
               primeira_vez = 1;
            }
            
            candle_novo = candle_atual;
            contador++;
            Comment("Trades: ", contador);
         }
      }
   }
}

void ModificarCompra(){
   
   simbolo.Refresh();
   simbolo.RefreshRates();
   
   priceCurrent = posicao.PriceCurrent();
   priceOpen = posicao.PriceOpen();
   take = posicao.TakeProfit();
   stop = posicao.StopLoss();
   
   if(primeira_vez == 1){
      priceOpenY = priceOpen;
      primeira_vez = 0;
   }

   // BreakEven
   if(stop < priceOpen){
      if(priceCurrent > priceOpenY + _break_even){
         priceOpenY += _break_even;
         negocio.PositionModify(posicao.Ticket(), priceOpen, take);
      }
   }
   // Trailing Stop
   else if(priceCurrent > priceOpenY + _tx_trailing){
      priceOpenY += _tx_trailing;
      if(stop < priceCurrent - _trailing){
         negocio.PositionModify(posicao.Ticket(), NormalizeDouble(priceCurrent - _trailing, _Digits), take);
      }
   }
}

void ModificarVenda(){

   simbolo.Refresh();
   simbolo.RefreshRates();

   priceCurrent = posicao.PriceCurrent();
   priceOpen = posicao.PriceOpen();
   take = posicao.TakeProfit();
   stop = posicao.StopLoss();

   if(primeira_vez == 1){
      priceOpenY = priceOpen;
      primeira_vez = 0;
   }
   
   // BreakEven
   if(stop > priceOpen){
      if(priceCurrent < priceOpenY - _break_even){
         priceOpenY -= _break_even;
         negocio.PositionModify(posicao.Ticket(), priceOpen, take);
      }
   }
   // Trailing Stop
   else if(priceCurrent < priceOpenY - _tx_trailing){
      priceOpenY -= _tx_trailing;
      if(stop > priceCurrent + _trailing){
         negocio.PositionModify(posicao.Ticket(), NormalizeDouble(priceCurrent + _trailing, _Digits), take);
      }
   }
}