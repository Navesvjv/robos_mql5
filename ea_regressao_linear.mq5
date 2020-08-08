
#include <Global.mqh>
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>

CTrade negocio;
CSymbolInfo simbolo;
CPositionInfo posicao;

int _volume = 1;
int _take_profit = 500;
int _stop_loss = 200;

int _break_even = 200;
//int _tx_break = 20;
int _trailing = 300;
int _tx_trailing = 20;

double _meta_gain = 150;
double _meta_loss = -100;

ENUM_TIMEFRAMES _tempo_grafico = PERIOD_M1;

string inicio = "09:00"; // Horario de inicio (entradas)
string termino = "17:00"; // Horario de Termino (entradas)
string fechamento = "17:30"; // Horario de Fechamento (posições)

MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual;

int h_linear, primeira_vez = 0;
double linear[], linear_c[], priceCurrent, priceOpen, take, stop, priceOpenY = 0;
bool _meta_batida = false;
string nh_linear;
MqlRates rates[], rates_dia[];
datetime candle_atual, candle_novo, candle_atual_dia, candle_novo_dia;

int OnInit() {
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
   negocio.SetExpertMagicNumber(MathRand());
   simbolo.Name(_Symbol);
  
   h_linear = iCustom(_Symbol, _tempo_grafico, "Linear regression");
   if(h_linear == INVALID_HANDLE) return INVALID_HANDLE;
   if(!ChartIndicatorAdd(0, 0, h_linear)) return INIT_FAILED;
   nh_linear = ChartIndicatorName(0, 0, 0);

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(rates_dia, true);
   ArraySetAsSeries(linear, true);
   ArraySetAsSeries(linear_c, true);
   
   TimeToStruct(StringToTime(inicio), horario_inicio);
   TimeToStruct(StringToTime(termino), horario_termino);
   TimeToStruct(StringToTime(fechamento), horario_fechamento);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   Comment("");
   ChartIndicatorDelete(0, 0, nh_linear);
}

