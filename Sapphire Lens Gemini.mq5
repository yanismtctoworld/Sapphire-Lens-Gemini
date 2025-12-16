//+------------------------------------------------------------------------------+
//|                                        Sapphire Lens Gemini .mq5             |           
//|                     MIT LicenseCopyright (c) 2025 yanismtctoworld            |
//|                    "https://github.com/yanismtctoworld/Sapphire-Lens-Gemini" |                                                    
//+------------------------------------------------------------------------------+
#property copyright "Yanis Moutsanas Carela, 2025. Licencia MIT."                      
#property link      https://github.com/yanismtctoworld/Sapphire-Lens-Gemini
#property version   "1.00"
//+------------------------------------------------------------------------------+
#property strict
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "Sapphire Lens"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

//--- Parámetros básicos
input int FastEMA = 1;            // EMA rápida
input int SlowEMA = 1000;         // EMA lenta
input int SignalPeriod = 1000;    // Período señal
input int LookbackBars = 50;      // Barras para detectar picos/valles

//--- Buffers
double macdBuffer[];    // Buffer para la línea MACD
double signalBuffer[];  // Buffer para la línea de Señal
double histogramBuffer[]; // Buffer para el Histograma MACD (el que se dibuja)

//--- Handles for built-in MACD indicator
int macd_handle;

//+------------------------------------------------------------------+
//| Función de inicialización                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   // Establece el buffer 0 para el histograma que se dibujará
   SetIndexBuffer(0, histogramBuffer, INDICATOR_DATA);
   
   // Crea el handle (identificador) para el indicador MACD incorporado
   macd_handle = iMACD(NULL, 0, FastEMA, SlowEMA, SignalPeriod, PRICE_CLOSE);
   
   // Verifica si el handle del MACD se creó correctamente
   if(macd_handle == INVALID_HANDLE)
   {
      Print("Falló al obtener el handle de MACD. Error: ", GetLastError());
      return INIT_FAILED; // Si falla, el indicador no se inicializa
   }
   
   // Limpiar líneas anteriores creadas por este indicador
   // (los objetos con nombre que empiezan por "MATL_")
   ObjectsDeleteAll(0, "MATL_");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Función principal de cálculo                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Asegúrate de que haya suficientes barras y que el handle de MACD sea válido
   if(rates_total < 1 || macd_handle == INVALID_HANDLE) return 0;

   int start;
   // Determina desde qué barra empezar el cálculo
   if(prev_calculated == 0) // Primera llamada a OnCalculate (inicial)
   {
      // Puedes empezar desde 0 o desde un punto más reciente para limitar el cálculo inicial
      start = 0; // O MathMax(0, rates_total - 200); para limitar el cálculo inicial
   }
   else // Llamadas subsecuentes (nuevas barras o recálculo)
   {
      start = prev_calculated - 1; // Recalcula la última barra y las nuevas barras
   }
   
   // Copia los valores de la línea principal del MACD (Buffer 0) al macdBuffer
   if(CopyBuffer(macd_handle, 0, start, rates_total - start, macdBuffer) == -1)
   {
      Print("Falló al copiar el buffer MACD. Error: ", GetLastError());
      return 0;
   }
   // Copia los valores de la línea de Señal del MACD (Buffer 1) al signalBuffer
   if(CopyBuffer(macd_handle, 1, start, rates_total - start, signalBuffer) == -1)
   {
      Print("Falló al copiar el buffer de Señal. Error: ", GetLastError());
      return 0;
   }

   // Calcula el Histograma MACD para las barras relevantes
   for(int i = start; i < rates_total; i++)
   {
      histogramBuffer[i] = macdBuffer[i] - signalBuffer[i];
   }
   
   // Detecta picos y valles en el histograma y dibuja las líneas
   DetectExtremes(rates_total, time);
   
   return rates_total; // Devuelve el número total de barras procesadas
}

