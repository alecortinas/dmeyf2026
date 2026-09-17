#!/bin/bash
# run_semillas.sh
#
# Corre un notebook/script R de DMEyF una vez por cada semilla de la lista fija
# (346321 = la que ya trae el script + las 14 que definió el usuario), pisando
# PARAM$semilla_primigenia y PARAM$experimento en una COPIA temporal para no
# modificar el notebook original.
#
# Uso:
#   ./run_semillas.sh <ruta_al_notebook_o_script_R> <experimento_base> [corte_fijo]
#
# Ejemplos:
#   ./run_semillas.sh /home/ds/buckets/b1/dmeyf2026/src/PredFinal/729_final_junior.ipynb 9500
#       -> corre las 15 semillas dejando el barrido de cortes original (1800..2400)
#
#   ./run_semillas.sh /home/ds/buckets/b1/dmeyf2026/src/PredFinal/729_cambios.ipynb 9600 2100
#       -> corre las 15 semillas subiendo un unico corte fijo (2100) por semilla,
#          para poder hacer el Wilcoxon pareado semilla a semilla contra el baseline

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Uso: $0 <ruta_notebook_o_R> <experimento_base> [corte_fijo]"
  exit 1
fi

INPUT="$1"
EXP_BASE="$2"
CORTE_FIJO="${3:-}"

SEMILLAS=(346321 187211 322247 390263 430267 487649 522497 569321 906839 992689)

OUTDIR="$(cd "$(dirname "$0")" && pwd)"
RUNDIR="${OUTDIR}/runs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUNDIR"

MANIFEST="${RUNDIR}/manifest.csv"
echo "indice,semilla,experimento,logfile,status" > "$MANIFEST"

echo "Notebook/script de entrada: $INPUT"
echo "Experimento base: $EXP_BASE"
if [ -n "$CORTE_FIJO" ]; then
  echo "Corte fijo a aplicar: $CORTE_FIJO"
else
  echo "Sin corte fijo: se respeta el barrido de cortes original del script"
fi
echo "Resultados de esta tanda en: $RUNDIR"
echo

# convierto el notebook a script R una sola vez (si ya es .R, lo uso tal cual)
if [[ "$INPUT" == *.ipynb ]]; then
  TEMPLATE="${RUNDIR}/_template.R"
  jupyter nbconvert --to script --stdout "$INPUT" > "$TEMPLATE" 2>/dev/null
else
  TEMPLATE="$INPUT"
fi

i=0
for SEMILLA in "${SEMILLAS[@]}"; do
  EXPERIMENTO=$((EXP_BASE + i))
  SCRIPT_R="${RUNDIR}/run_${EXPERIMENTO}_${SEMILLA}.R"
  LOGFILE="${RUNDIR}/log_${EXPERIMENTO}_${SEMILLA}.txt"

  cp "$TEMPLATE" "$SCRIPT_R"

  # piso la semilla y el numero de experimento (para no pisar carpetas entre corridas)
  sed -i "s/PARAM\$semilla_primigenia <- [0-9]*/PARAM\$semilla_primigenia <- ${SEMILLA}/" "$SCRIPT_R"
  sed -i "s/PARAM\$experimento <- [0-9]*/PARAM\$experimento <- ${EXPERIMENTO}/" "$SCRIPT_R"

  # si se pidio un corte fijo, reemplazo el barrido de cortes por un unico valor
  if [ -n "$CORTE_FIJO" ]; then
    sed -i "s/PARAM\$kaggle\$cortes <- seq([0-9]*, [0-9]*, by = [0-9]*)/PARAM\$kaggle\$cortes <- c(${CORTE_FIJO})/" "$SCRIPT_R"
  fi

  echo "[$((i+1))/15] semilla=${SEMILLA} experimento=${EXPERIMENTO} -> ${LOGFILE}"

  if Rscript "$SCRIPT_R" > "$LOGFILE" 2>&1; then
    STATUS="OK"
  else
    STATUS="ERROR"
    echo "  !! fallo la corrida, revisar ${LOGFILE}"
  fi

  echo "${i},${SEMILLA},${EXPERIMENTO},${LOGFILE},${STATUS}" >> "$MANIFEST"

  i=$((i+1))
done

echo
echo "Listo. Manifest en: $MANIFEST"
