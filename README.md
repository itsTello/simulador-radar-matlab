# 📡 Simulador de Radar PPI con Compresión de Pulsos LFM

Desarrollado en MATLAB, este proyecto es un simulador en tiempo real de un radar de onda continua pulsada[cite: 1]. Modela fielmente la física de la propagación electromagnética, presentando una interfaz visual interactiva que reproduce una pantalla PPI (Plan Position Indicator), un A-Scope y el espacio físico real simulado[cite: 1].

El objetivo de esta herramienta es observar de forma inmediata cómo los parámetros de diseño (potencia, ancho de pulso, ganancia, etc.) afectan al alcance, la resolución radial y la tasa de falsas alarmas[cite: 1].

*Para un desglose analítico completo de las ecuaciones de diseño y el dimensionamiento del sistema, consulta la **[Memoria Técnica adjunta (PDF)](Memoria_Radar_DavidTelloYMarioPiqueras.pdf)**.*

## ⚙️ Características y Modelado Físico

*   **Compresión de Pulsos LFM (Chirp):** Desacopla la resolución radial del alcance máximo. El sistema simula el ancho de banda del chirp ($B_{chirp}$) y aplica la ganancia de procesado (Ratio de Compresión, $CR$)[cite: 1, 2].
*   **Modelo de Blancos (Swerling V):** Los objetivos presentan una sección eficaz (RCS, $\sigma$) aleatorizada y constante durante la simulación, moviéndose en trayectorias lineales[cite: 1, 2].
*   **Detección CFAR y Falsas Alarmas:** Se modela el ruido térmico AWGN y se calcula dinámicamente un umbral basado en la probabilidad de falsa alarma ($P_{fa}$) deseada mediante la aproximación de Albersheim[cite: 1, 2]. Las falsas alarmas se visualizan en el PPI[cite: 1].
*   **Ambigüedad en Distancia (Fold-over):** Demostración visual de ecos provenientes de blancos situados más allá del alcance no ambiguo ($R_{max,na}$), calculando el tiempo residual de vuelo para simular el "plegado" del eco en una posición errónea (marcada en amarillo)[cite: 1, 2].
*   **Zonas Ciegas:** Modelado estricto de la zona ciega física (basada en el tiempo de transmisión del pulso no comprimido $\tau$) y la zona ciega de diseño del PRT[cite: 1, 2].

## 🧮 Actualización del Modelo Matemático

El código fuente implementa una actualización sobre la ecuación fundamental descrita en la memoria de prácticas[cite: 1, 2]. Para integrar de forma precisa la compresión LFM en el cálculo de la potencia recibida ($P_{r}$), se incorpora explícitamente el Ratio de Compresión ($CR$) en el numerador[cite: 2]:

$$P_{r} = \frac{P_{t} \cdot CR \cdot G^{2} \cdot \lambda^{2} \cdot \sigma}{(4\pi)^{3} \cdot R^{4} \cdot L_{sys}}$$

Donde el Ratio de Compresión se define como el producto del ancho de banda del chirp por la duración del pulso transmitido ($CR = B_{chirp} \cdot \tau$)[cite: 1, 2]. Esta misma corrección se aplica al cálculo del alcance máximo ($R_{max}$)[cite: 2].

## 🚀 Cómo ejecutar el simulador

1.  Clona este repositorio o descarga los archivos.
2.  Abre MATLAB y navega hasta la carpeta del proyecto.
3.  Ejecuta el script principal: `Simulador_Radar_David_TelloYMarioPiqueras.m`[cite: 1].
4.  Se abrirá un menú CLI en la consola. Puedes pulsar `ENTER` para aceptar los parámetros por defecto o introducir valores personalizados para:
    *   Potencia TX, Frecuencia y Ganancia de antena[cite: 2].
    *   Anchura de pulso y Ancho de banda Chirp[cite: 2].
    *   Probabilidades de Detección ($P_{d}$) y Falsa Alarma ($P_{fa}$)[cite: 2].
    *   Número de blancos y su velocidad radial[cite: 2].
5.  La simulación gráfica comenzará inmediatamente tras la configuración[cite: 2].