//+------------------------------------------------------------------+
//| Detectar picos y valles                                          |
//+------------------------------------------------------------------+
void DetectExtremes(const int rates_total, const datetime &time[])
{
   // Asegúrate de que haya suficientes barras para el lookback
   if (rates_total <= LookbackBars * 2) return;

   // Itera desde LookbackBars hasta rates_total - LookbackBars - 1
   // para asegurar que i-j e i+j son índices válidos
   for(int i = LookbackBars; i < rates_total - LookbackBars; i++)
   {
      bool isPeak = true;
      bool isValley = true;
      
      // Verifica si es un Pico
      for(int j = 1; j <= LookbackBars; j++)
      {
         // Si el valor actual es menor o igual que algún vecino, no es un pico
         if(histogramBuffer[i] <= histogramBuffer[i-j] || histogramBuffer[i] <= histogramBuffer[i+j])
         {
            isPeak = false;
            break; // No es necesario seguir comprobando si ya no es un pico
         }
      }
      
      // Verifica si es un Valle
      for(int j = 1; j <= LookbackBars; j++)
      {
         // Si el valor actual es mayor o igual que algún vecino, no es un valle
         if(histogramBuffer[i] >= histogramBuffer[i-j] || histogramBuffer[i] >= histogramBuffer[i+j])
         {
            isValley = false;
            break; // No es necesario seguir comprobando si ya no es un valle
         }
      }
      
      // Dibuja líneas si encontramos extremos
      if(isPeak) DrawTrendLine(i, time, clrRed);
      if(isValley) DrawTrendLine(i, time, clrBlue);
   }
}

//+------------------------------------------------------------------+
//| Dibujar línea de tendencia                                       |
//+------------------------------------------------------------------+
void DrawTrendLine(int bar, const datetime &time[], color clr)
{
   static int lastPeakBar = 0; // Para controlar la última barra donde se dibujó un pico
   static int lastValleyBar = 0; // Para controlar la última barra donde se dibujó un valle
   
   // Define una distancia mínima en barras entre las líneas para evitar aglomeraciones
   const int MIN_BARS_DISTANCE = 5; 

   // Obtiene el índice de la subventana donde se encuentra el indicador
   int subWindowIndex = ChartWindowFind(); 
   if (subWindowIndex < 0) // Si no se encuentra la subventana (nunca debería ocurrir para un #property indicator_separate_window)
   {
       Print("Error: No se pudo encontrar la subventana del indicador.");
       return;
   }

   // Verificaciones de depuración para valores de barra e histograma
  
  

   string name;
   bool created = false;

   if(clr == clrRed) // Línea para un Pico (bajista)
   {
      if(bar > lastPeakBar + MIN_BARS_DISTANCE) 
      {
         // Crea un nombre único para el objeto de línea, incluyendo la hora para más unicidad
         name = "MATL_Peak_" + IntegerToString(bar) + "_" + TimeToString(time[bar], TIME_DATE|TIME_MINUTES|TIME_SECONDS); 
         
         // Verifica si el objeto ya existe para evitar redibujados innecesarios
         if (ObjectFind(0, name) == -1)
         {
             // Crea el objeto de línea en la subventana correcta
             created = ObjectCreate(0, name, OBJ_TREND, subWindowIndex, time[bar], histogramBuffer[bar], time[bar+10], histogramBuffer[bar]);
             if (created)
             {
                 ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
                 ObjectSetInteger(0, name, OBJPROP_RAY, false); // Hace que la línea sea un segmento, no un rayo infinito
                 ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Grosor de la línea para mejor visibilidad
                 ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // Estilo sólido para mejor visibilidad
                 ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true); // Permite seleccionar la línea en el gráfico
                 Print("Línea de pico dibujada: ", name, " en ventana ", subWindowIndex, " en bar: ", bar);
             }
             else
             {
                 Print("Error al crear la línea de pico: ", name, " Error: ", GetLastError());
             }
         }
         lastPeakBar = bar; // Actualiza la última barra donde se dibujó un pico
      }
   }
   else if(clr == clrBlue) // Línea para un Valle (alcista)
   {
      if(bar > lastValleyBar + MIN_BARS_DISTANCE) 
      {
         // Crea un nombre único para el objeto de línea
         name = "MATL_Valley_" + IntegerToString(bar) + "_" + TimeToString(time[bar], TIME_DATE|TIME_MINUTES|TIME_SECONDS); 
         
         // Verifica si el objeto ya existe
         if (ObjectFind(0, name) == -1)
         {
             // Crea el objeto de línea en la subventana correcta
             created = ObjectCreate(0, name, OBJ_TREND, subWindowIndex, time[bar], histogramBuffer[bar], time[bar+10], histogramBuffer[bar]);
             if (created)
             {
                 ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
                 ObjectSetInteger(0, name, OBJPROP_RAY, false);
                 ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
                 ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
                 ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
                 Print("Línea de valle dibujada: ", name, " en ventana ", subWindowIndex, " en bar: ", bar);
             }
             else
             {
                 Print("Error al crear la línea de valle: ", name, " Error: ", GetLastError());
             }
         }
         lastValleyBar = bar; // Actualiza la última barra donde se dibujó un valle
      }
   }
}

//+------------------------------------------------------------------+
//| Limpieza al eliminar el indicador                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Elimina todos los objetos de línea creados por este indicador
   ObjectsDeleteAll(0, "MATL_");

}


