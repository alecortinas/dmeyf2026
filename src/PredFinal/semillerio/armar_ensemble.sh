#!/bin/bash
# armar_ensemble.sh
#
# Arma un ENSEMBLE "sabor 2" (mismo modelo, varias semillas) promediando
# las probabilidades de varios experimentos ya entrenados, genera los
# archivos de corte, y los sube a Kaggle. No reentrena nada: usa los
# prediccion.txt que cada experimento ya dejo guardado en su carpeta
# WF<experimento>/.
#
# Uso:
#   ./armar_ensemble.sh "<experimentos>" "<cortes>" <nombre_ensemble> [competencia]
#
# Ejemplo (el que se uso para la entrega final, combinado 10 semillas):
#   ./armar_ensemble.sh "9820 9821 9822 9823 9824 9825 9826 9827 9828 9829" \
#                        "1500" \
#                        ENSEMBLE_COMBINADO
#
# Ejemplo con barrido de cortes (para encontrar el maximo del ensemble):
#   ./armar_ensemble.sh "9820 9821 9822 9823 9824 9825 9826 9827 9828 9829" \
#                        "1400 1500 1600 1700 1800 1900 2000" \
#                        ENSEMBLE_COMBINADO

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Uso: $0 \"<experimentos>\" \"<cortes>\" <nombre_ensemble> [competencia]"
  echo "  experimentos: numeros de WF separados por espacio, entre comillas"
  echo "  cortes:       cantidad de envios separados por espacio, entre comillas"
  echo "  nombre_ensemble: prefijo para los archivos generados (sin espacios)"
  exit 1
fi

EXPERIMENTOS="$1"
CORTES="$2"
NOMBRE="$3"
COMPETENCIA="${4:-utn-2026-virtual-jr}"

OUTDIR="$(cd "$(dirname "$0")" && pwd)/ensemble_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "Experimentos a combinar: $EXPERIMENTOS"
echo "Cortes a generar: $CORTES"
echo "Salida en: $OUTDIR"
echo

# --- paso 1: promediar las probabilidades de todos los experimentos ---
ARCHIVO_PROB="${OUTDIR}/${NOMBRE}_probabilidad.csv"

Rscript -e "
  library(data.table)

  experimentos <- strsplit('${EXPERIMENTOS}', ' ')[[1]]

  tablas <- lapply(experimentos, function(exp) {
    archivo <- paste0('/home/ds/buckets/b1/exp/WF', exp, '/prediccion.txt')
    if (!file.exists(archivo)) stop('No existe: ', archivo)
    tb <- fread(archivo)
    setnames(tb, 'prob', paste0('prob_', exp))
    tb
  })

  ensemble <- Reduce(function(x, y) merge(x, y, by='numero_de_cliente'), tablas)
  cols_prob <- grep('^prob_', colnames(ensemble), value=TRUE)
  ensemble[, prob_promedio := rowMeans(.SD), .SDcols=cols_prob]

  cat('Experimentos combinados:', length(experimentos), '\n')
  cat('Clientes en el ensemble:', nrow(ensemble), '\n')

  tb_final <- ensemble[, .(numero_de_cliente, prob=prob_promedio)]
  setorder(tb_final, -prob)

  fwrite(tb_final, '${ARCHIVO_PROB}', sep='\t')
"

echo "Probabilidad promediada guardada en: $ARCHIVO_PROB"
echo

# --- paso 2: generar un archivo de corte por cada valor de CORTES, y subir a Kaggle ---
for CORTE in $CORTES; do

  ARCHIVO_KAGGLE="${OUTDIR}/${NOMBRE}_${CORTE}.csv"

  Rscript -e "
    library(data.table)
    tb <- fread('${ARCHIVO_PROB}')
    setorder(tb, -prob)
    tb[, Predicted := 0L]
    tb[1:${CORTE}, Predicted := 1L]
    fwrite(tb[, .(numero_de_cliente, Predicted)], '${ARCHIVO_KAGGLE}', sep=',')
  "

  echo "== corte=${CORTE}: csv generado (${ARCHIVO_KAGGLE}) =="
  echo "  -> subiendo a Kaggle"

  kaggle competitions submit -c "$COMPETENCIA" -f "$ARCHIVO_KAGGLE" \
    -m "${NOMBRE} envios=${CORTE} (experimentos: ${EXPERIMENTOS})"

  sleep 3
done

echo
echo "Listo. Archivos en: $OUTDIR"
