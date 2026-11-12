Guía de preparación · Data Engineering

# Databricks de cero a entrevista

Cada concepto explicado con palabras normales, una analogía del mundo real y un dibujo. Si entiendes los dibujos, entiendes Databricks.

## Contenido

1. [¿Qué es Databricks?](#que-es)
2. [Arquitectura: Control Plane y Data Plane](#arquitectura)
3. [El Cluster: Driver y Workers](#cluster)
4. [Spark: cómo piensa](#spark)
5. [El DAG explicado](#dag)
6. [Job → Stage → Task](#job-stage-task)
7. [Particiones y Shuffle](#particiones)
8. [Delta Lake y el transaction log](#delta)
9. [Arquitectura Medallion](#medallion)
10. [Workflows: Jobs con tareas](#workflows)
11. [Unity Catalog](#unity)
12. [Auto Loader y Streaming](#streaming)
13. [Delta Live Tables](#dlt)
14. [Rendimiento y optimización](#performance)
15. [30 preguntas de entrevista](#preguntas)
16. [Trampas típicas](#trampas)
17. [Cheat sheet de código](#cheatsheet)

## 01¿Qué es Databricks?

Databricks es una **plataforma en la nube para trabajar con datos**. En un solo lugar junta: dónde se guardan los datos, la potencia de cómputo para procesarlos, el editor donde escribes el código, el programador de tareas automáticas y las herramientas de machine learning.

Antes de que existiera, una empresa necesitaba cinco o seis productos distintos para eso, y alguien tenía que pegarlos con cinta. Databricks los unifica.

Analogía

Piensa en una **cocina industrial completa**. La *bodega* es donde guardas los ingredientes (tu storage en la nube). Los *cocineros* son la potencia de cómputo. Las *recetas* son tus notebooks. El *jefe de cocina que organiza turnos* es el scheduler de Jobs. Antes alquilabas la bodega a una empresa, los cocineros a otra y comprabas las recetas aparte. Databricks te entrega la cocina montada.

### El concepto clave: Lakehouse

Esta es la palabra que **siempre** aparece en una entrevista de Databricks. Para entenderla hay que conocer las dos cosas que existían antes.

#### Data Warehouse

Ordenadísimo. Tablas con estructura fija, rápido para consultas de negocio. Pero caro y solo acepta datos limpios y tabulares. No puedes meter videos, JSON raros ni fotos.

#### Data Lake

Acepta todo: archivos, imágenes, logs, lo que sea. Barato. Pero no tiene orden ni garantías, así que se convierte fácilmente en un "data swamp" (pantano) donde nadie encuentra nada ni confía en los números.

#### Lakehouse

Guardas los archivos barato como en un lake, pero encima pones una capa (Delta Lake) que les da el orden, las garantías y la velocidad de un warehouse. Lo mejor de los dos.

El Lakehouse no es un producto nuevo encima de los otros dos: es poner una capa de metadatos y transacciones (Delta Lake) sobre archivos baratos, para que se comporten como tablas de warehouse.

Si te lo preguntan, responde así

"Un Lakehouse es una arquitectura que combina el almacenamiento barato y flexible de un data lake con las garantías transaccionales y el rendimiento de un data warehouse. En Databricks eso se logra con Delta Lake, que añade un log de transacciones sobre archivos Parquet en el object storage. El beneficio principal es que eliminas la duplicación de datos: BI, data engineering y machine learning trabajan sobre la misma copia, con un solo modelo de gobierno."

## 02Arquitectura: Control Plane y Data Plane

Esta separación es **la pregunta de arquitectura más común**. Databricks está partido en dos mitades que viven en sitios distintos.

El **Control Plane** vive en la cuenta cloud de Databricks. Ahí está la interfaz web, el código de tus notebooks, la configuración de los clusters, el scheduler de jobs y los permisos. Es el "cerebro administrativo".

El **Data Plane** (hoy llamado *Compute Plane*) vive en **tu** cuenta cloud. Ahí se levantan las máquinas virtuales que procesan los datos, y ahí está tu storage. **Tus datos nunca salen de tu cuenta.** Esa frase es la que buscan los entrevistadores.

Analogía

Es como contratar una **empresa de mudanzas**. La oficina de la empresa (control plane) tiene los formularios, la agenda y los contratos. Pero los camiones y los muebles (data plane) están en tu casa. La oficina decide *cuándo* y *cómo* se mueven las cosas, pero nunca se lleva tus muebles a su oficina.

El control plane manda las instrucciones; el data plane hace el trabajo sobre datos que nunca abandonan tu cuenta cloud. Esa frontera es el argumento de seguridad de Databricks.

### Workspace

Un **workspace** es tu espacio de trabajo: la URL donde entras, con tus notebooks, carpetas, clusters y jobs. Una empresa suele tener varios (dev, staging, producción). Un workspace vive en una región cloud concreta.

### Serverless

Databricks ofrece además opciones **serverless**: el compute se levanta en la cuenta de Databricks y arranca en segundos, sin esperar 5 minutos a que nazcan las VMs. Pagas solo por el tiempo de consulta. La contrapartida es menos control sobre la configuración de la máquina. Si te preguntan cuándo usarlo: para SQL interactivo y BI, donde el arranque rápido importa más que el control fino.

## 03El Cluster: Driver y Workers

Un **cluster** es un grupo de computadoras trabajando juntas como si fueran una sola. Tiene dos tipos de miembros, y la diferencia entre ellos se pregunta siempre.

El **Driver** es el jefe. Recibe tu código, lo convierte en un plan, reparte el trabajo y recoge los resultados. Hay exactamente uno. Si el driver se cae, se cae todo.

Los **Workers** (o *Executors*) son los obreros. Cada uno recibe un pedazo de los datos y hace el cálculo sobre ese pedazo. Puede haber desde uno hasta cientos.

Analogía

Tienes que contar cuántas páginas hay en una biblioteca de 10.000 libros. Tú solo tardarías semanas. Pero si eres el **bibliotecario jefe** (driver) y tienes 20 ayudantes (workers), le das 500 libros a cada uno, cada quien cuenta lo suyo en paralelo, y tú solo sumas los 20 números que te entregan. El jefe no cuenta páginas: organiza y suma al final.

Cada core de cada worker es un "slot" que ejecuta una task. El paralelismo máximo del cluster es la suma de todos los cores de los workers; el driver no ejecuta tasks de datos.

### Tipos de compute

| Tipo | Para qué sirve | Clave |
| --- | --- | --- |
| All-Purpose | Desarrollo interactivo en notebooks. Varias personas pueden compartirlo. | Más caro por DBU. Se queda encendido mientras exploras. |
| Job Cluster | Se crea automáticamente cuando arranca un job y se destruye al terminar. | Más barato. Es la opción correcta para producción. |
| SQL Warehouse | Consultas SQL y herramientas de BI (Power BI, Tableau). | Optimizado para SQL. Existe en versión serverless. |
| Pools | Máquinas pre-encendidas en espera para que los clusters arranquen rápido. | Reduce el tiempo de arranque de minutos a segundos. |

Pregunta clásica

**"¿Cuándo usarías un job cluster en vez de uno all-purpose?"**

"Siempre que sea una carga programada y no interactiva. El job cluster nace con el job y muere al terminar, así que no pagas tiempo ocioso y la tarifa de DBU es menor. El all-purpose lo reservo para desarrollo exploratorio, donde necesito que el estado y la caché sobrevivan entre celdas, y donde el equipo comparte el mismo compute."

### Autoscaling y terminación automática

**Autoscaling**: defines un mínimo y un máximo de workers, y Databricks añade o quita según la carga. **Auto-termination**: el cluster se apaga solo tras X minutos sin actividad. Olvidar esto es la causa número uno de facturas infladas, y mencionarlo en una entrevista de costos suma puntos.

### DBU

Un **DBU** (Databricks Unit) es la unidad con la que Databricks cobra el procesamiento. Tu factura total son dos cosas sumadas: los DBUs que cobra Databricks y las máquinas virtuales que cobra tu proveedor cloud por separado.

## 04Spark: cómo piensa

**Apache Spark** es el motor que hace el trabajo pesado dentro de Databricks. Databricks fue fundada por los creadores de Spark, así que esperan que lo conozcas.

### Transformaciones vs Acciones

Esta es *la* idea que hay que tener clara. Spark divide todo lo que puedes pedirle en dos categorías.

Una **transformación** describe un cambio: filtrar, agrupar, unir, seleccionar columnas. Cuando escribes una transformación, **no pasa absolutamente nada**. Spark solo anota la instrucción en una lista.

Una **acción** pide un resultado real: contar filas, mostrar datos, escribir a disco. Solo cuando llega una acción Spark mira toda la lista, la optimiza y *entonces* ejecuta.

Esto se llama **evaluación perezosa** (lazy evaluation).

Analogía

Vas al supermercado con una lista. Un cocinero ingenuo iría al supermercado una vez por cada ingrediente: va, compra el tomate, vuelve; va, compra la cebolla, vuelve. Spark en cambio **anota toda la lista primero**. Cuando dices "ya, voy a cocinar" (la acción), mira la lista completa, se da cuenta de que el tomate y la cebolla están en el mismo pasillo, reordena el recorrido y hace un solo viaje eficiente.

Ejemplos de transformaciones: `select`, `filter`, `withColumn`, `groupBy`, `join`. Ejemplos de acciones: `show`, `count`, `collect`, `write`, `display`.

### Narrow vs Wide: la distinción que define el rendimiento

Las transformaciones se dividen otra vez, y esta división es la que explica por qué un job es lento.

Una transformación **narrow** (estrecha) se puede hacer sin mirar lo que tienen los demás workers. Filtrar una fila solo necesita esa fila. Cada worker trabaja aislado, en paralelo perfecto, sin mover datos por la red. Es barato.

Una transformación **wide** (ancha) necesita juntar datos que están repartidos entre workers. Para contar ventas por país, todas las filas de Colombia tienen que terminar en la misma máquina. Eso obliga a mover datos por la red: es el **shuffle**, y es la operación más cara de Spark.

Regla práctica para la entrevista: cuenta los shuffles de tu query y habrás contado los cuellos de botella. Cada línea naranja que cruza es datos moviéndose por la red.

### RDD, DataFrame y Dataset

| API | Qué es | Cuándo usarla |
| --- | --- | --- |
| RDD | La API original y de más bajo nivel. Una colección distribuida de objetos sin esquema. Tú controlas todo a mano. | Casi nunca hoy. Solo para control muy fino o datos sin estructura alguna. No recibe optimizaciones del Catalyst. |
| DataFrame | Una tabla distribuida con columnas y tipos. Es la API estándar. Spark la optimiza automáticamente. | El 95% del trabajo. Es lo que debes decir que usas. |
| Dataset | Como un DataFrame pero con tipos verificados en compilación. Solo existe en Scala y Java. | En Scala cuando quieres seguridad de tipos. En Python no existe. |

### Catalyst y Tungsten

**Catalyst** es el optimizador de consultas: toma tu código, lo reescribe en algo equivalente pero más rápido (mueve filtros, reordena joins, elimina columnas no usadas) y genera el plan físico. **Tungsten** es la capa de ejecución: gestiona memoria fuera del heap de la JVM y genera código Java optimizado en tiempo real para que el cálculo vaya al ritmo de la máquina.

**AQE (Adaptive Query Execution)** es la mejora más citada: Spark mira las estadísticas *reales* a mitad de la ejecución y reajusta el plan — fusiona particiones que quedaron diminutas, cambia la estrategia de join, y parte las particiones sesgadas. Está activo por defecto en Databricks.

## 05El DAG explicado

**DAG** significa Directed Acyclic Graph: grafo dirigido acíclico. Suena terrible; el concepto es simple.

**Grafo**: un dibujo de cajas conectadas por flechas. **Dirigido**: las flechas van en un solo sentido. **Acíclico**: nunca vuelve sobre sus pasos, no hay bucles. Si pudiera volver atrás, nunca terminaría.

En Spark, el DAG es **el mapa de todos los pasos necesarios para producir tu resultado y en qué orden**. Lo construye el driver cuando llega una acción, a partir de todas las transformaciones que anotó.

Analogía

Una receta de pasta dibujada como diagrama. "Hervir agua" y "picar ajo" no dependen una de otra, así que pueden pasar *al mismo tiempo* (paralelo). Pero "echar la pasta" necesita que el agua ya esté hirviendo (dependencia). Y nunca vuelves a "picar ajo" después de servir el plato (acíclico). Ese diagrama de la receta es un DAG.

Este es el DAG que ves en la pestaña Spark UI de Databricks. Las flechas son dependencias; lo que no está conectado puede ejecutarse simultáneamente.

Para qué sirve realmente el DAG: el driver lo usa para **decidir qué puede ir en paralelo**, para **optimizar antes de ejecutar**, y para **recuperarse de fallos**. Si un worker muere, Spark mira el DAG, ve exactamente qué pasos produjeron esa partición perdida y los recalcula solo para ella. Eso se llama **lineage** (linaje), y es la razón de que Spark tolere fallos sin replicar datos.

Cómo responder

**"¿Qué es un DAG en Spark?"**

"Es el grafo dirigido acíclico de las operaciones que Spark debe ejecutar para resolver una acción. El driver lo construye a partir de las transformaciones acumuladas de forma perezosa, lo usa para identificar qué ramas son independientes y pueden paralelizarse, y lo divide en stages cortando en cada frontera de shuffle. Además es el mecanismo de tolerancia a fallos: el lineage del DAG le permite recalcular solo la partición perdida en vez de reiniciar el job."

## 06Job → Stage → Task

Aquí hay una trampa de vocabulario que confunde a mucha gente en las entrevistas: **la palabra "job" significa dos cosas distintas** en Databricks.

El **Spark job** (del que hablamos en esta sección) es lo que dispara una acción dentro de tu código. Un notebook puede generar veinte Spark jobs.

El **Databricks Job** (o Workflow, sección 10) es una tarea programada: "ejecuta este notebook todos los días a las 6 am". Es un concepto de orquestación, no de Spark.

Si el entrevistador pregunta por "job", vale la pena aclarar a cuál se refiere. Eso mismo demuestra que entiendes la diferencia.

### La jerarquía de Spark

Las reglas memorizables: un job por acción; un stage nuevo por cada shuffle; una task por partición dentro del stage. Las tasks de un stage son el mismo código sobre datos distintos.

| Nivel | Definición en una línea | Cuántos hay |
| --- | --- | --- |
| Application | Tu programa conectado al cluster. | Uno por notebook/script conectado. |
| Job | Todo lo necesario para resolver una acción. | Uno por cada acción que ejecutas. |
| Stage | Un grupo de trabajo que se puede hacer sin mover datos. | Número de shuffles + 1. |
| Task | El código del stage aplicado a una partición. | Tantas como particiones tenga el stage. |

Analogía completa

Una **mudanza**. La *application* es la empresa trabajando contigo todo el día. Cada *job* es una casa que hay que mudar. Los *stages* son las fases obligatorias en orden: primero empacar todo, luego cargar el camión, luego descargar — no puedes cargar antes de empacar. Las *tasks* son "empacar la caja 7", "empacar la caja 8": trabajo idéntico sobre objetos distintos, que 10 personas pueden hacer a la vez.

## 07Particiones y Shuffle

Una **partición** es un pedazo de tus datos que cabe en la memoria de una máquina y que una task procesa. Si tienes 1 TB de datos y 10.000 particiones, cada una es de unos 100 MB.

El número de particiones determina el paralelismo. Demasiado pocas y la mayoría de tus workers está de brazos cruzados. Demasiadas y pagas más en coordinación que en cálculo. El rango que se suele citar como sano es **128 MB a 1 GB por partición**.

### Data skew: el problema que siempre preguntan

**Skew** (sesgo) es cuando una partición queda muchísimo más grande que las demás. El síntoma clásico: 199 tasks terminan en 30 segundos y una task sigue corriendo 40 minutos. El stage entero no termina hasta que termina la más lenta, así que todo el cluster espera a una sola máquina.

El skew aparece cuando una clave de agrupación o join concentra las filas: valores nulos, un cliente gigante, un país con el 80% de las ventas.

#### Cómo se arregla

- **AQE skew join**: en Databricks está activo por defecto y parte automáticamente las particiones sesgadas. Es la primera respuesta correcta.
- **Salting**: añades un número aleatorio a la clave sesgada para repartirla entre varias particiones, agregas, y luego quitas el sufijo. Es la respuesta "manual" que demuestra profundidad.
- **Broadcast join**: si una de las dos tablas es pequeña (unos cientos de MB), Spark manda una copia completa a cada worker y elimina el shuffle por completo.
- **Filtrar los nulos** antes del join, si no aportan nada.

### Broadcast join, con dibujo

Spark elige broadcast automáticamente cuando la tabla pequeña está por debajo de `spark.sql.autoBroadcastJoinThreshold` (10 MB por defecto; Databricks lo eleva y AQE lo decide en caliente). Puedes forzarlo con `broadcast(df)`.

### Partition pruning y repartition vs coalesce

**Partition pruning**: si la tabla está particionada en disco por fecha y filtras por fecha, Spark ni siquiera abre las carpetas de los otros días. Es la optimización más rentable que existe y es gratis si particionaste bien.

**`repartition(n)`** cambia el número de particiones haciendo un shuffle completo; sirve para subir el paralelismo o rebalancear. **`coalesce(n)`** solo puede reducir, pero fusiona particiones vecinas sin shuffle; sirve para no escribir 2.000 archivos diminutos al final.

## 08Delta Lake y el transaction log

**Delta Lake** es el formato de tabla por defecto en Databricks y es el corazón del Lakehouse. En la práctica es: **archivos Parquet normales, más una carpeta oculta con un registro de todo lo que ha pasado**.

Ese registro se llama `_delta_log`. Cada operación (insertar, borrar, actualizar) escribe un archivo JSON nuevo que dice qué archivos de datos se añadieron y cuáles dejaron de ser válidos. Los archivos viejos no se borran: se marcan como retirados.

Analogía

Una cuenta bancaria. El banco no guarda solo "tienes $500". Guarda **el historial de movimientos**: depósito de 300, retiro de 50, depósito de 250. Tu saldo actual es la suma del historial. Y por eso puedes pedir el extracto del mes pasado y ver exactamente cuánto tenías entonces. El `_delta_log` es ese historial de movimientos de la tabla.

Un lector siempre consulta primero el log para saber qué archivos son válidos ahora mismo. Por eso nunca ve una escritura a medias, y por eso puede pedir una versión anterior.

### ACID, en palabras normales

#### Atomicidad

Todo o nada. Si el job falla a la mitad de escribir 1.000 filas, no quedan 400 filas sueltas: no queda ninguna.

#### Consistencia

La tabla nunca queda en un estado inválido. Las reglas de esquema se respetan siempre.

#### Aislamiento

Alguien leyendo mientras tú escribes ve la versión anterior completa, nunca una mezcla de ambas.

#### Durabilidad

Una vez confirmada la escritura, está en el storage y sobrevive a caídas de máquinas.

### Operaciones que debes saber nombrar

```
-- Time travel: leer el pasado
SELECT * FROM ventas VERSION AS OF 12;
SELECT * FROM ventas TIMESTAMP AS OF '2026-11-01';

-- Ver todo el historial de la tabla
DESCRIBE HISTORY ventas;

-- Deshacer un desastre
RESTORE TABLE ventas TO VERSION AS OF 11;

-- MERGE: upsert. Actualiza lo que existe, inserta lo nuevo.
MERGE INTO ventas t
USING nuevas s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- Compactar archivos pequeños y ordenar por columna de filtro
OPTIMIZE ventas ZORDER BY (cliente_id);

-- Borrar físicamente los archivos retirados de hace +7 días
VACUUM ventas RETAIN 168 HOURS;
```

Cuidado con esta

**"Si haces VACUUM, ¿qué pasa con el time travel?"**

"Se pierde para las versiones cuyos archivos se eliminaron. `VACUUM` borra físicamente los archivos de datos que el log marcó como retirados y que superan el periodo de retención, así que después ya no se puede reconstruir aquellas versiones. Por eso el valor por defecto son 7 días y Databricks bloquea retenciones más cortas salvo que desactives la comprobación explícitamente."

### Schema evolution vs enforcement

**Enforcement** es el comportamiento por defecto: si intentas escribir una columna que la tabla no tiene, falla. Eso protege la calidad. **Evolution** es la opción que activas con `mergeSchema` cuando sí quieres que la tabla acepte la columna nueva. La respuesta madura en entrevista es: enforcement en Silver y Gold, evolution controlada en Bronze.

## 09Arquitectura Medallion

Es el patrón de diseño que Databricks recomienda y que **aparece en casi toda entrevista**. Los datos pasan por tres capas, y en cada una están más limpios y más listos para usar.

Analogía

Hacer jugo de naranja. **Bronze** es el costal de naranjas como llegó del camión, con tierra y hojas: no tocas nada, lo guardas tal cual por si acaso. **Silver** son las naranjas lavadas, sin las podridas, peladas y en gajos: útiles para muchas recetas. **Gold** es el vaso de jugo servido y listo para el cliente: hecho para un consumo específico.

No es obligatorio que sean exactamente tres capas, y conviene decirlo: es un patrón, no un dogma. Lo esencial es separar lo crudo de lo validado y de lo agregado.

## 10Workflows: Jobs con tareas

Aquí "job" significa lo otro: **una tubería programada**. Un **Databricks Job** (gestionado desde Workflows) es un conjunto de **tasks** con dependencias entre sí, que se ejecuta según un horario o un disparador.

Cada task puede ser un notebook, un script Python, una query SQL, un JAR, una pipeline de DLT o incluso otro job. Las dependencias entre tasks forman — otra vez — un DAG. La diferencia es que este DAG lo dibujas tú, mientras que el de Spark lo deduce el motor.

Analogía

Es el **plan de un desayuno**. El *job* es "preparar el desayuno, todos los días a las 7". Las *tasks* son "hacer café", "tostar el pan", "freír huevos", "servir". Café y tostadas van en paralelo, pero "servir" espera a que las tres estén listas. Si los huevos se queman, el job marca fallo en esa task y tú decides: ¿se reintenta?, ¿se sirve sin huevos?, ¿se cancela todo?

Las tasks 2 y 3 no dependen entre sí, así que Databricks las lanza a la vez. La task 4 es un punto de encuentro: no arranca hasta que ambas terminen con éxito.

### Lo que conviene mencionar

- **Triggers**: por horario (cron), continuo, por llegada de archivos (*file arrival*), o manual vía API.
- **Reintentos**: configurables por task. Clave para fallos de red intermitentes.
- **Repair run**: si falla la task 5 de 7, al reparar solo se reejecutan la 5 y las que dependen de ella, no todo el job. Mencionar esto suma mucho.
- **Cluster compartido entre tasks**: reutilizar el mismo job cluster para varias tasks evita pagar 7 arranques.
- **Databricks Asset Bundles**: definir jobs como código YAML versionado en Git, para desplegar la misma pipeline en dev, staging y prod. Es la respuesta correcta a "¿cómo haces CI/CD aquí?".

Diferencia que debes tener lista

**"Diferencia entre un Spark job y un Databricks Job."**

"Un Spark job es una unidad interna del motor: lo genera cada acción y se descompone en stages y tasks. Un Databricks Job es una unidad de orquestación: un conjunto de tasks con dependencias y un trigger, que yo defino. Un solo Databricks Job puede generar cientos de Spark jobs al ejecutarse."

## 11Unity Catalog

**Unity Catalog** es el sistema de gobierno: decide **quién puede ver y hacer qué**, y lleva el registro de de dónde viene cada dato. Antes cada workspace tenía su propio metastore aislado; Unity Catalog es uno solo para toda la cuenta.

Su estructura es de tres niveles, y esto se pregunta tal cual:

La consulta `SELECT * FROM prod.ventas.pedidos` es exactamente este árbol recorrido de arriba abajo. Antes de Unity Catalog solo había dos niveles (`database.table`).

### Managed vs External

Una tabla **managed** la gestiona Databricks por completo: si haces `DROP TABLE`, los archivos se borran. Una tabla **external** apunta a una ruta que tú controlas: al hacer `DROP` desaparece el registro pero los archivos siguen ahí. Managed es lo recomendado por defecto porque permite optimizaciones automáticas; external se usa cuando otros sistemas fuera de Databricks también leen esos archivos.

## 12Auto Loader y Structured Streaming

**Structured Streaming** es la forma de Spark de procesar datos que llegan continuamente. La idea central es elegante: **tratas el stream como una tabla que nunca deja de crecer**. Escribes el mismo código que para un DataFrame normal, y Spark lo ejecuta en micro-lotes a medida que llegan datos nuevos.

**Auto Loader** (`cloudFiles`) es la herramienta para ingerir archivos que van cayendo en un directorio de la nube. Su truco: lleva su propio registro de qué archivos ya procesó, así que **nunca procesa dos veces el mismo archivo ni se le escapa ninguno**, sin que tú tengas que listar el directorio entero cada vez.

Analogía

Un **buzón de correo**. La versión ingenua sería vaciar el buzón entero cada mañana y revisar carta por carta cuáles ya leíste — carísimo cuando hay un millón de cartas. Auto Loader en cambio **apunta en una libreta** qué cartas ya abrió, y el cartero le avisa cuando llega una nueva. Solo toca lo nuevo.

El **checkpoint** es la pieza que hace posible la garantía exactly-once. Si lo borras, el stream vuelve a procesar desde cero.

```
(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "json")
  .option("cloudFiles.schemaLocation", "/chk/ventas/schema")
  .load("/landing/ventas/")
 .writeStream
  .option("checkpointLocation", "/chk/ventas")
  .trigger(availableNow=True)   # procesa lo pendiente y termina
  .toTable("prod.bronze.ventas"))
```

### Watermark, en una frase

En streaming los datos llegan tarde y desordenados. Un **watermark** le dice a Spark cuánto esperar por datos atrasados antes de cerrar una ventana de tiempo y liberar memoria. Sin watermark, el estado crece sin límite y el job acaba cayéndose.

## 13Delta Live Tables

**DLT** (hoy también llamado Lakeflow Declarative Pipelines) es una forma **declarativa** de escribir pipelines. En vez de decir *cómo* hacer cada paso en qué orden, declaras *qué* tabla quieres y de qué depende. DLT deduce el orden, gestiona los checkpoints, maneja los reintentos y vigila la calidad.

Analogía

La diferencia entre **conducir tú mismo** y **pedir un taxi**. Conduciendo (Workflows) decides cada giro: primero esta calle, luego aquella. Con el taxi (DLT) solo dices el destino y el conductor calcula la ruta, esquiva el tráfico y se encarga de los imprevistos. Pierdes control fino; ganas que no tengas que pensar en el camino.

Su rasgo distintivo son las **expectations**: reglas de calidad declaradas en la propia definición de la tabla, con tres comportamientos posibles ante una fila mala.

```
import dlt
from pyspark.sql.functions import col

@dlt.table(comment="Ventas limpias")
@dlt.expect("total_positivo", "total > 0")                # avisa y deja pasar
@dlt.expect_or_drop("id_presente", "id IS NOT NULL")     # descarta la fila
@dlt.expect_or_fail("moneda_valida", "moneda IN ('COP','USD')")  # detiene todo
def silver_ventas():
    return dlt.read_stream("bronze_ventas").filter(col("anio") >= 2025)
```

|  | Workflows | Delta Live Tables |
| --- | --- | --- |
| Estilo | Imperativo: tú defines el orden. | Declarativo: DLT deduce el orden. |
| Calidad | La programas tú con tests. | Expectations integradas, con métricas. |
| Checkpoints | Los gestionas a mano. | Automáticos. |
| Flexibilidad | Total: cualquier código, cualquier task. | Limitada a pipelines de tablas. |
| Cuándo | Orquestación general, pasos heterogéneos. | Pipelines ETL de Bronze a Gold. |

## 14Rendimiento y optimización

Esta sección es la que separa a un candidato junior de uno senior. Si te preguntan "tu job tarda 4 horas, ¿qué haces?", esto es lo que debes recorrer.

### El problema de los archivos pequeños

Si una tabla tiene 100.000 archivos de 1 MB en vez de 1.000 de 100 MB, Spark pasa más tiempo abriendo archivos que leyendo datos. Se arregla con `OPTIMIZE`, que los compacta, o dejando que Databricks lo haga solo con *auto-optimize* y *predictive optimization*.

### Z-Ordering y Liquid Clustering

**Z-Order** reorganiza físicamente las filas para que los valores parecidos de una columna queden juntos en los mismos archivos. Así, al filtrar por esa columna, Spark puede saltarse archivos enteros usando las estadísticas del log (*data skipping*). Lo eliges para las columnas por las que más filtras.

**Liquid Clustering** es el sucesor: hace lo mismo pero puedes cambiar las columnas de clustering sin reescribir la tabla, y maneja el skew mucho mejor. Mencionarlo como la recomendación actual frente a particionado + Z-Order demuestra que estás al día.

El data skipping funciona porque el `_delta_log` guarda el mínimo y el máximo de cada columna por archivo. Z-Order hace que esos rangos sean estrechos y por tanto útiles.

### Caching

`df.cache()` guarda un DataFrame en memoria para reutilizarlo. Útil cuando vas a usar el mismo resultado intermedio varias veces, por ejemplo en un bucle de entrenamiento. Pero ocupa memoria que las tasks necesitan, así que cachear por reflejo es un antipatrón: solo cachea lo que de verdad se reutiliza, y libéralo con `unpersist()`.

### Photon

**Photon** es el motor de ejecución vectorizado de Databricks, reescrito en C++. Acelera consultas SQL y operaciones de DataFrame sin cambiar tu código: lo activas y ya. Cobra más DBUs por hora, pero si la consulta termina en la mitad del tiempo, sale más barato en total. Brilla en agregaciones y joins sobre Delta; no ayuda en UDFs de Python, que caen de vuelta al motor normal.

### Evita las UDFs de Python

Una UDF de Python obliga a Spark a sacar cada fila de la JVM, pasarla a un proceso Python, calcular y devolverla. Eso es lentísimo y ciego para el optimizador. El orden de preferencia es: **funciones nativas de Spark** primero; si no existe lo que necesitas, una **Pandas UDF** (vectorizada, procesa lotes); y solo como último recurso una UDF de Python fila a fila.

### Checklist mental para "mi job está lento"

1. Abrir la Spark UI y encontrar el stage que consume el tiempo.
2. Mirar la distribución de duración de las tasks: si una domina, es **skew**.
3. Contar los shuffles: ¿se puede convertir algún join en broadcast?
4. Revisar el tamaño y número de archivos: ¿hace falta `OPTIMIZE`?
5. Comprobar que los filtros se empujan a la lectura y que hay partition pruning.
6. Verificar que no hay UDFs de Python en el camino caliente.
7. Comprobar spill a disco en la UI: si lo hay, faltan particiones o memoria.
8. Solo al final: agrandar el cluster. Escalar hardware antes de arreglar el plan es caro e inútil.

## 1530 preguntas de entrevista

### Fundamentos

1\. ¿Qué es un Lakehouse y qué problema resuelve?

Combina el storage barato y flexible del lake con las garantías y el rendimiento del warehouse. **Resuelve la duplicación**: ya no mantienes una copia para BI y otra para ML.

2\. Control plane vs data plane.

Control plane en la cuenta de Databricks (UI, scheduler, metadatos). Data plane en tu cuenta cloud (compute y storage). **Tus datos nunca salen de tu cuenta.**

3\. ¿Qué es un DBU?

La unidad de consumo con la que Databricks factura el procesamiento. Tu costo total son DBUs + las VMs que te cobra el proveedor cloud aparte.

### Spark

4\. Transformación vs acción.

La transformación solo describe y no ejecuta nada (lazy). La acción pide un resultado y dispara la ejecución de todo el plan acumulado.

5\. ¿Por qué Spark es perezoso?

Para ver el plan completo antes de ejecutar y poder optimizarlo: empujar filtros a la lectura, podar columnas, reordenar joins y fusionar operaciones narrow en un solo paso.

6\. Narrow vs wide.

Narrow: cada partición se resuelve sola, sin red. Wide: hay que redistribuir datos entre workers, lo que genera un **shuffle** y corta el stage.

7\. ¿Qué es un DAG y para qué sirve?

El grafo de operaciones a ejecutar. Permite paralelizar lo independiente, optimizar antes de correr, y recuperarse de fallos recalculando solo la partición perdida vía lineage.

8\. Job, stage y task.

Job = una acción. Stage = trozo sin shuffle (shuffles + 1). Task = el stage aplicado a una partición. La task es la unidad real que corre en un slot.

9\. ¿Cuántas tasks corren a la vez?

Tantas como cores totales tengan los workers. Es el paralelismo máximo del cluster.

10\. ¿Qué hace el driver?

Ejecuta tu código principal, construye el DAG y el plan, programa las tasks en los executors y recoge los resultados. Hay uno solo y es un punto único de fallo.

11\. RDD vs DataFrame.

RDD es bajo nivel, sin esquema y sin optimización de Catalyst. DataFrame es una tabla distribuida tipada que sí se optimiza. Usa DataFrame salvo necesidad muy específica.

12\. ¿Qué es Catalyst?

El optimizador de consultas: reescribe tu plan lógico en uno equivalente más eficiente y genera el plan físico.

13\. ¿Qué es AQE?

Adaptive Query Execution: reoptimiza el plan durante la ejecución usando estadísticas reales. Fusiona particiones pequeñas, cambia estrategia de join y divide particiones sesgadas.

14\. repartition vs coalesce.

repartition hace shuffle completo y puede subir o bajar el número. coalesce solo reduce, fusionando sin shuffle. coalesce antes de escribir, repartition para rebalancear.

15\. cache vs persist.

cache es persist con el nivel por defecto (memoria y disco). persist te deja elegir el nivel de almacenamiento.

### Delta Lake

16\. ¿Qué es Delta Lake?

Una capa de almacenamiento sobre Parquet que añade un transaction log, dando ACID, time travel, enforcement de esquema y estadísticas para data skipping.

17\. ¿Cómo consigue ACID?

Con el `_delta_log`: cada commit es un archivo JSON atómico que declara qué archivos están activos. Los lectores consultan el log, así que nunca ven escrituras a medias.

18\. Explica time travel.

Como el log guarda el historial completo, puedes reconstruir la tabla en cualquier versión o momento: `VERSION AS OF` o `TIMESTAMP AS OF`. Sirve para auditoría, reproducibilidad y para deshacer errores.

19\. ¿Qué hace OPTIMIZE?

Compacta muchos archivos pequeños en pocos grandes. Con `ZORDER BY` además coloca juntas las filas con valores parecidos para mejorar el data skipping.

20\. ¿Qué hace VACUUM y qué riesgo tiene?

Borra físicamente los archivos retirados más antiguos que el periodo de retención. El riesgo: pierdes el time travel a esas versiones.

21\. ¿Para qué sirve MERGE?

Upsert en una sola operación atómica: actualiza las filas que coinciden, inserta las nuevas y opcionalmente borra. Es la base de las cargas incrementales y de SCD tipo 2.

22\. Managed vs external.

En managed, el DROP borra los datos. En external, solo borra el registro del catálogo y los archivos quedan. Managed por defecto; external cuando otros sistemas leen esos archivos.

23\. Schema enforcement vs evolution.

Enforcement rechaza escrituras que no cuadran con el esquema; es el default y protege la calidad. Evolution (`mergeSchema`) permite añadir columnas nuevas a propósito.

### Arquitectura y operación

24\. Explica la arquitectura medallion.

Bronze crudo e inmutable, Silver limpio y conformado, Gold agregado para consumo. Permite reprocesar desde Bronze y pone puntos de control de calidad entre capas.

25\. Job cluster vs all-purpose.

Job cluster nace y muere con el job: más barato y correcto para producción. All-purpose para desarrollo interactivo compartido.

26\. ¿Qué es Unity Catalog?

El gobierno centralizado: namespace de tres niveles (catálogo, esquema, objeto), permisos SQL heredados, linaje automático a nivel de columna, auditoría y Delta Sharing.

27\. ¿Qué es Auto Loader y por qué no un listado del directorio?

Ingesta incremental de archivos con checkpoint propio, que garantiza exactly-once sin listar todo el directorio en cada corrida. En directorios con millones de archivos, listar es inviable.

28\. Workflows vs DLT.

Workflows es orquestación imperativa y general. DLT es declarativo para pipelines de tablas, con expectations de calidad y gestión automática de checkpoints y dependencias.

29\. ¿Cómo haces CI/CD en Databricks?

Código en Git con Databricks Repos, jobs y pipelines definidos como código con Asset Bundles, y despliegue por entornos (dev, staging, prod) separados en catálogos de Unity Catalog.

30\. Tu job pasó de 20 minutos a 4 horas. ¿Qué miras?

Spark UI para ubicar el stage lento; distribución de tasks para detectar skew; número y tamaño de archivos; si los joins pueden ser broadcast; si hay spill a disco; si entró una UDF de Python. Escalar el cluster es el último recurso, no el primero.

## 16Trampas típicas

1

Confundir el **Spark job** con el **Databricks Job**. Aclara a cuál se refieren; demuestra criterio.

2

Decir que `collect()` es inofensivo. Trae **todos** los datos al driver y lo tumba por falta de memoria. Usa `limit()` o `display()`.

3

Creer que Delta es un formato de archivo. **Es Parquet más un transaction log.** Los datos siguen siendo Parquet.

4

Decir que `VACUUM` es gratis. Borra el time travel de las versiones afectadas.

5

Pensar que particionar siempre ayuda. Particionar por una columna de alta cardinalidad (como un ID) crea millones de carpetas diminutas y empeora todo. Como regla, solo particiona tablas grandes y por columnas de baja cardinalidad.

6

Cachear todo "por si acaso". La caché come la memoria que las tasks necesitan.

7

Responder "agrando el cluster" ante un job lento. Primero arregla el plan; el hardware es el último paso.

8

Olvidar el auto-termination al hablar de costos. Es el error operativo más caro y más común.

9

No saber que el número de tasks lo determinan las **particiones**, no los workers.

10

Hablar de streaming sin mencionar el **checkpoint**. Es lo que da la garantía exactly-once.

## 17Cheat sheet de código

### PySpark esencial

```
from pyspark.sql.functions import col, sum, count, broadcast, current_timestamp

df = spark.read.table("prod.silver.ventas")

# Transformaciones encadenadas — nada se ejecuta todavía
res = (df
  .filter(col("pais") == "CO")
  .withColumn("ingesta", current_timestamp())
  .groupBy("mes")
  .agg(sum("total").alias("ventas"), count("*").alias("n")))

res.explain("formatted")   # ver el plan SIN ejecutar
res.display()                # acción: aquí sí corre

# Forzar broadcast de la tabla pequeña
grande.join(broadcast(pequena), "id", "left")

# Escribir en Delta
(res.write.format("delta")
   .mode("overwrite")
   .option("overwriteSchema", "true")
   .saveAsTable("prod.gold.ventas_mes"))
```

### Diagnóstico

```
-- ¿Cuántos archivos y de qué tamaño?
DESCRIBE DETAIL prod.silver.ventas;

-- ¿Qué se le ha hecho a esta tabla?
DESCRIBE HISTORY prod.silver.ventas;

-- ¿De dónde salen estos datos? (Unity Catalog)
DESCRIBE EXTENDED prod.silver.ventas;

-- Particiones actuales en memoria
-- df.rdd.getNumPartitions()
```

### Permisos

```
GRANT USE CATALOG ON CATALOG prod TO `analistas`;
GRANT USE SCHEMA ON SCHEMA prod.ventas TO `analistas`;
GRANT SELECT ON TABLE prod.ventas.pedidos TO `analistas`;
SHOW GRANTS ON TABLE prod.ventas.pedidos;
```

### Frases que funcionan bien en la entrevista

- "Mis datos nunca salen de mi cuenta cloud; el control plane solo tiene metadatos."
- "Cuento los shuffles del plan antes de tocar el tamaño del cluster."
- "Bronze es append-only para poder reprocesar sin volver a la fuente."
- "Uso job clusters en producción y all-purpose solo para desarrollo."
- "Prefiero liquid clustering a particionado más Z-Order en tablas nuevas."
- "El checkpoint es lo que me da exactly-once; sin él no hay garantía."
- "Reviso la distribución de duración de tasks antes de culpar al volumen de datos."

Guía de preparación para entrevista de Databricks · noviembre 2026. Los nombres de producto y los valores por defecto de Databricks cambian con frecuencia; confirma los detalles de versión contra la documentación oficial antes de citarlos como exactos.