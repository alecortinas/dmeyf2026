# Cómo correr los scripts (versión corta)

## Para qué sirve

Cada `run_*.sh` corre su notebook (Exp9110, Exp9111, Exp9112, Exp9116_GrupoA
o Exp9117_GrupoA) varias veces seguidas, una por semilla, sin que tengas que
abrir el notebook y tocar nada a mano.

## Dónde tiene que ir

El `.sh` va en una carpeta **un nivel por debajo** de donde está su notebook:

```
src/
├── 621_WorkFlow_01_junior_grupoB_Exp9110.ipynb
├── 621_WorkFlow_01_junior_grupoB_Exp9111.ipynb
├── 621_WorkFlow_01_junior_grupoB_Exp9112.ipynb
├── 621_WorkFlow_01_junior_grupoB_Exp9116_GrupoA.ipynb
├── 621_WorkFlow_01_junior_grupoB_Exp9117_GrupoA.ipynb
└── Corridas_FE/              ← los .sh van ACÁ
    ├── run_9110_15semillas.sh
    ├── run_9111_15semillas.sh
    ├── run_9112_15semillas.sh
    ├── run_9116_GrupoA_10semillas.sh
    └── run_9117_GrupoA_10semillas.sh
```

(La carpeta `Corridas_FE` se puede llamar como sea, con que quede justo un
nivel abajo de los notebooks alcanza.)

## Cómo se corre

Parate en esa carpeta y corré el que te toque, por ejemplo:

```bash
cd Corridas_FE
chmod +x run_9110_15semillas.sh
nohup bash run_9110_15semillas.sh > salida.log 2>&1 &
```

Eso es todo. Se va a quedar corriendo solo en segundo plano (podés cerrar la
terminal). Para ver si sigue vivo o cómo va:

```bash
tail -f "$HOME/log/z621_9110/secuencial.log"
```

Ahí vas a ver una línea por semilla que dice `INICIO`, `OK` o `FALLO`.

Cuando termina todo, va a decir `TERMINARON` al final de ese mismo log.
