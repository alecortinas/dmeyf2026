# armar_ensemble.R
#
# Arma un ENSEMBLE "sabor 2" (mismo modelo, varias semillas) promediando
# las probabilidades de varios experimentos ya entrenados, genera los
# archivos de corte, y los sube a Kaggle. No reentrena nada: usa los
# prediccion.txt que cada experimento ya dejo guardado en su carpeta
# WF<experimento>/.
#
# Uso:
#   Rscript armar_ensemble.R
#
# Para usarlo con otros experimentos/cortes, modificar directamente
# PARAM$experimentos y PARAM$cortes mas abajo.

require("data.table")

PARAM <- list()

# numeros de experimento (carpetas WF<experimento>) a promediar
# ejemplo real: las 10 semillas del modelo combinado
PARAM$experimentos <- c(9820, 9821, 9822, 9823, 9824, 9825, 9826, 9827, 9828, 9829)

# cantidad de envios a generar y subir (uno o varios)
PARAM$cortes <- c(1500)

PARAM$nombre_ensemble <- "ENSEMBLE_COMBINADO"
PARAM$kaggle$competencia <- "utn-2026-virtual-jr"

# carpeta de salida, una nueva por corrida para no pisar resultados anteriores
PARAM$outdir <- paste0(
  "/home/ds/buckets/b1/dmeyf2026/src/PredFinal/semillerio/ensemble_",
  format(Sys.time(), "%Y%m%d_%H%M%S")
)
dir.create(PARAM$outdir, showWarnings = FALSE, recursive = TRUE)

cat("Experimentos a combinar:", PARAM$experimentos, "\n")
cat("Cortes a generar:", PARAM$cortes, "\n")
cat("Salida en:", PARAM$outdir, "\n\n")


# ---------------------------------------------------------------
# paso 1: promediar las probabilidades de todos los experimentos
# ---------------------------------------------------------------

tablas <- lapply(PARAM$experimentos, function(exp) {

  archivo <- paste0("/home/ds/buckets/b1/exp/WF", exp, "/prediccion.txt")

  if (!file.exists(archivo)) {
    stop("No existe el archivo de predicciones: ", archivo)
  }

  tb <- fread(archivo)
  setnames(tb, "prob", paste0("prob_", exp))
  tb
})

# merge sucesivo de las 10 (o las que sean) tablas por numero_de_cliente
ensemble <- Reduce(function(x, y) merge(x, y, by = "numero_de_cliente"), tablas)

cols_prob <- grep("^prob_", colnames(ensemble), value = TRUE)
ensemble[, prob_promedio := rowMeans(.SD), .SDcols = cols_prob]

cat("Experimentos combinados:", length(PARAM$experimentos), "\n")
cat("Clientes en el ensemble:", nrow(ensemble), "\n\n")

tb_prediccion <- ensemble[, list(numero_de_cliente, prob = prob_promedio)]
setorder(tb_prediccion, -prob)

archivo_prob <- paste0(PARAM$outdir, "/", PARAM$nombre_ensemble, "_probabilidad.csv")
fwrite(tb_prediccion, file = archivo_prob, sep = "\t")
cat("Probabilidad promediada guardada en:", archivo_prob, "\n\n")


# ---------------------------------------------------------------
# paso 2: por cada corte, generar el archivo y subirlo a Kaggle
# ---------------------------------------------------------------

for (envios in PARAM$cortes) {

  tb_prediccion[, Predicted := 0L]
  tb_prediccion[1:envios, Predicted := 1L]

  archivo_kaggle <- paste0(PARAM$outdir, "/", PARAM$nombre_ensemble, "_", envios, ".csv")

  fwrite(tb_prediccion[, list(numero_de_cliente, Predicted)],
    file = archivo_kaggle,
    sep = ","
  )

  cat("== corte=", envios, ": csv generado (", archivo_kaggle, ") ==\n", sep = "")
  cat("  -> subiendo a Kaggle\n")

  comando <- "kaggle competitions submit"
  competencia <- paste("-c", PARAM$kaggle$competencia)
  arch <- paste("-f", archivo_kaggle)
  mensaje <- paste0(
    "-m '", PARAM$nombre_ensemble, " envios=", envios,
    " (experimentos: ", paste(PARAM$experimentos, collapse = " "), ")'"
  )

  linea <- paste(comando, competencia, arch, mensaje)

  salida <- system(linea, intern = TRUE)
  Sys.sleep(5)
  cat(salida, "\n")
}

cat("\nListo. Archivos en:", PARAM$outdir, "\n")
