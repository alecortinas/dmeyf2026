#!/bin/bash
# Corre 621_WorkFlow_01_junior_grupoB_Exp9111.ipynb (SIN MODIFICARLO) una vez por cada una de las
# 15 semillas del Experimento 9111, de a una, en secuencia.
#
# Cada corrida es el mismo notebook, sin ningun cambio de codigo excepto el
# valor de PARAM$semilla_primigenia. Cada corrida hace su PROPIO Grid Search
# y puede terminar eligiendo hiperparametros distintos: son 15 corridas
# independientes del pipeline original, no una version "robusta a semilla"
# del tuning.
#
# El archivo original 621_WorkFlow_01_junior_grupoB_Exp9111.ipynb NUNCA se toca: se trabaja siempre
# sobre una copia temporal que se borra al final de cada corrida.
#
# Como no hay parallel::mclapply corriendo DENTRO de cada corrida (cada corrida
# es un proceso R independiente, sin fork()), no hace falta ningun fix de
# threading para este script.

# Uso: nohup bash run_9111_15semillas.sh > "$HOME/log/z621_9111/nohup.out" 2>&1 &
#
# Portable entre usuarios/VMs: todas las rutas se arman con $HOME y con la
# ubicacion del propio script (nada de "/home/ds" hardcodeado). Requisito:
# este .sh tiene que quedar en una carpeta "Corridas_FE" (o como se llame)
# ubicada un nivel por debajo de donde esta 621_WorkFlow_01_junior_grupoB_Exp9111.ipynb
# (misma estructura relativa que en el repo).

cd "$(dirname "$0")" || exit 1

ORIGINAL="../621_WorkFlow_01_junior_grupoB_Exp9111.ipynb"
TRABAJO="621_WorkFlow_01_junior_grupoB_Exp9111_semilla_actual.ipynb"

# Numero de experimento REAL segun PARAM$experimento adentro del notebook
# (define en que carpeta WF<N> caen los resultados). Coincide con el numero del experimento.
WF_EXPERIMENTO=9111

LOGDIR="$HOME/log/z621_9111"
RESULTDIR="$HOME/buckets/b1/exp/WF${WF_EXPERIMENTO}"

if [ ! -f "$ORIGINAL" ]; then
  echo "ERROR: no encuentro $ORIGINAL (parado en $(pwd)). Este script tiene que estar en una subcarpeta, un nivel por debajo del notebook original." >&2
  exit 1
fi

mkdir -p "$LOGDIR"
mkdir -p "$RESULTDIR"

# semillas para el Experimento 9111 (15 semillas, propias del Grupo B)
SEMILLAS=(116131 187211 322247 390263 430267 487649 522497 569321 906839 992689 828833 791261 981947 962867 223063)

RESUMEN="$LOGDIR/resumen_9111.txt"
echo -e "semilla\tganancia_suavizada_max\tenvios" > "$RESUMEN"

for semilla in "${SEMILLAS[@]}"; do
  echo "=== $(date '+%F %T') INICIO semilla $semilla ===" | tee -a "$LOGDIR/secuencial.log"

  if [ ! -f "$ORIGINAL" ]; then
    echo "ERROR: no encuentro $ORIGINAL" | tee -a "$LOGDIR/secuencial.log"
    exit 1
  fi

  # copia de trabajo: el archivo original NO se toca en ningun momento
  cp "$ORIGINAL" "$TRABAJO"

  # cambio UNICAMENTE el valor de la semilla en la copia de trabajo (nada mas)
  python3 - "$TRABAJO" "$semilla" <<'PYEOF'
import json, sys
path, semilla = sys.argv[1], sys.argv[2]
nb = json.load(open(path))
cambiado = False
for c in nb["cells"]:
    if c["cell_type"] != "code":
        continue
    for i, line in enumerate(c["source"]):
        if "PARAM$semilla_primigenia <- 346321" in line:
            c["source"][i] = line.replace("346321", semilla)
            cambiado = True
if not cambiado:
    sys.exit("no se encontro la linea de la semilla_primigenia")
json.dump(nb, open(path, "w"), indent=1)
PYEOF
  if [ $? -ne 0 ]; then
    echo "=== $(date '+%F %T') ERROR parcheando la semilla $semilla, se sigue con la proxima ===" | tee -a "$LOGDIR/secuencial.log"
    rm -f "$TRABAJO"
    continue
  fi

  jupyter nbconvert --to notebook --execute --inplace \
    --ExecutePreprocessor.timeout=-1 \
    --ExecutePreprocessor.kernel_name=ir \
    "$TRABAJO" >> "$LOGDIR/semilla_${semilla}.log" 2>&1
  rc=$?

  if [ $rc -eq 0 ]; then
    echo "=== $(date '+%F %T') OK    semilla $semilla ===" | tee -a "$LOGDIR/secuencial.log"

    # archivo los resultados de ESTA semilla antes de que la proxima corrida los pise
    destino="$RESULTDIR/semilla_${semilla}"
    mkdir -p "$destino"
    cp "$RESULTDIR"/PARAM.yml "$RESULTDIR"/ganancias.txt "$RESULTDIR"/modelo.txt \
       "$RESULTDIR"/impo.txt "$RESULTDIR"/prediccion.txt "$RESULTDIR"/curva_de_ganancia.pdf \
       "$RESULTDIR"/tb_grid_search_01.txt \
       "$destino/" 2>/dev/null

    # extraigo ganancia_suavizada_max y envios de ganancias.txt para el resumen
    python3 - "$destino/ganancias.txt" "$semilla" "$RESUMEN" <<'PYEOF'
import csv, sys
path, semilla, resumen = sys.argv[1], sys.argv[2], sys.argv[3]
mx, mxpos = None, None
with open(path) as f:
    r = csv.reader(f, delimiter="\t")
    header = next(r)
    idx = header.index("gan_suavizada")
    for i, row in enumerate(r, start=1):
        v = row[idx]
        if v == "":
            continue
        v = float(v)
        if mx is None or v > mx:
            mx, mxpos = v, i
with open(resumen, "a") as f:
    f.write(f"{semilla}\t{mx}\t{mxpos}\n")
PYEOF

  else
    echo "=== $(date '+%F %T') FALLO semilla $semilla (exit $rc) --- se sigue con la proxima ===" | tee -a "$LOGDIR/secuencial.log"
  fi

  rm -f "$TRABAJO"
done

echo "=== $(date '+%F %T') LAS 15 SEMILLAS DEL EXP 9111 TERMINARON. Resumen en $RESUMEN, detalle por semilla en $RESULTDIR/semilla_<N>/ ===" | tee -a "$LOGDIR/secuencial.log"
