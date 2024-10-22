
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>

CTrade negocio;
CSymbolInfo simbolo;

string inicio = "10:30"; // Horario de inicio (entradas)
string termino = "17:00"; // Horario de Termino (entradas)
string fechamento = "17:30"; // Horario de Fechamento (posições)

double SL = 60; // Stop Loss
double TP = 120; // Take Profit
int Volume = 1; // Quantidade de contratos
double foraDaBanda = 0; // Posicionar uma ordem assim que atingir tantos pontos fora da Bolling Band.

int handleBand;
double handleClose, handleHigh, handleLow;
string nhandleBand;

MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual;

int OnInit(){
   
   // Inicializa o simbolo
   if(!simbolo.Name(_Symbol)){
      Print("Ativo Invalido!!");
      return INIT_FAILED;
   }
   
   handleBand = iBands(_Symbol, _Period, 10, 0, 2, PRICE_CLOSE);
   handleClose = iClose(_Symbol, PERIOD_D1, 1);
   handleHigh = iHigh(_Symbol, PERIOD_D1, 1);
   handleLow = iLow(_Symbol, PERIOD_D1, 1);   
     
   if(handleBand == INVALID_HANDLE || handleClose == INVALID_HANDLE || handleHigh == INVALID_HANDLE || handleLow == INVALID_HANDLE){
      Print("Falha ao carregar o handle!!!");
      return INIT_FAILED;
   }
   
   // Desenha o indicador no grafico, caso contrario, executa o print.
   if(!ChartIndicatorAdd(0, 0, handleBand)){
      Print("Falha plotar o inicador!!!");
      return INIT_FAILED;
   }
   
   // Captura o nome do indicador para poder excluir assim que o robo é removido do grafico (olhar a funcao OnDeinit()).
   nhandleBand = ChartIndicatorName(0, 0, ChartIndicatorsTotal(0, 0)-1);
   
   // Converte as string de horario para uma struct do tipo MqlDateTime.
   TimeToStruct(StringToTime(inicio), horario_inicio);
   TimeToStruct(StringToTime(termino), horario_termino);
   TimeToStruct(StringToTime(fechamento), horario_fechamento);

   // Faz validações comparando os horarios.
   if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min > horario_termino.min)){
      Print("Parametros de Horario Invalidos!!");
      return INIT_FAILED;
   }
   
   if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min > horario_fechamento.min)){
      Print("Parametros de Horario Invalidos!!");
      return INIT_FAILED;
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
    Print("Deinit reason -> ", reason);
    
    // Assim que o robo é removido do grafico, o indicador também é removido.
    ChartIndicatorDelete(0, 0, nhandleBand);
}

void OnTick(){
   
   // Atualiza o simbolo a cada novo tick.
   if(!simbolo.RefreshRates()){
      Print("Nao foi possivel atualizar o Ativo!!");
      return;
   }
   
   // Se estiver dentro do horario de "inicio", executa operações.
   if(HorarioDeEntrada()){
      
      // Só será executado uma nova operação somente se ainda não estiver posicionado e se não existir ordens no gráfico.
      if(!PositionSelect(_Symbol) && OrdersTotal() == 0){
         int sinal = SinalDeEntrada(); // 1 - Compra .. -1 - Venda .. 0 - Não faz nada
         if(sinal == 1){
            Comprar();
         }
         if(sinal == -1){
            Vender();
         }
      }
   }
   
   // Se chegar no horário de fechamento e ainda existir uma ordem no gráfico, essa ordem será fechada.
   if(HorarioDeFechamento()){
      if(PositionSelect(_Symbol)){
         FecharPosicao();
      }
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
   
   if(tipo == POSITION_TYPE_BUY)
      negocio.Sell(Volume, _Symbol, 0, 0, 0, "Fechamento do dia");
   else
      negocio.Buy(Volume, _Symbol, 0, 0, 0, "Fechamento do dia");
}

// Verifica se o preço atual esta acima ou abaixo da Bolling Band.
int SinalDeEntrada(){
   double BufferBandSup[], BufferBandInf[];
   ArraySetAsSeries(BufferBandSup, true);
   ArraySetAsSeries(BufferBandInf, true);
   CopyBuffer(handleBand, 1, 0, 1, BufferBandSup);
   CopyBuffer(handleBand, 2, 0, 1, BufferBandInf);
   

   if(simbolo.Last() > (BufferBandSup[0] + foraDaBanda)){
      return -1; // Comprar
   }
   
   if(simbolo.Last() < (BufferBandInf[0] - foraDaBanda)){
      return 1; // Vender
   }
   
   return 0;
}

void Comprar(){
   
   double price = simbolo.Ask(); // Melhor oferta de venda
   double stopLoss = simbolo.NormalizePrice(price - SL);
   double takeProfit = simbolo.NormalizePrice(price + TP);
   
   if(!negocio.Buy(Volume, NULL, price, stopLoss, takeProfit, "Compra acima da banda"))
      Print("Falha na compra -- Codigo de retorno: ",negocio.ResultRetcode(), " .... Descricao do codigo: ",negocio.ResultRetcodeDescription());
   else
      Print("Buy() executado com sucesso!!! Codigo de Retorne=",negocio.ResultRetcode(), " (",negocio.ResultRetcodeDescription(),")");
}

void Vender(){
   
   double price = simbolo.Bid(); // Melhor oferta de compra
   double stopLoss = simbolo.NormalizePrice(price + SL);
   double takeProfit = simbolo.NormalizePrice(price - TP);
   
   if(!negocio.Sell(Volume, NULL, price, stopLoss, takeProfit, "Venda abaixo da banda"))
      Print("Falha na venda -- Codigo de retorno: ",negocio.ResultRetcode(), " .... Descricao do codigo: ",negocio.ResultRetcodeDescription());
   else
      Print("Sell() executado com sucesso!!! Codigo de Retorne=",negocio.ResultRetcode(), " (",negocio.ResultRetcodeDescription(),")");
}