void OnTick() {
   CopyRates(_Symbol, PERIOD_D1, 0, 4, rates_dia);
   candle_atual_dia = rates_dia[0].time;
   if(candle_atual_dia != candle_novo_dia){
      _meta_batida = false;
      candle_novo_dia = candle_atual_dia;
   }
   
   CopyRates(_Symbol, _tempo_grafico, 0, 4, rates);
   CopyBuffer(h_linear, 0, 0, 4, linear);
   CopyBuffer(h_linear, 1, 0, 4, linear_c);
   simbolo.Refresh();
   simbolo.RefreshRates();

   if(posicao.Select(_Symbol)){
    
      if(posicao.PositionType() == POSITION_TYPE_BUY){
         SaidaCompra();
         ModificarCompra();
      }
      else if(posicao.PositionType() == POSITION_TYPE_SELL){
         SaidaVenda();
         ModificarVenda(); 
      }
   } else if(HorarioDeEntrada()){
      
      VerificaMeta();
      if(!_meta_batida){
      
         candle_atual = rates[0].time;
         if(candle_atual != candle_novo){
            
            priceOpen = simbolo.Ask();
            
            // COMPRA
            if(linear[2] > linear[1] && linear[1] < linear[0]){
               //ObjectCreate(0, "Compra" + TimeToString(rates[0].time), OBJ_ARROW_BUY, 0, rates[0].time, rates[0].close);
               
               stop = NormalizeDouble(priceOpen - _stop_loss, _Digits);
               take = NormalizeDouble(priceOpen + _take_profit, _Digits);
               
               if(negocio.Buy(_volume, _Symbol, priceOpen, stop, take, "Comprado!")){
                  primeira_vez = 1;
                  priceOpenY = 0.0;
               }
               
               candle_novo = candle_atual;
            }
            // VENDA
            else if(linear[2] < linear[1] && linear[1] > linear[0]){
               //ObjectCreate(0, "Venda" + TimeToString(rates[0].time), OBJ_ARROW_SELL, 0, rates[0].time, rates[0].close);
               
               stop = NormalizeDouble(priceOpen + _stop_loss, _Digits);
               take = NormalizeDouble(priceOpen - _take_profit, _Digits);
               
               if(negocio.Sell(_volume, _Symbol, priceOpen, stop, take, "Vendido!")){
                  primeira_vez = 1;
                  priceOpenY = 0.0;
               }
               
               candle_novo = candle_atual;
            }
         }
      }
   }
   
   if(HorarioDeFechamento()){
      if(PositionSelect(_Symbol)){
         FecharPosicao();
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
   /*
   // BreakEven
   if(stop < priceOpen){
      if(priceCurrent > priceOpenY + _tx_break){
         priceOpenY += _tx_break;
         if(stop < priceCurrent - _break_even){
            negocio.PositionModify(posicao.Ticket(), NormalizeDouble(priceCurrent - _break_even, _Digits), take);
         }
      }
   }*/
   // Trailing Stop
   if(stop < priceOpen){
      if(priceCurrent > priceOpenY + _break_even){
         priceOpenY += _break_even;
         negocio.PositionModify(posicao.Ticket(), priceOpen, take);
      }
   }
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
   /*
   // BreakEven
   if(stop > priceOpen){
      if(priceCurrent < priceOpenY - _tx_break){
         priceOpenY -= _tx_break;
         if(stop > priceCurrent + _break_even){
            negocio.PositionModify(posicao.Ticket(), NormalizeDouble(priceCurrent + _break_even, _Digits), take);
         }
      }
   }*/
   
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

void SaidaCompra(){
   if(linear[2] < linear[1] && linear[1] > linear[0]){
      negocio.PositionClose(posicao.Ticket(), 0);
   }
}

void SaidaVenda(){
   if(linear[2] > linear[1] && linear[1] < linear[0]){
      negocio.PositionClose(posicao.Ticket(), 0);
   }
}

bool HorarioDeEntrada(){
   TimeToStruct(TimeCurrent(), horario_atual);
   if(horario_atual.hour >= horario_inicio.hour && horario_atual.hour <= horario_termino.hour){
      if(horario_atual.hour == horario_inicio.hour){
         if(horario_atual.min >= horario_inicio.min) return true;
         else return false;
      }
      if(horario_atual.hour == horario_termino.hour){
         if(horario_atual.min <= horario_termino.min) return true;
         else return false;
      }
      return true;
   }
   return false;
}

bool HorarioDeFechamento(){
   TimeToStruct(TimeCurrent(), horario_atual);
   if(horario_atual.hour >= horario_fechamento.hour){
      if(horario_atual.hour == horario_fechamento.hour){
         if(horario_atual.min >= horario_fechamento.min) return true;
         else return false;
      }
      return true;
   }
   return false;
}

void FecharPosicao(){
   if(!PositionSelect(_Symbol)) return;
   long tipo = PositionGetInteger(POSITION_TYPE);
   if(tipo == POSITION_TYPE_BUY) negocio.Sell(_volume, _Symbol, 0, 0, 0, "Fechamento do dia");
   else negocio.Buy(_volume, _Symbol, 0, 0, 0, "Fechamento do dia");
}

void VerificaMeta(){
   datetime _inicio, _fim;
   double lucro = 0, perda = 0;
   double resultado;
   ulong ticket;
   
   MqlDateTime inicio_struct, fim_struct;
   TimeToStruct(rates[0].time, inicio_struct);
   inicio_struct.hour = 0;
   inicio_struct.min = 2;
   inicio_struct.sec = 2;
   _inicio = StructToTime(inicio_struct);
   
   TimeToStruct(rates[0].time, fim_struct);
   fim_struct.hour = 23;
   fim_struct.min = 58;
   fim_struct.sec = 58;
   _fim = StructToTime(fim_struct);
   
   HistorySelect(_inicio, _fim);
   
   for(int i=0; i<HistoryDealsTotal(); i++){
      ticket = HistoryDealGetTicket(i);
      if(ticket > 0){
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol){
            resultado = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(resultado < 0){
               perda += -resultado;
            }else{
               lucro += resultado;
            }
         }
      }
   }
      
   double resultado_liquido = lucro - perda;
   
   if(resultado_liquido > _meta_gain){
      _meta_batida = true;
   }else if(resultado_liquido < _meta_loss){
      _meta_batida = true;
   }
   
   Comment("Lucro: ", DoubleToString(lucro, 2), " Perdas: ", DoubleToString(perda, 2), " Resultado: ", DoubleToString(resultado_liquido, 2));
}