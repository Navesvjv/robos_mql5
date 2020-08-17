
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>

CTrade negocio;
CSymbolInfo simbolo;
CPositionInfo posicao;

int _volume = 1;
int _take_profit = 50;
int _stop_loss = 100;

int contador = 0;

ENUM_TIMEFRAMES _tempo_grafico = PERIOD_M2;

double priceCurrent, priceOpen, take, stop;
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
   ChartIndicatorDelete(0, 1, nh_macd);
}

void OnTick() {

   CopyRates(_Symbol, _tempo_grafico, 0, 4, rates);
   simbolo.Refresh();
   simbolo.RefreshRates();

   candle_atual = rates[0].time;

   if(posicao.Select(_Symbol)){
   
      candle_novo = candle_atual;
      //if(posicao.PositionType() == POSITION_TYPE_BUY) ModificarCompra();
      //else if(posicao.PositionType() == POSITION_TYPE_SELL) ModificarVenda();
   } else {
      
      if(candle_atual != candle_novo){
         
         priceOpen = simbolo.Ask();
         
         // COMPRA
         if(macd[1] < macd[0] && macd[0] < 0 && MathAbs(macd[0]) > 50){
            
            stop = NormalizeDouble(priceOpen - _stop_loss, _Digits);
            take = NormalizeDouble(priceOpen + _take_profit, _Digits);
            
            negocio.Buy(_volume, _Symbol, priceOpen, stop, take, "Comprado!");
            
            candle_novo = candle_atual;
            contador++;
            Comment("Trades: ", contador);
         }
         // VENDA
         else if(macd[1] > macd[0] && macd[0] > 0 && MathAbs(macd[0]) > 50){

            stop = NormalizeDouble(priceOpen + _stop_loss, _Digits);
            take = NormalizeDouble(priceOpen - _take_profit, _Digits);
            
            negocio.Sell(_volume, _Symbol, priceOpen, stop, take, "Vendido!");
            
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
   
   // BreakEven
   if(stop < priceOpen){
      if(priceCurrent > priceOpen + _break_even){
         negocio.PositionModify(posicao.Ticket(), priceOpen + 10, take);
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

   // BreakEven
   if(stop > priceOpen){
      if(priceCurrent < priceOpen - _break_even){
         negocio.PositionModify(posicao.Ticket(), priceOpen - 10, take);
      }
   }
}
