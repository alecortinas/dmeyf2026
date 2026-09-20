# Modelo combinado — cómo correr todo, paso a paso

Este README explica cómo reproducir de punta a punta el modelo final entregado: desde el
entrenamiento hasta la submission subida a Kaggle.

## Qué es el "modelo combinado"

Es el notebook baseline oficial de la cátedra (`z729_final_junior.ipynb`)
con **3 modificaciones puntuales**, cada una tomada de un experimento distinto del curso,
ya validado por sus propios autores. Todo lo demás queda idéntico al baseline.

| # | Cambio | Origen |
|---|---|---|
| 1 | FEhist extendido: se agregan `lag3`, `delta3` y media móvil de 3 meses | Problema #5 (Grupo B: Cortiñas - Brúgola) |
| 2 | Se excluyen los meses de pandemia (202003-202012) del training | Problema #4 (Grupo B: Bazza Antonella) |
| 3 | `training_pct` de 1.0 a 0.5 (solo afecta el Grid Search, no el modelo final) | Problema #12 (Grupo B: Bianchini - Bosso) |

El notebook con estos 3 cambios ya aplicados está en **`729_final_junior_COMBINADO.ipynb`**
(en esta misma carpeta), celda por celda idéntico al baseline salvo en las celdas donde
corresponden estos cambios.

**Validación**: comparado contra el baseline con 10 semillas y test de Wilcoxon pareado
(máximo por semilla en Kaggle, el método correcto), el combinado gana de forma significativa
(p=0.0049, 9 de 10 semillas a favor).

---

## Paso 1 — Entrenar el modelo con varias semillas (semillerío)

El script `semillerio/run_semillas.sh` corre el notebook una vez por cada semilla, sin
modificar el archivo original (trabaja sobre copias temporales).

```bash
cd src/PredFinal/semillerio
./run_semillas.sh ../729_final_junior_COMBINADO.ipynb 9820
```

- Esto corre las 10 semillas por defecto (346321, 187211, 322247, 390263, 430267, 487649,
  522497, 569321, 906839, 992689), generando los experimentos **WF9820 a WF9829**.
- Cada corrida hace el pipeline completo: Catastrophe Analysis, drift, feature engineering,
  grid search de hiperparámetros, entrenamiento del modelo final, predicción sobre el mes
  futuro (202109), y sube automáticamente 7 cortes a Kaggle por semilla.
- Cada experimento guarda su modelo y predicciones en `/home/ds/buckets/b1/exp/WF<experimento>/`
  (`modelo.txt`, `prediccion.txt`, `impo.txt`, `tb_grid_search_01.txt`, `PARAM.yml`).
- **Estas 10 carpetas ya están commiteadas en este repo** (`src/PredFinal/WF9820` a
  `WF9829`), así que si solo querés reproducir el ensemble, podés saltear este paso y usar
  directamente los `prediccion.txt` que ya están ahí.

Para correr con semillas distintas a las 10 por defecto:

```bash
SEMILLAS="123456 789012" ./run_semillas.sh ../729_final_junior_COMBINADO.ipynb 9900
```

**`run_semillas.sh` también sirve para correr el baseline** (no es exclusivo del combinado) —
solo hay que pasarle la ruta al notebook del baseline en vez del combinado:

```bash
./run_semillas.sh <ruta_al_baseline.ipynb> 9500
```

Así se generaron las 10 corridas del baseline (`WF9500` a `WF9509`), que son las que se
usan para la comparación con Wilcoxon del paso siguiente.

---

## Paso 2 — Armar el ensemble (promediar las semillas)

Con las 10 corridas ya hechas (Paso 1), se arma un **ensemble**: se promedia la
probabilidad que cada semilla le asignó a cada cliente, y se usa esa probabilidad promediada
para la entrega final. 

Abrir y correr **`semillerio/armar_ensemble.ipynb`** (kernel R). El notebook ya está
configurado con:

- `PARAM$experimentos` = los 10 experimentos del combinado (WF9820-WF9829)
- `PARAM$cortes` = el barrido completo de cortes probado (1400 a 3000, cada 100)

El notebook hace, en orden:

1. Lee el `prediccion.txt` de cada uno de los 10 experimentos.
2. Promedia la probabilidad por cliente entre las 10 semillas.
3. Para cada corte de `PARAM$cortes`, genera el archivo `<numero_de_cliente,Predicted>` y lo
   sube a Kaggle con `kaggle competitions submit`.

Todo lo que genera queda en una carpeta nueva `semillerio/ensemble_<fecha_hora>/`, para no
pisar corridas anteriores.

**Si solo se quiere reproducir la submission final** (sin repetir el barrido completo de 17
cortes), cambiar antes de correr:

```r
PARAM$cortes <- c(1500)
```

---

